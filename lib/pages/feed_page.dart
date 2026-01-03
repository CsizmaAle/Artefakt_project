import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/widgets/post_actions.dart';
import 'package:artefakt_v1/widgets/user_header.dart';
import 'package:artefakt_v1/pages/post_detail_page.dart';
import 'package:artefakt_v1/services/feed_ranker.dart';
import 'package:artefakt_v1/services/post_interactions_service.dart';
import 'package:artefakt_v1/services/post_metrics_service.dart';
import 'package:artefakt_v1/services/search_history_service.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostMetricsService _metricsService = PostMetricsService();
  final PostInteractionsService _interactionsService = PostInteractionsService();

  @override
  void initState() {
    super.initState();
    FeedRanker.instance.loadFromAssets().then((_) {
      if (mounted) setState(() {});
    });
  }

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
        builder: (context, snap) {
          final posts = snap.data ?? const [];
          return _buildRankedList(
            posts: posts,
            followingIds: const <String>{},
            seenIds: const <String>{},
            uid: null,
          );
        },
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
                return _buildRankedList(
                  posts: all,
                  followingIds: followingIds,
                  seenIds: seenIds,
                  uid: uid,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRankedList({
    required List<Map<String, dynamic>> posts,
    required Set<String> followingIds,
    required Set<String> seenIds,
    required String? uid,
  }) {
    final ids = _collectPostIds(posts);
    return FutureBuilder<_FeedExtras>(
      future: _loadExtras(ids, uid),
      builder: (context, extrasSnap) {
        final extras = extrasSnap.data;
        final metrics = extras?.metrics ?? PostMetrics.empty();
        final interacted = extras?.interactedIds ?? const <String>{};
        final enriched = _applyMetrics(posts, metrics);
        final ranked = FeedRanker.instance.rankPosts(
          posts: enriched,
          followingIds: followingIds,
          seenIds: seenIds,
          currentUserId: uid,
        );
        final ordered = _moveInteractedToEnd(
          ranked,
          seenIds: seenIds,
          interactedIds: interacted,
        );
        return _buildPostsList(context, ordered);
      },
    );
  }

  Future<_FeedExtras> _loadExtras(List<String> postIds, String? uid) async {
    final metrics = await _metricsService.fetchMetrics(postIds);
    if (uid == null || postIds.isEmpty) {
      return _FeedExtras(metrics: metrics, interactedIds: const {});
    }
    final interacted = await _interactionsService.fetchInteractedPostIds(
      postIds: postIds,
      userId: uid,
    );
    return _FeedExtras(metrics: metrics, interactedIds: interacted);
  }
}

List<String> _collectPostIds(List<Map<String, dynamic>> posts) {
  final ids = <String>[];
  for (final p in posts) {
    final id = (p['id'] as String?) ?? '';
    if (id.isNotEmpty) ids.add(id);
  }
  return ids;
}

List<Map<String, dynamic>> _moveInteractedToEnd(
  List<Map<String, dynamic>> posts, {
  required Set<String> seenIds,
  required Set<String> interactedIds,
}) {
  if (posts.isEmpty) return posts;
  final allInteracted = <String>{...seenIds, ...interactedIds};
  if (allInteracted.isEmpty) return posts;
  final fresh = <Map<String, dynamic>>[];
  final old = <Map<String, dynamic>>[];
  for (final post in posts) {
    final id = (post['id'] as String?) ?? '';
    if (id.isNotEmpty && allInteracted.contains(id)) {
      old.add(post);
    } else {
      fresh.add(post);
    }
  }
  return [...fresh, ...old];
}

List<Map<String, dynamic>> _applyMetrics(List<Map<String, dynamic>> posts, PostMetrics metrics) {
  return [
    for (final p in posts)
      Map<String, dynamic>.from(p)
        ..['likes_count'] = metrics.likes[(p['id'] as String?) ?? ''] ?? 0
        ..['comments_count'] = metrics.comments[(p['id'] as String?) ?? ''] ?? 0
        ..['shares_count'] = metrics.shares[(p['id'] as String?) ?? ''] ?? 0
  ];
}

class _FeedExtras {
  final PostMetrics metrics;
  final Set<String> interactedIds;

  const _FeedExtras({
    required this.metrics,
    required this.interactedIds,
  });
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
