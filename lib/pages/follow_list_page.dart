import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/pages/profile_page.dart';

class FollowListPage extends StatefulWidget {
  /// kind: 'followers' or 'following'
  final String userId;
  final String kind;
  const FollowListPage({super.key, required this.userId, required this.kind});

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String get _title => widget.kind == 'followers' ? 'Followers' : 'Following';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List ids;
      if (widget.kind == 'followers') {
        ids = await supabase
            .from('follows')
            .select('follower_id')
            .eq('target_id', widget.userId);
      } else {
        ids = await supabase
            .from('follows')
            .select('target_id')
            .eq('follower_id', widget.userId);
      }
      if (ids.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final idList = ids.map((e) => widget.kind == 'followers' ? e['follower_id'] : e['target_id']).toList();

      final profiles = await supabase
          .from('profiles')
          .select('id, username, display_name, photo_url')
          .inFilter('id', idList);

      setState(() {
        _items = (profiles as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No users yet'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = _items[i];
                    final name = (u['display_name'] ?? u['username'] ?? u['id']).toString();
                    final avatar = u['photo_url'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                        child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
                      ),
                      title: Text(name),
                      subtitle: Text('@${u['username'] ?? ''}'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: u['id'] as String),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
