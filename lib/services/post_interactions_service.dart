import 'package:supabase_flutter/supabase_flutter.dart';

class PostInteractionsService {
  final SupabaseClient _c = Supabase.instance.client;

  Future<Set<String>> fetchInteractedPostIds({
    required List<String> postIds,
    required String userId,
  }) async {
    if (postIds.isEmpty || userId.isEmpty) return {};

    final liked = await _fetchPostIdsForUser('post_likes', postIds, userId);
    final commented = await _fetchPostIdsForUser('post_comments', postIds, userId);
    final shared = await _fetchPostIdsForUser('post_shares', postIds, userId);

    return {...liked, ...commented, ...shared};
  }

  Future<Set<String>> _fetchPostIdsForUser(
    String table,
    List<String> postIds,
    String userId,
  ) async {
    try {
      final rows = await _c
          .from(table)
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final ids = <String>{};
      for (final row in (rows as List)) {
        final postId = (row['post_id'] as String?) ?? '';
        if (postId.isNotEmpty) ids.add(postId);
      }
      return ids;
    } catch (_) {
      return {};
    }
  }
}
