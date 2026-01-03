import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/utils/date_format.dart';

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

    final dateText = formatPostDate(widget.createdAt);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          height: 1.45,
        );
    final dateStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
        );
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 18) : null,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
      ),
      subtitle: Text(widget.body, style: bodyStyle),
      trailing: dateText.isNotEmpty
          ? Text(
              dateText,
              style: dateStyle,
            )
          : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}
