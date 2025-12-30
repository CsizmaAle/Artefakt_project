import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/widgets/post_actions.dart';
import 'package:artefakt_v1/widgets/user_header.dart';
import 'package:artefakt_v1/pages/post_detail_page.dart';
import 'package:artefakt_v1/services/search_history_service.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;
    // Base posts stream
    final postsStream = supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    // If not logged in, just show all posts
    if (uid == null) {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: postsStream,
        builder: (context, snap) => _buildPostsList(context, snap.data ?? const []),
      );
    }

    // Stream of posts the user has "seen" (logged when opening a post)
    final seenStream = supabase
        .from('search_history')
        .stream(primaryKey: ['id']);

    // Following set
    final followingStream = supabase
        .from('follows')
        .stream(primaryKey: ['follower_id', 'target_id'])
        .eq('follower_id', uid);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: followingStream,
      builder: (context, followingSnap) {
        final followingIds = {
          for (final r in (followingSnap.data ?? const [])) (r['target_id'] as String?) ?? ''
        }..removeWhere((e) => e.isEmpty);
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: seenStream,
          builder: (context, seenSnap) {
            final seenRows = (seenSnap.data ?? const [])
                .where((r) => (r['user_id'] as String?) == uid && (r['search_type'] as String?) == 'post');
            final seenIds = {
              for (final r in seenRows) (r['query'] as String?) ?? ''
            }..removeWhere((e) => e.isEmpty);

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: postsStream,
              builder: (context, postsSnap) {
                final all = postsSnap.data ?? const [];

                DateTime? parseTs(String? s) => s == null ? null : DateTime.tryParse(s);
                final cutoffFollowed = DateTime.now().subtract(const Duration(days: 21));

                final idInFollowedRecent = <String>{};
                final followedRecent = <Map<String, dynamic>>[];
                for (final p in all) {
                  final author = (p['author_id'] as String?) ?? '';
                  if (!followingIds.contains(author)) continue;
                  final ts = parseTs(p['created_at'] as String?);
                  if (ts != null && ts.isBefore(cutoffFollowed)) continue;
                  followedRecent.add(p);
                  final pid = (p['id'] as String?) ?? '';
                  if (pid.isNotEmpty) idInFollowedRecent.add(pid);
                }

                followedRecent.sort((a, b) {
                  final aTs = parseTs(a['created_at'] as String?);
                  final bTs = parseTs(b['created_at'] as String?);
                  if (aTs != null && bTs != null) return bTs.compareTo(aTs);
                  return ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? '');
                });

                final remaining = all.where((p) {
                  final pid = (p['id'] as String?) ?? '';
                  return pid.isEmpty || !idInFollowedRecent.contains(pid);
                }).toList();

                final unseen = <Map<String, dynamic>>[];
                final seen = <Map<String, dynamic>>[];
                for (final p in remaining) {
                  final pid = (p['id'] as String?) ?? '';
                  (pid.isNotEmpty && seenIds.contains(pid) ? seen : unseen).add(p);
                }

                unseen.shuffle();
                seen.shuffle();

                final ordered = <Map<String, dynamic>>[...followedRecent]
                  
                  ..addAll(unseen)
                  ..addAll(seen);

                return _buildPostsList(context, ordered);
              },
            );
          },
        );
      },
    );
  }
}

Widget _buildPostsList(BuildContext context, List<Map<String, dynamic>> posts) {
  if (posts.isEmpty) {
    return const Center(child: Text('No posts yet'));
  }
  return ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: posts.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, i) {
      final p = posts[i];
      final id = (p['id'] as String?) ?? '';
      final imageUrl = (p['image_url'] as String?) ?? '';
      final body = (p['body'] as String?) ?? '';
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Log post as seen when opening
            SearchHistoryService().log(query: id, searchType: 'post');
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PostDetailPage(post: p)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((p['author_id'] as String?)?.isNotEmpty ?? false)
                UserHeader(
                  userId: p['author_id'] as String,
                  subtitle: (p['created_at'] as String?) ?? '',
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                ),
              if (imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              if (body.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(body),
                ),
              ],
              if (id.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PostActionsBar(
                    postId: id,
                    onCommentTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PostDetailPage(post: p)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
    },
  );
}
