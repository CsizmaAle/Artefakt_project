import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/services/follow_events.dart';

class FollowService {
  Future<void> follow({required String currentUid, required String targetUid}) async {
    if (currentUid == targetUid) {
      throw Exception('You cannot follow yourself.');
    }

    // Validate target via profiles
    final target = await supabase
        .from('profiles')
        .select('id')
        .eq('id', targetUid)
        .maybeSingle();
    if (target == null) throw Exception('Target user does not exist.');

    try {
      await supabase.from('follows').insert({
        'follower_id': currentUid,
        'target_id': targetUid,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Notify UI to refresh counts immediately
      FollowEvents.instance.notify();
    } catch (e) {
      // Ignore duplicate insert (unique on follower_id,target_id) if thrown
      // You can inspect PostgrestException code '23505' to be precise.
    }
  }

  Future<void> unfollow({required String currentUid, required String targetUid}) async {
    if (currentUid == targetUid) {
      throw Exception('You cannot unfollow yourself.');
    }
    await supabase
        .from('follows')
        .delete()
        .eq('follower_id', currentUid)
        .eq('target_id', targetUid);
    // Notify UI to refresh counts immediately
    FollowEvents.instance.notify();
  }

  Future<bool> isFollowing({required String currentUid, required String targetUid}) async {
    final row = await supabase
        .from('follows')
        .select('follower_id')
        .eq('follower_id', currentUid)
        .eq('target_id', targetUid)
        .maybeSingle();
    return row != null;
  }

  Future<int> followersCount(String userId) async {
    final res = await supabase
        .from('follows')
        .select('follower_id')
        .eq('target_id', userId);
    return (res as List).length;
  }

  Future<int> followingCount(String userId) async {
    final res = await supabase
        .from('follows')
        .select('target_id')
        .eq('follower_id', userId);
    return (res as List).length;
  }
}
