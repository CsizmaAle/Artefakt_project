
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/services/follow_events.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _saving = false;
  bool _uploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    if (!mounted) return;
    setState(() {
      _photoUrl = (row?['photo_url'] ?? '') as String?;
      _nameCtrl.text = (row?['display_name'] ?? '') as String? ?? '';
      _bioCtrl.text = (row?['bio'] ?? '') as String? ?? '';
    });
  }

  String _guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _pickAndUploadPhoto() async {
    final c = Supabase.instance.client;
    final user = c.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }
    final uid = user.id;

    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 88);
    if (x == null) return;

    final Uint8List bytes = await x.readAsBytes();
    final mime = _guessMimeFromName(x.name);

    final String path = '$uid/profile_${DateTime.now().millisecondsSinceEpoch}${x.name.contains(".") ? x.name.substring(x.name.lastIndexOf(".")) : ".jpg"}';

    assert(!path.startsWith('/'), 'Path must not start with "/"');
    assert(path.split('/').first == uid, 'First segment must be UID');

    setState(() => _uploading = true);
    try {
      await c.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      // Public bucket → public URL
      final publicUrl = c.storage.from('avatars').getPublicUrl(path);

      await c.from('profiles').update({'photo_url': publicUrl}).eq('id', uid);
      setState(() => _photoUrl = publicUrl);
      // Notify profile screens to refresh immediately even if Realtime is off
      FollowEvents.instance.notify();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final c = Supabase.instance.client;
    final user = c.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await c.from('profiles').update({
        'display_name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      // Notify and return to profile so changes show right away
      FollowEvents.instance.notify();
      // Go back to profile and show changes immediately
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: Text('You need to be signed in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                    ? NetworkImage(_photoUrl!)
                    : null,
                child: (_photoUrl == null || _photoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 44)
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _uploading ? null : _pickAndUploadPhoto,
                    icon: const Icon(Icons.photo),
                    label: const Text('Change photo'),
                  ),
                  if (_uploading) const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioCtrl,
            decoration: const InputDecoration(labelText: 'Bio'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}

