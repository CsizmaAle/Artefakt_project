import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/services/post_service.dart';
import 'package:artefakt_v1/widgets/post_actions.dart';
import 'package:artefakt_v1/widgets/comment_tile.dart';
import 'package:artefakt_v1/widgets/user_header.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _svc = PostService();
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final postId = (post['id'] as String?) ?? '';
    final imageUrl = (post['image_url'] as String?) ?? '';
    final body = (post['body'] as String?) ?? '';
    final createdAt = (post['created_at'] as String?) ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((post['author_id'] as String?)?.isNotEmpty ?? false)
            UserHeader(
              userId: post['author_id'] as String,
              subtitle: createdAt,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          if (imageUrl.isNotEmpty) const SizedBox(height: 12),
          if (body.isNotEmpty)
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (body.isNotEmpty) const SizedBox(height: 12),
          if (createdAt.isNotEmpty)
            Text(
              createdAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          const SizedBox(height: 12),

          // Actions: Like / Comment / Share
          if (postId.isNotEmpty)
            PostActionsBar(
              postId: postId,
              onCommentTap: () => _commentFocus.requestFocus(),
            ),

          const SizedBox(height: 12),

          // Comments list
          if (postId.isNotEmpty)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _svc.commentsStream(postId),
              builder: (context, snap) {
                final comments = snap.data ?? const [];
                if (comments.isEmpty) {
                  return const Text('No comments yet');
                }
                return Column(
                  children: comments.map((c) {
                    final text = (c['body'] as String?) ?? '';
                    final ts = (c['created_at'] as String?) ?? '';
                    final uid = (c['user_id'] as String?) ?? '';
                    return CommentTile(body: text, userId: uid, createdAt: ts);
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 12),

          // Add comment box
          if (postId.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocus,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending
                      ? null
                      : () async {
                          final text = _commentCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _sending = true);
                          try {
                            await _svc.addComment(postId: postId, body: text);
                            _commentCtrl.clear();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to comment: $e')));
                          } finally {
                            if (mounted) setState(() => _sending = false);
                          }
                        },
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
