import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/pages/profile_public_page.dart';
import 'package:artefakt_v1/services/search_history_service.dart';
import 'package:artefakt_v1/utils/date_format.dart';

class UserHeader extends StatefulWidget {
  final String userId;
  final String? subtitle; // e.g., created_at
  final EdgeInsetsGeometry padding;
  const UserHeader({super.key, required this.userId, this.subtitle, this.padding = const EdgeInsets.all(8)});

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
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
      final row = await supabase
          .from('profiles')
          .select('id, username, display_name, photo_url')
          .eq('id', uid)
          .maybeSingle();
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
    final subtitleText = formatPostDate(widget.subtitle);

    return Padding(
      padding: widget.padding,
      child: InkWell(
        onTap: () {
          // Log as recently accessed account
          SearchHistoryService().log(query: widget.userId, searchType: 'user');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePublicPage(userId: widget.userId),
            ),
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitleText.isNotEmpty)
                    Text(
                      subtitleText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
