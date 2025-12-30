import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:artefakt_v1/services/post_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/pages/profile_page.dart';

class NewPostPage extends StatefulWidget {
  final VoidCallback? onPosted;
  const NewPostPage({super.key, this.onPosted});

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final _textCtrl = TextEditingController();
  Uint8List? _imageBytes;
  String _imageExt = '.jpg';
  bool _posting = false;

  String _guessExt(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 90);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageExt = _guessExt(x.name);
    });
  }

  Future<void> _removeImage() async {
    setState(() {
      _imageBytes = null;
      _imageExt = '.jpg';
    });
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    final text = _textCtrl.text.trim();
    if ((text.isEmpty) && (_imageBytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something or add a photo.')));
      return;
    }

    setState(() => _posting = true);
    try {
      await PostService().createPost(
        contentText: text,
        imageBytes: _imageBytes,
        imageExt: _imageExt,
      );
      if (!mounted) return;
      // If a callback is provided (e.g., from HomePage), use it to switch tabs.
      if (widget.onPosted != null) {
        widget.onPosted!.call();
        return;
      }
      // Fallback navigation: go to Profile page.
      try {
        // Import is deferred below to avoid unused import if callback handles it.
        // ignore: use_build_context_synchronously
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      } catch (_) {
        // If navigation fails for any reason, keep the old UX as a last resort.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          _textCtrl.clear();
          setState(() {
            _imageBytes = null;
            _imageExt = '.jpg';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Posted')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageBytes;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.memory(
                  image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _posting ? null : _removeImage,
                icon: const Icon(Icons.close),
                label: const Text('Remove photo'),
              ),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: _posting ? null : _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('Add photo'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _posting ? null : _submit,
        label: _posting
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Post'),
        icon: _posting ? null : const Icon(Icons.send),
      ),
    );
  }
}


