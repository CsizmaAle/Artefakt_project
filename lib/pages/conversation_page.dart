import 'dart:async';
import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/services/messages_service.dart';

class ConversationPage extends StatefulWidget {
  final String conversationId;
  const ConversationPage({super.key, required this.conversationId});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final _svc = MessagesService();
  int? _lastMessageId;
  Timer? _markReadDebounce;
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _localEcho = [];
  
  String _dayLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thatDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(thatDay).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _fmtLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      bool sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      String two(int n) => n.toString().padLeft(2, '0');
      if (sameDay) {
        return '${two(dt.hour)}:${two(dt.minute)}';
      }
      bool sameYear = dt.year == now.year;
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final md = '${months[dt.month - 1]} ${dt.day}';
      final hm = '${two(dt.hour)}:${two(dt.minute)}';
      return sameYear ? '$md, $hm' : '${dt.year}-$two(dt.month)-$two(dt.day) $hm';
    } catch (_) {
      return iso;
    }
  }

  @override
  void dispose() {
    _markReadDebounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _scheduleMarkRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 300), () {
      _svc.markRead(conversationId: widget.conversationId, lastMessageId: _lastMessageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;

    final convStream = supabase
        .from('conversations')
        .stream(primaryKey: ['id']);
    final membersStream = supabase
        .from('conversation_members')
        .stream(primaryKey: ['conversation_id', 'user_id']);

    final msgsStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: convStream,
      builder: (context, convSnap) {
        final conv = (convSnap.data ?? const [])
            .firstWhere(
                (c) => (c['id'] as String?) == widget.conversationId,
                orElse: () => <String, dynamic>{},
            );
        final title = ((conv['title'] as String?) ?? 'Conversation');
        final isGroup = (conv['is_group'] as bool?) ?? false;
        return Scaffold(
          appBar: AppBar(
            title: isGroup
                ? Text(title.isNotEmpty ? title : 'Group')
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: membersStream,
                    builder: (context, memSnap) {
                      final rows = (memSnap.data ?? const [])
                          .where((m) => (m['conversation_id'] as String?) == widget.conversationId)
                          .toList();
                      String? otherId;
                      for (final r in rows) {
                        final mid = (r['user_id'] as String?) ?? '';
                        if (mid.isNotEmpty && mid != uid) { otherId = mid; break; }
                      }
                      if (otherId == null) return const Text('Direct');
                      return _TitleWithAvatar(userId: otherId!);
                    },
                  ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: msgsStream,
                  builder: (context, msgsSnap) {
                    final fromStream = (msgsSnap.data ?? const [])
                        .where((m) => (m['conversation_id'] as String?) == widget.conversationId)
                        .toList();
                    final seenIds = <int>{
                      for (final m in fromStream) if (m['id'] is int) m['id'] as int
                    };
                    final merged = <Map<String, dynamic>>[
                      ...fromStream,
                      ..._localEcho.where((m) => m['id'] is int ? !seenIds.contains(m['id'] as int) : true),
                    ]..sort((a, b) {
                        final at = DateTime.tryParse((a['created_at'] as String?) ?? '');
                        final bt = DateTime.tryParse((b['created_at'] as String?) ?? '');
                        if (at != null && bt != null) return at.compareTo(bt);
                        return ((a['created_at'] as String?) ?? '').compareTo((b['created_at'] as String?) ?? '');
                      });
                    if (merged.isNotEmpty) {
                      final lastId = (merged.last['id'] as int?);
                      if (lastId != null) {
                        _lastMessageId = lastId;
                        _scheduleMarkRead();
                      }
                    }
                    // Build list with day separators
                    final items = <Map<String, dynamic>>[];
                    String? lastDayKey;
                    for (final m in merged) {
                      final created = (m['created_at'] as String?) ?? '';
                      DateTime? dt;
                      try { dt = DateTime.parse(created).toLocal(); } catch (_) {}
                      final dayKey = dt == null ? created : '${dt.year}-${dt.month}-${dt.day}';
                      if (dayKey != lastDayKey) {
                        items.add({'__separator': true, 'label': _dayLabel(created)});
                        lastDayKey = dayKey;
                      }
                      items.add(m);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      reverse: false,
                      controller: _scrollCtrl,
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final row = items[i];
                        if (row['__separator'] == true) {
                          final label = (row['label'] as String?) ?? '';
                          if (label.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(height: 1)),
                                const SizedBox(width: 8),
                                Text(label, style: Theme.of(context).textTheme.labelSmall),
                                const SizedBox(width: 8),
                                const Expanded(child: Divider(height: 1)),
                              ],
                            ),
                          );
                        }
                        final m = row;
                        final senderId = (m['sender_id'] as String?) ?? '';
                        final mine = uid != null && senderId == uid;
                        final content = (m['content'] as String?) ?? '';
                        final createdAt = (m['created_at'] as String?) ?? '';
                        final bubble = ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              child: Column(
                                crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if ((m['attachment_url'] as String?)?.isNotEmpty ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Image.network(
                                        m['attachment_url'] as String,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  if (content.isNotEmpty) Text(content),
                                  const SizedBox(height: 2),
                                  Builder(builder: (context) {
                                    final base = Theme.of(context).textTheme.bodySmall;
                                    final faded = base?.copyWith(
                                      color: (base?.color ?? Colors.white).withOpacity(0.7),
                                    );
                                    return Text(_fmtLocal(createdAt), style: faded);
                                  }),
                                ],
                              ),
                            ),
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) ...[
                                _MiniAvatar(userId: senderId),
                                const SizedBox(width: 6),
                                bubble,
                              ] else ...[
                                bubble,
                                const SizedBox(width: 6),
                                _MiniAvatar(userId: senderId),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          final text = _textCtrl.text.trim();
                          if (text.isEmpty) return;
                          _textCtrl.clear();
                          final row = await _svc.sendMessage(
                            conversationId: widget.conversationId,
                            content: text,
                          );
                          if (row != null) {
                            setState(() {
                              _localEcho.add(row);
                            });
                            await Future.delayed(const Duration(milliseconds: 50));
                            if (_scrollCtrl.hasClients) {
                              _scrollCtrl.animateTo(
                                _scrollCtrl.position.maxScrollExtent + 120,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TitleWithAvatar extends StatelessWidget {
  final String userId;
  const _TitleWithAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('profiles')
          .select('username, display_name, photo_url')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snap) {
        final row = snap.data;
        final username = (row?['username'] as String?) ?? '';
        final displayName = (row?['display_name'] as String?) ?? '';
        final photoUrl = (row?['photo_url'] as String?) ?? '';
        final text = displayName.isNotEmpty ? displayName : (username.isNotEmpty ? '@$username' : 'Direct');
        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
            Text(text),
          ],
        );
      },
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String userId;
  const _MiniAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('profiles')
          .select('photo_url')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snap) {
        final photoUrl = (snap.data?['photo_url'] as String?) ?? '';
        return CircleAvatar(
          radius: 12,
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
        );
      },
    );
  }
}
