import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  final _c = Supabase.instance.client;

  String _extToMime(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':  return 'image/png';
      case '.webp': return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:      return 'image/jpeg';
    }
  }

  Future<String> _uploadImage({
    required Uint8List bytes,
    required String imageExt, 
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) { throw Exception('Not logged in'); }
    final uid = user.id;

    final path = '$uid/post_${DateTime.now().millisecondsSinceEpoch}$imageExt';
    // RLS safety checks
    if (path.startsWith('/')) throw Exception('Upload path must not start with "/"');
    if (path.split('/').first != uid) throw Exception('First path segment must equal UID');

    final mime = _extToMime(imageExt);

    try {
      await _c.storage.from('posts').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );
    } on StorageException {
      // Helpful debug
      rethrow;
    }

    // If bucket is public:
    return _c.storage.from('posts').getPublicUrl(path);
    // If private, use createSignedUrl instead and store that.
  }

  Future<void> createPost({
    required String contentText,
    Uint8List? imageBytes,
    String imageExt = '.jpg',
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    String? imageUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      imageUrl = await _uploadImage(bytes: imageBytes, imageExt: imageExt);
    }

    await _c.from('posts').insert({
    'author_id': user.id,
    'body': contentText.isNotEmpty ? contentText : null,
    'image_url': imageUrl,
  });

  }

  Future<void> updatePost({
    required String postId,
    required String body,
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    if (postId.trim().isEmpty) throw Exception('Missing post id');
    await _c.from('posts').update({
      'body': body.trim().isEmpty ? null : body.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
  }

  Future<void> deletePost({required String postId}) async {
    final user = _c.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    if (postId.trim().isEmpty) throw Exception('Missing post id');
    await _c.from('posts').delete().eq('id', postId);
  }

  // Likes
  Future<bool> toggleLike(String postId) async {
    final res = await _c.rpc('toggle_like', params: {'p_post_id': postId});
    if (res is bool) return res;
    // Supabase may return as int/num for boolean on some drivers; coerce
    if (res is num) return res != 0;
    throw Exception('toggle_like failed');
  }

  Stream<List<Map<String, dynamic>>> likesStream(String postId) {
    return _c
        .from('post_likes')
        .stream(primaryKey: ['post_id', 'user_id'])
        .eq('post_id', postId);
  }

  // Comments
  Future<String> addComment({required String postId, required String body, String? parentId}) async {
    final res = await _c.rpc('add_comment', params: {
      'p_post_id': postId,
      'p_body': body,
      'p_parent_id': parentId,
    });
    if (res is String) return res;
    throw Exception('add_comment failed');
  }

  Stream<List<Map<String, dynamic>>> commentsStream(String postId) {
    return _c
        .from('post_comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at');
  }

  // Shares
  Future<bool> sharePost(String postId) async {
    final res = await _c.rpc('share_post', params: {'p_post_id': postId});
    if (res is bool) return res;
    if (res is num) return res != 0;
    throw Exception('share_post failed');
  }

  Stream<List<Map<String, dynamic>>> sharesStream(String postId) {
    return _c
        .from('post_shares')
        .stream(primaryKey: ['post_id', 'user_id'])
        .eq('post_id', postId);
  }
}
