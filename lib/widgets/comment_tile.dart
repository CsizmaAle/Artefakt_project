import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';

class CommentTile extends StatefulWidget {
  final String body;
  final String userId;
  final String? createdAt;
  const CommentTile({super.key, required this.body, required this.userId, this.createdAt});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  static final Map<String, Map<String, dynamic>> _cache = {};
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.userId;
    if (_cache.containsKey(uid)) {
      setState(() => _profile = _cache[uid]);
      return;
    }
    try {
      final row = await supabase.from('profiles').select('id, username, display_name, photo_url').eq('id', uid).maybeSingle();
      if (mounted) {
        _cache[uid] = row ?? const {};
        setState(() => _profile = row);
      }
    } catch (_) {
      // ignore fetch errors; show fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final displayName = (p?['display_name'] as String?)?.trim();
    final username = (p?['username'] as String?)?.trim();
    final photoUrl = (p?['photo_url'] as String?)?.trim();
    final title = (displayName?.isNotEmpty ?? false)
        ? displayName!
        : (username?.isNotEmpty ?? false)
            ? '@${username!}'
            : 'user';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 18) : null,
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(widget.body),
      trailing: (widget.createdAt != null && widget.createdAt!.isNotEmpty)
          ? Text(
              widget.createdAt!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            )
          : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}

