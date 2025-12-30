import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/supabase_config.dart';

class AuthServiceSupabase {
  final _auth = Supabase.instance.client.auth;

  Future<String?> signIn({required String email, required String password}) async {
    final res = await _auth.signInWithPassword(email: email, password: password);
    return res.user?.email;
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    username = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(username)) {
      throw Exception('Invalid username (3-20: letters, digits, . or _).');
    }

    // Optional pre-check: is username free?
    // We'll rely on unique constraint on profiles.username

    final res = await _auth.signUp(email: email, password: password);
    final uid = res.user?.id;

    if (uid == null) {
      throw const AuthException('signup_failed');
    }
    try {
      await supabase.from('profiles').insert({
        'id': uid,
        'email': email,
        'username': username,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Username already taken.');
      }
      rethrow;
    }
    return res.user?.email ?? email;
  }

  Future<void> signOut() => _auth.signOut();
}
