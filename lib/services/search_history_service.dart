import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/supabase_config.dart';

class SearchHistoryService {
  final _c = Supabase.instance.client;

  Future<void> log({required String query, required String searchType}) async {
    final user = _c.auth.currentUser;
    if (user == null) return;
    if (query.trim().isEmpty) return;
    final type = (searchType == 'user') ? 'user' : 'post';
    try {
      await _c.from('search_history').insert({
        'user_id': user.id,
        'query': query.trim(),
        'search_type': type,
      });
    } catch (_) {
      // ignore
    }
  }

  Stream<List<Map<String, dynamic>>> myHistoryStream({int limit = 20}) {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) {
      // empty stream for unauthenticated
      return Stream.value(const []);
    }
    return supabase
        .from('search_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<void> clearMine() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('search_history').delete().eq('user_id', uid);
  }
}

