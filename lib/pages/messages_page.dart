// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/pages/conversation_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: () async {
          final current = supabase.auth.currentUser?.id;
          if (current == null) return <Map<String, dynamic>>[];
          final memRows = await supabase
              .from('conversation_members')
              .select('conversation_id')
              .eq('user_id', current);
          final ids = <String>[];
          for (final r in (memRows as List)) {
            final id = (r['conversation_id'] as String?) ?? '';
            if (id.isEmpty) continue;
            if (!ids.contains(id)) ids.add(id);
          }
          if (ids.isEmpty) return <Map<String, dynamic>>[];
          final convs = await supabase
              .from('conversations')
              .select('id, is_group, title, last_message_at')
              .inFilter('id', ids)
              .order('last_message_at', ascending: false);
          return (convs as List).cast<Map<String, dynamic>>();
        }(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [Text('No conversations yet')],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              final cid = (c['id'] as String?) ?? '';
              return _ConversationTile(conversation: c, onTap: () {
                if (cid.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ConversationPage(conversationId: cid)),
                );
              });
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cid = (conversation['id'] as String?) ?? '';
    final isGroup = (conversation['is_group'] as bool?) ?? false;
    final title = (conversation['title'] as String?) ?? '';
    final uid = supabase.auth.currentUser?.id ?? '';

    final membersStream = supabase
        .from('conversation_members')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', cid);

    final lastMsgStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', cid)
        .order('created_at', ascending: false);

    final readsStream = supabase
        .from('message_reads')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', cid);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: membersStream,
      builder: (context, memSnap) {
        final members = (memSnap.data ?? const []).where((m) => (m['conversation_id'] as String?) == cid).toList();
        String subtitle = '';
        String? otherId;
        if (isGroup) {
          subtitle = '${members.length} members';
        } else {
          for (final m in members) {
            final mid = (m['user_id'] as String?) ?? '';
            if (mid.isNotEmpty && mid != uid) { otherId = mid; break; }
          }
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: lastMsgStream,
          builder: (context, lastSnap) {
            final last = (lastSnap.data ?? const []).where((m) => (m['conversation_id'] as String?) == cid).toList();
            final lastRow = last.isNotEmpty ? last.first : null;
            final lastId = (lastRow?['id'] as int?) ?? -1;
            final lastText = _previewText((lastRow?['content'] as String?) ?? '');
            final lastCreated = (lastRow?['created_at'] as String?) ?? '';

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: readsStream,
              builder: (context, readSnap) {
                final reads = (readSnap.data ?? const [])
                    .where((r) => (r['conversation_id'] as String?) == cid && (r['user_id'] as String?) == uid)
                    .toList();
                final readRow = reads.isNotEmpty ? reads.first : null;
                final readId = (readRow?['last_read_message_id'] as int?) ?? -1;
                final unread = lastId > 0 && lastId > readId;

                return ListTile(
                  leading: isGroup
                      ? const CircleAvatar(child: Icon(Icons.group))
                      : (otherId == null
                          ? const CircleAvatar(child: Icon(Icons.person))
                          : UserAvatar(userId: otherId)),
                  title: isGroup
                      ? Text(title.isNotEmpty ? title : 'Group')
                      : (otherId == null
                          ? const Text('Direct')
                          : _UserTitle(userId: otherId)),
                  subtitle: Text(lastText.isNotEmpty ? lastText : (subtitle.isNotEmpty ? subtitle : 'No messages yet')),
                  trailing: _TrailingTimeAndUnread(iso: lastCreated, unread: unread),
                  onTap: onTap,
                );
              },
            );
          },
        );
      },
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String userId;
  const UserAvatar({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase.from('profiles').select('photo_url').eq('id', userId).maybeSingle(),
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

class _TrailingTimeAndUnread extends StatelessWidget {
  final String iso;
  final bool unread;
  const _TrailingTimeAndUnread({required this.iso, required this.unread});

  String _fmtLocalShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      if (sameDay) return '${two(dt.hour)}:${two(dt.minute)}';
      final sameYear = dt.year == now.year;
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final md = '${months[dt.month - 1]} ${dt.day}';
      if (sameYear) return md;
      return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: (Theme.of(context).textTheme.bodySmall?.color ?? Colors.white).withOpacity(0.7),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_fmtLocalShort(iso), style: style),
        if (unread) const SizedBox(height: 4),
        if (unread) const Icon(Icons.mark_chat_unread, color: Colors.redAccent, size: 18),
      ],
    );
  }
}

class _UserTitle extends StatelessWidget {
  final String userId;
  const _UserTitle({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
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

String _previewText(String content) {
  if (content.startsWith('post:')) return 'Shared a post';
  return content;
}
