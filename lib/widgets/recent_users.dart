// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:artefakt_v1/services/search_history_service.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/pages/profile_public_page.dart';

class RecentUsers extends StatelessWidget {
  const RecentUsers({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();

    final future = supabase
        .from('search_history')
        .select('query, search_type, created_at')
        .eq('user_id', uid)
        .eq('search_type', 'user')
        .order('created_at', ascending: false)
        .limit(50);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        final rows = (snap.data ?? const []);
        final queries = <String>[];
        final seen = <String>{};
        for (final r in rows) {
          final q = (r['query'] as String?)?.trim() ?? '';
          if (q.isEmpty || seen.contains(q)) continue;
          seen.add(q);
          queries.add(q);
          if (queries.length >= 6) break;
        }
        if (queries.isEmpty) return const SizedBox.shrink();

        Future<Map<String, dynamic>?> fetchProfile(String q) async {
          // Try by id
          final byId = await supabase
              .from('profiles')
              .select('id, username, display_name, photo_url')
              .eq('id', q)
              .maybeSingle();
          if (byId != null) return byId;
          // Fallback: by exact username (for older history rows)
          final byUser = await supabase
              .from('profiles')
              .select('id, username, display_name, photo_url')
              .eq('username', q)
              .maybeSingle();
          return byUser;
        }

        final futures = queries.map(fetchProfile).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(futures).then((list) => list
              .whereType<Map<String, dynamic>>()
              .toList()),
          builder: (context, profSnap) {
            final seenIds = <String>{};
            final ordered = <Map<String, dynamic>>[];
            for (final row in (profSnap.data ?? const [])) {
              if (row == null) continue;
              final id = (row['id'] as String?) ?? '';
              if (id.isEmpty || seenIds.contains(id)) continue;
              seenIds.add(id);
              ordered.add(row);
              if (ordered.length >= 6) break;
            }
            if (ordered.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 18),
                          const SizedBox(width: 8),
                          Text('Recent accounts', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...ordered.map((u) {
                      final username = (u['username'] as String?) ?? '';
                      final name = (u['display_name'] as String?) ?? '';
                      final photoUrl = (u['photo_url'] as String?) ?? '';
                      final userId = (u['id'] as String?) ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(name.isNotEmpty ? name : (username.isEmpty ? 'user' : '@$username')),
                        subtitle: username.isNotEmpty && name.isNotEmpty ? Text('@$username') : null,
                        onTap: () {
                          if (userId.isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ProfilePublicPage(userId: userId)),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
