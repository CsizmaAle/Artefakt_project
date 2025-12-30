import 'dart:async';
import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'profile_public_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _queryCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _queryCtrl.text.trim();
    final qLower = q.toLowerCase();

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryCtrl,
                onChanged: _onTextChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search users or posts',
                ),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Users'),
                Tab(text: 'Posts'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _UsersResults(queryLower: qLower),
                  _PostsResults(queryLower: qLower),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersResults extends StatelessWidget {
  final String queryLower;
  const _UsersResults({required this.queryLower});

  @override
  Widget build(BuildContext context) {
    if (queryLower.isEmpty) {
      return const Center(child: Text('Search for a user'));
    }
    final future = supabase
        .from('profiles')
        .select('id, username, display_name, photo_url')
        .ilike('username', '$queryLower%')
        .limit(20);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = docs[i];
            final username = (u['username'] as String?) ?? '';
            final name = (u['display_name'] as String?) ?? '';
            final photoUrl = (u['photo_url'] as String?) ?? '';
            final userId = (u['id'] as String?) ?? '';
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(name.isNotEmpty ? name : (username.isEmpty ? 'user' : '@$username')),
              subtitle: username.isNotEmpty && name.isNotEmpty ? Text('@$username') : null,
              onTap: () {
                if (userId.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfilePublicPage(userId: userId)),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PostsResults extends StatelessWidget {
  final String queryLower;
  const _PostsResults({required this.queryLower});

  @override
  Widget build(BuildContext context) {
    final future = queryLower.isEmpty
        ? supabase.from('posts').select().order('created_at', ascending: false).limit(30)
        : supabase.from('posts').select().ilike('title', '$queryLower%').limit(30);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No posts found'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = docs[i];
            final text = (p['content_text'] as String?) ?? '';\n            final image = (p['image_url'] as String?) ?? '';\n            final preview = text.isNotEmpty ? text : (image.isNotEmpty ? '[image]' : '(empty)');\n            return ListTile(\n              leading: image.isNotEmpty ? const Icon(Icons.image) : const Icon(Icons.notes),\n              title: Text(preview.length > 60 ? preview.substring(0, 60) + '…' : preview),\n            );
          },
        );
      },
    );
  }
}

