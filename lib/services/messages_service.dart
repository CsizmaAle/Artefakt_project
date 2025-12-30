import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesService {
  final _c = Supabase.instance.client;

  Future<String?> startDmWith(String otherUserId) async {
    try {
      final res = await _c.rpc('start_dm', params: {'other_user': otherUserId});
      final id = (res as String?)?.trim();
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final inserted = await _c.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': content,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
    }).select().maybeSingle();
    try {
      await _c.from('conversations').update({'last_message_at': DateTime.now().toIso8601String()}).eq('id', conversationId);
    } catch (_) {
      // ignore
    }
    return (inserted is Map<String, dynamic>) ? inserted : null;
  }

  Future<void> markRead({required String conversationId, int? lastMessageId}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _c.from('message_reads').upsert({
        'conversation_id': conversationId,
        'user_id': uid,
        if (lastMessageId != null) 'last_read_message_id': lastMessageId,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'conversation_id,user_id');
    } catch (_) {
      // ignore
    }
  }
}
