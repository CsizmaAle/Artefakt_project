import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/services/follow_service.dart';
import 'package:artefakt_v1/pages/edit_profile_page.dart';
import 'package:artefakt_v1/pages/follow_list_page.dart';
import 'package:artefakt_v1/services/follow_events.dart';
import 'package:artefakt_v1/pages/post_detail_page.dart';

class ProfilePage extends StatelessWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetUid = userId ?? currentUser?.id;

    if (targetUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You need to be signed in.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
                child: const Text('Go to login'),
              ),
            ],
          ),
        ),
      );
    }

    final viewingSelf = currentUser != null && currentUser.id == targetUid;

    final userFuture = supabase.from('profiles').select().eq('id', targetUid).maybeSingle();
    final postsFuture = supabase.from('posts').select().eq('author_id', targetUid).order('created_at', ascending: false);

    return Scaffold(
      appBar: viewingSelf ? null : AppBar(title: Text(viewingSelf ? 'My Profile' : 'Profile')),
      body: ValueListenableBuilder<int>(
        valueListenable: FollowEvents.instance.tick,
        builder: (context, tick, __) => StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('profile-$targetUid-$tick'),
          stream: supabase
              .from('profiles')
              .stream(primaryKey: ['id'])
              .eq('id', targetUid),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final row = (snapshot.data?.isNotEmpty ?? false) ? snapshot.data!.first : null;
          final data = row ?? <String, dynamic>{};
          final username = (data['username'] as String?) ??
              (viewingSelf ? (currentUser.email ?? '') : '');
          final displayName =
              (data['display_name'] as String?) ?? (data['name'] as String?) ?? '';
          final bio = (data['bio'] as String?) ?? '';
          final photoUrl = (data['photo_url'] as String?) ?? '';
          final postsCount = (data['posts_count'] as num?)?.toInt();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person, size: 44) : null,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatTile(label: 'Posts', value: postsCount),
                          ValueListenableBuilder<int>(
                            valueListenable: FollowEvents.instance.tick,
                            builder: (_, __, ___) => _FollowCountTile(
                            label: 'Followers',
                            uid: targetUid,
                            followers: true,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FollowListPage(userId: targetUid, kind: 'followers'),
                                ),
                              );
                            },
                          ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: FollowEvents.instance.tick,
                            builder: (_, __, ___) => _FollowCountTile(
                            label: 'Following',
                            uid: targetUid,
                            followers: false,
                            onTap: () {
                              Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FollowListPage(userId: targetUid, kind: 'following'),
                              ),
                            );
                            },
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  username.isNotEmpty ? '@$username' : 'user',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (displayName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(displayName, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(bio),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: viewingSelf
                          ? OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfilePage(),
                                  ),
                                );
                              },
                              child: const Text('Edit Profile'),
                            )
                          : _FollowButton(targetUid: targetUid),
                    ),
                    
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: postsFuture,
                  builder: (context, postsSnap) {
                    if (postsSnap.connectionState == ConnectionState.waiting && !postsSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = postsSnap.data ?? const [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.photo_library_outlined, size: 48),
                              SizedBox(height: 8),
                              Text('No posts yet'),
                            ],
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        childAspectRatio: 1,
                      ),
                      itemCount: docs.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final post = docs[index];
                        final imageUrl = (post['image_url'] as String?) ?? '';
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostDetailPage(post: post),
                              ),
                            );
                          },
                          child: Container(
                            color: Colors.grey.shade200,
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image)),
                                  )
                                : const Center(child: Icon(Icons.image_not_supported_outlined)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int? value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final styleNum =
        Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final styleLbl = Theme.of(context).textTheme.bodyMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text((value ?? 0).toString(), style: styleNum),
        const SizedBox(height: 2),
        Text(label, style: styleLbl),
      ],
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String targetUid;
  const _FollowButton({required this.targetUid});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool? _isFollowing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await supabase
        .from('follows')
        .select('follower_id')
        .eq('follower_id', user.id)
        .eq('target_id', widget.targetUid)
        .maybeSingle();
    if (!mounted) return;
    setState(() => _isFollowing = res != null);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return OutlinedButton(
        onPressed: () => Navigator.of(context).pushNamed('/login'),
        child: const Text('Sign in to follow'),
      );
    }

    final isFollowing = _isFollowing;
    return OutlinedButton(
      onPressed: isFollowing == null
          ? null
          : () async {
              final service = FollowService();
              try {
                if (isFollowing) {
                  await service.unfollow(currentUid: user.id, targetUid: widget.targetUid);
                  if (mounted) setState(() => _isFollowing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unfollowed')),
                  );
                } else {
                  await service.follow(currentUid: user.id, targetUid: widget.targetUid);
                  if (mounted) setState(() => _isFollowing = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Followed')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action failed: $e')),
                );
              }
            },
      child: Text(isFollowing == true ? 'Unfollow' : 'Follow'),
    );
  }
}

class _FollowCountTile extends StatelessWidget {
  final String label;
  final String uid;
  final bool followers; // true => count where targetId == uid; false => followerId == uid
  final VoidCallback? onTap;
  const _FollowCountTile({required this.label, required this.uid, required this.followers, this.onTap});

  @override
  Widget build(BuildContext context) {
    final field = followers ? 'target_id' : 'follower_id';
    final stream = supabase
        .from('follows')
        .stream(primaryKey: ['follower_id', 'target_id'])
        .eq(field, uid);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final count = (snap.data?.length ?? 0);
        final tile = _StatTile(label: label, value: count);
        return onTap == null
            ? tile
            : InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: tile,
                ),
              );
      },
    );
  }
}
