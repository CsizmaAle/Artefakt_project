// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/services/post_service.dart';
import 'package:artefakt_v1/widgets/post_actions.dart';
import 'package:artefakt_v1/widgets/comment_tile.dart';
import 'package:artefakt_v1/widgets/user_header.dart';
import 'package:artefakt_v1/utils/date_format.dart';

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
  bool _editing = false;
  bool _hasEdits = false;

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
    final createdLabel = formatPostDate(createdAt);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final authorId = (post['author_id'] as String?) ?? '';
    final isAuthor = userId != null && authorId.isNotEmpty && userId == authorId;

    return WillPopScope(
      onWillPop: () async {
        if (!_hasEdits) return true;
        Navigator.of(context).pop(true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Post'),
          actions: isAuthor
              ? [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(initialText: body);
                      } else if (value == 'delete') {
                        _confirmDelete(postId);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ]
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          if ((post['author_id'] as String?)?.isNotEmpty ?? false)
            UserHeader(
              userId: post['author_id'] as String,
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
            (imageUrl.isEmpty)
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _editing ? (post['body'] as String? ?? '') : body,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black,
                          ),
                    ),
                  )
                : Text(
                    _editing ? (post['body'] as String? ?? '') : body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
          if (body.isNotEmpty) const SizedBox(height: 12),
          if (createdLabel.isNotEmpty)
            Text(
              createdLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          const SizedBox(height: 12),

          // Actions: Like / Comment / Share
          if (postId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PostActionsBar(
                postId: postId,
                onCommentTap: () => _commentFocus.requestFocus(),
                whiteIcons: true,
              ),
            ),

          const SizedBox(height: 16),

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
      ),
    );
  }

  Future<void> _showEditDialog({required String initialText}) async {
    if (_editing) return;
    final controller = TextEditingController(text: initialText);
    final updated = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit post'),
          content: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Update your post',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted || updated == null) return;
    setState(() => _editing = true);
    try {
      final postId = (widget.post['id'] as String?) ?? '';
      await _svc.updatePost(postId: postId, body: updated);
      widget.post['body'] = updated.trim();
      _hasEdits = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _confirmDelete(String postId) async {
    if (postId.isEmpty) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await _svc.deletePost(postId: postId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}
