import 'package:supabase_flutter/supabase_flutter.dart';

class PostMetrics {
  final Map<String, int> likes;
  final Map<String, int> comments;
  final Map<String, int> shares;

  const PostMetrics({
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory PostMetrics.empty() => const PostMetrics(
        likes: {},
        comments: {},
        shares: {},
      );
}

class PostMetricsService {
  final SupabaseClient _c = Supabase.instance.client;

  Future<PostMetrics> fetchMetrics(List<String> postIds) async {
    if (postIds.isEmpty) return PostMetrics.empty();

    final likes = await _countByPost('post_likes', postIds);
    final comments = await _countByPost('post_comments', postIds);
    final shares = await _countByPost('post_shares', postIds);

    return PostMetrics(likes: likes, comments: comments, shares: shares);
  }

  Future<Map<String, int>> _countByPost(String table, List<String> postIds) async {
    try {
      final rows = await _c.from(table).select('post_id').inFilter('post_id', postIds);
      final counts = <String, int>{};
      for (final row in (rows as List)) {
        final postId = (row['post_id'] as String?) ?? '';
        if (postId.isEmpty) continue;
        counts[postId] = (counts[postId] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }
}
