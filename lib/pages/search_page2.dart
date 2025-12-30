import 'dart:async';
import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'profile_public_page.dart';
import 'package:artefakt_v1/widgets/posts_results_cards.dart';
import 'package:artefakt_v1/widgets/recent_users.dart';
import 'package:artefakt_v1/widgets/recent_posts.dart';
import 'package:artefakt_v1/services/search_history_service.dart';
import 'package:artefakt_v1/services/wikipedia_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _queryCtrl = TextEditingController();
  Timer? _debounce;
  final WikipediaService _wikiService = WikipediaService();

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

  void _openCulturalizeDialog() {
    final initialTopic = _queryCtrl.text.trim();
    final initialLanguage = Localizations.localeOf(context).languageCode;

    showDialog<void>(
      context: context,
      builder: (_) => _CulturalizeDialog(
        initialTopic: initialTopic,
        initialLanguage: initialLanguage,
        service: _wikiService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _queryCtrl.text.trim();
    final qLower = q.toLowerCase();

    return Stack(
      children: [
        SafeArea(
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
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _openCulturalizeDialog,
            label: const Text('Culturalize me'),
            icon: const Icon(Icons.public),
          ),
        ),
      ],
    );
  }
}

class _CulturalizeDialog extends StatefulWidget {
  final String initialTopic;
  final String initialLanguage;
  final WikipediaService service;

  const _CulturalizeDialog({
    required this.initialTopic,
    required this.initialLanguage,
    required this.service,
  });

  @override
  State<_CulturalizeDialog> createState() => _CulturalizeDialogState();
}

class _CulturalizeDialogState extends State<_CulturalizeDialog> {
  late final TextEditingController _topicCtrl;
  String? _error;
  WikipediaSummary? _summary;
  bool _loading = false;
  List<String> _imagePool = const [];
  List<String> _visibleImages = const [];
  final Set<String> _failedImages = {};
  late String _langValue;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.initialTopic);
    _langValue = _normalizeLang(widget.initialLanguage);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
      _imagePool = const [];
      _visibleImages = const [];
      _failedImages.clear();
    });
    try {
      final res = await widget.service.fetchSummary(
        topic: _topicCtrl.text,
        languageCode: _langValue,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _summary = res;
        _imagePool = res.imageUrls;
        _visibleImages = res.imageUrls.take(7).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleImageError(int index, String url) {
    if (_failedImages.contains(url)) return;
    _failedImages.add(url);
    for (final candidate in _imagePool) {
      if (_failedImages.contains(candidate)) continue;
      if (_visibleImages.contains(candidate)) continue;
      setState(() {
        _visibleImages[index] = candidate;
      });
      return;
    }
    setState(() {
      _visibleImages[index] = '';
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() => _error = 'Invalid link.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open the link.');
    }
  }

  String _normalizeLang(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.startsWith('ro')) return 'ro';
    return 'en';
  }

  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Culturalize me'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _topicCtrl,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Topic or painter',
                  hintText: 'e.g. Frida Kahlo',
                ),
                onSubmitted: (_) => _runSearch(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _langValue,
                decoration: const InputDecoration(
                  labelText: 'Language',
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                  DropdownMenuItem(value: 'ro', child: Text('Romanian (RO)')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _langValue = value);
                },
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (_summary != null) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary!.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _summary!.extract,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                          textAlign: TextAlign.left,
                        ),
                        if (_visibleImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _visibleImages.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final url = _visibleImages[i];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: url.isEmpty
                                        ? Container(
                                            color: Theme.of(context).colorScheme.surfaceVariant,
                                            child: const Center(child: Icon(Icons.broken_image)),
                                          )
                                        : InkWell(
                                            onTap: () => _openImagePreview(url),
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) {
                                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  if (mounted) _handleImageError(i, url);
                                                });
                                                return Container(
                                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                                  child: const Center(child: Icon(Icons.broken_image)),
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'No images available for this topic.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (_summary!.url.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openUrl(_summary!.url),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open on Wikipedia'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _runSearch,
          child: const Text('Search'),
        ),
      ],
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
