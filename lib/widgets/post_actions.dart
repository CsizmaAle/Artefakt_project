import 'package:flutter/material.dart';
import 'package:artefakt_v1/services/post_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/services/messages_service.dart';

class PostActionsBar extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentTap;
  final bool whiteIcons;
  const PostActionsBar({
    super.key,
    required this.postId,
    this.onCommentTap,
    this.whiteIcons = false,
  });

  @override
  State<PostActionsBar> createState() => _PostActionsBarState();
}

class _PostActionsBarState extends State<PostActionsBar> {
  final PostService _svc = PostService();
  final MessagesService _msgSvc = MessagesService();
  bool _likeBusy = false;
  bool _shareBusy = false;

  Future<List<_ConversationPickItem>> _loadConversations() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const [];
    final memRows = await Supabase.instance.client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid);
    final ids = <String>[];
    for (final r in (memRows as List)) {
      final id = (r['conversation_id'] as String?) ?? '';
      if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
    }
    if (ids.isEmpty) return const [];

    final convs = await Supabase.instance.client
        .from('conversations')
        .select('id, is_group, title, last_message_at')
        .inFilter('id', ids)
        .order('last_message_at', ascending: false);

    final members = await Supabase.instance.client
        .from('conversation_members')
        .select('conversation_id, user_id')
        .inFilter('conversation_id', ids);

    final membersByConv = <String, List<String>>{};
    for (final r in (members as List)) {
      final cid = (r['conversation_id'] as String?) ?? '';
      final mid = (r['user_id'] as String?) ?? '';
      if (cid.isEmpty || mid.isEmpty) continue;
      membersByConv.putIfAbsent(cid, () => []).add(mid);
    }

    final items = <_ConversationPickItem>[];
    for (final row in (convs as List)) {
      final id = (row['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final isGroup = (row['is_group'] as bool?) ?? false;
      final title = (row['title'] as String?) ?? '';
      String? otherId;
      if (!isGroup) {
        final list = membersByConv[id] ?? const [];
        for (final mid in list) {
          if (mid != uid) {
            otherId = mid;
            break;
          }
        }
      }
      items.add(_ConversationPickItem(
        conversationId: id,
        isGroup: isGroup,
        title: title,
        otherUserId: otherId,
      ));
    }
    return items;
  }

  Future<void> _sendPostToConversation(String conversationId, String postId) async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      final row = await _msgSvc.sendMessage(
        conversationId: conversationId,
        content: 'post:$postId',
      );
      if (row != null) {
        await _svc.sharePost(postId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post sent')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send post')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  void _openSharePicker(String postId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FutureBuilder<List<_ConversationPickItem>>(
            future: _loadConversations(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No conversations')),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return _ConversationPickTile(
                    item: item,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _sendPostToConversation(item.conversationId, postId);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final postId = widget.postId;
    final scheme = Theme.of(context).colorScheme;
    final baseColor = widget.whiteIcons ? Colors.white : scheme.onSurfaceVariant;
    final labelColor = widget.whiteIcons ? Colors.white : scheme.onSurface;
    return Row(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.likesStream(postId),
          builder: (context, snap) {
            final likes = snap.data ?? const [];
            final count = likes.length;
            final likedByMe = userId != null && likes.any((e) => e['user_id'] == userId);
            final likedColor = widget.whiteIcons ? Colors.white : (likedByMe ? Colors.red : baseColor);
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
                      color: likedColor,
                    ),
              label: Text(
                count.toString(),
                style: TextStyle(color: labelColor),
              ),
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
              icon: Icon(Icons.mode_comment_outlined, color: baseColor),
              label: Text(
                count.toString(),
                style: TextStyle(color: labelColor),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.sharesStream(postId),
          builder: (context, snap) {
            final count = (snap.data ?? const []).length;
            return TextButton.icon(
              onPressed: _shareBusy ? null : () => _openSharePicker(postId),
              icon: _shareBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.share_outlined, color: baseColor),
              label: Text(
                count.toString(),
                style: TextStyle(color: labelColor),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ConversationPickItem {
  final String conversationId;
  final bool isGroup;
  final String title;
  final String? otherUserId;

  const _ConversationPickItem({
    required this.conversationId,
    required this.isGroup,
    required this.title,
    required this.otherUserId,
  });
}

class _ConversationPickTile extends StatelessWidget {
  final _ConversationPickItem item;
  final VoidCallback onTap;

  const _ConversationPickTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (item.isGroup) {
      final title = item.title.isNotEmpty ? item.title : 'Group';
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.group)),
        title: Text(title),
        onTap: onTap,
      );
    }
    final otherId = item.otherUserId;
    if (otherId == null) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: const Text('Direct'),
        onTap: onTap,
      );
    }
    return ListTile(
      leading: _UserAvatar(userId: otherId),
      title: _UserTitle(userId: otherId),
      onTap: onTap,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String userId;
  const _UserAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('profiles')
          .select('photo_url')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snap) {
        final photoUrl = (snap.data?['photo_url'] as String?) ?? '';
        return CircleAvatar(
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
        );
      },
    );
  }
}

class _UserTitle extends StatelessWidget {
  final String userId;
  const _UserTitle({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('profiles')
          .select('username, display_name')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snap) {
        final row = snap.data;
        final username = (row?['username'] as String?) ?? '';
        final displayName = (row?['display_name'] as String?) ?? '';
        final text = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? '@$username' : 'Direct');
        return Text(text);
      },
    );
  }
}
