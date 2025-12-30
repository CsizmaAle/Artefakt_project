import 'package:artefakt_v1/supabase_config.dart';

class ProfileService {

  Future<void> updateProfile({
    required String uid,
    String? newUsername, // lowercase 3-20 [a-z0-9_.]
    String? bio,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (bio != null) updates['bio'] = bio.trim().isEmpty ? null : bio.trim();
    if (photoUrl != null) updates['photo_url'] = photoUrl.trim().isEmpty ? null : photoUrl.trim();

    if (newUsername != null) {
      final u = newUsername.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(u)) {
        throw Exception('Username invalid (3-20: letters, digits, . or _).');
      }

      // Update profiles.username (relies on unique constraint; will throw if taken)
      await supabase.from('profiles').update({
        ...updates,
        'username': u,
      }).eq('id', uid);
      return;
    }

    if (updates.length > 1) {
      await supabase.from('profiles').update(updates).eq('id', uid);
    }
  }
}
