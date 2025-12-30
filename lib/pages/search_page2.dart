import 'dart:async';
import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'profile_public_page.dart';
import 'post_detail_page.dart';
import 'package:artefakt_v1/widgets/posts_results_cards.dart';
import 'package:artefakt_v1/widgets/recent_users.dart';
import 'package:artefakt_v1/widgets/recent_posts.dart';
import 'package:artefakt_v1/services/search_history_service.dart';
import 'package:artefakt_v1/widgets/user_header.dart';

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
                  Column(
                    children: [
                      if (qLower.isEmpty) ...[
                        const RecentUsers(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: Row(
                            children: [
                              Text('All users', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(width: 12),
                              const Expanded(child: Divider(height: 1)),
                            ],
                          ),
                        ),
                      ],
                      Expanded(child: _UsersResults(queryLower: qLower, rawQuery: q)),
                    ],
                  ),
                  Column(
                    children: [
                      if (qLower.isEmpty) ...[
                        const RecentPosts(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: Row(
                            children: [
                              Text('All posts', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(width: 12),
                              const Expanded(child: Divider(height: 1)),
                            ],
                          ),
                        ),
                      ],
                      Expanded(child: PostsResultsCards(queryLower: qLower, rawQuery: q)),
                    ],
                  ),
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
  final String rawQuery;
  const _UsersResults({required this.queryLower, required this.rawQuery});

  @override
  Widget build(BuildContext context) {
    final selectCols = 'id, username, display_name, photo_url';
    final future = queryLower.isEmpty
        ? supabase
            .from('profiles')
            .select(selectCols)
            .limit(60)
        : supabase
            .from('profiles')
            .select(selectCols)
            .ilike('username', '$queryLower%')
            .limit(20);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (queryLower.isNotEmpty && snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? const [];
        if (queryLower.isEmpty) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (docs.isEmpty) return const SizedBox.shrink();
          final shuffled = List<Map<String, dynamic>>.from(docs);
          shuffled.shuffle();
          final picks = shuffled.take(6).toList();
          return ListView.separated(
            itemCount: picks.length,
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final u = picks[i];
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
        }
        if (docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }
        return ListView.separated(
          itemCount: docs.length,
          padding: const EdgeInsets.all(12),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                SearchHistoryService().log(query: userId, searchType: 'user');
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
        ? supabase
            .from('posts')
            .select('id, body, image_url, author_id, created_at')
            .order('created_at', ascending: false)
            .limit(30)
        : supabase
            .from('posts')
            .select('id, body, image_url, author_id, created_at')
            .ilike('body', '%$queryLower%')
            .order('created_at', ascending: false)
            .limit(30);

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
            final text = (p['body'] as String?) ?? '';
            final image = (p['image_url'] as String?) ?? '';
            final preview = text.isNotEmpty ? text : (image.isNotEmpty ? '[image]' : '(empty)');
            return ListTile(
              leading: image.isNotEmpty ? const Icon(Icons.image) : const Icon(Icons.notes),
              title: Text(preview.length > 60 ? '${preview.substring(0, 60)}…' : preview),
            );
          },
        );
      },
    );
  }
}
