import 'package:flutter/material.dart';
import 'package:artefakt_v1/services/post_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostActionsBar extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentTap;
  const PostActionsBar({super.key, required this.postId, this.onCommentTap});

  @override
  State<PostActionsBar> createState() => _PostActionsBarState();
}

class _PostActionsBarState extends State<PostActionsBar> {
  final PostService _svc = PostService();
  bool _likeBusy = false;
  bool _shareBusy = false;

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final postId = widget.postId;
    return Row(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.likesStream(postId),
          builder: (context, snap) {
            final likes = snap.data ?? const [];
            final count = likes.length;
            final likedByMe = userId != null && likes.any((e) => e['user_id'] == userId);
            return TextButton.icon(
              onPressed: _likeBusy
                  ? null
                  : () async {
                      setState(() => _likeBusy = true);
                      try {
                        await _svc.toggleLike(postId);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to like: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _likeBusy = false);
                      }
                    },
              icon: _likeBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: likedByMe ? Colors.red : null,
                    ),
              label: Text(count.toString()),
            );
          },
        ),
        const SizedBox(width: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.commentsStream(postId),
          builder: (context, snap) {
            final count = (snap.data ?? const []).length;
            return TextButton.icon(
              onPressed: widget.onCommentTap,
              icon: const Icon(Icons.mode_comment_outlined),
              label: Text(count.toString()),
            );
          },
        ),
        const SizedBox(width: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.sharesStream(postId),
          builder: (context, snap) {
            final count = (snap.data ?? const []).length;
            return TextButton.icon(
              onPressed: _shareBusy
                  ? null
                  : () async {
                      setState(() => _shareBusy = true);
                      try {
                        await _svc.sharePost(postId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Shared')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to share: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _shareBusy = false);
                      }
                    },
              icon: _shareBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_outlined),
              label: Text(count.toString()),
            );
          },
        ),
      ],
    );
  }
}
