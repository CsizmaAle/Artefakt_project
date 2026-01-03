import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/widgets/user_header.dart';
import 'package:artefakt_v1/pages/post_detail_page.dart';
import 'package:artefakt_v1/services/search_history_service.dart';

class PostsResultsCards extends StatelessWidget {
  final String queryLower;
  final String rawQuery;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  const PostsResultsCards({
    super.key,
    required this.queryLower,
    required this.rawQuery,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final selectCols = 'id, body, image_url, author_id, created_at';
    final future = queryLower.isEmpty
        ? supabase
            .from('posts')
            .select(selectCols)
            .order('created_at', ascending: false)
            .limit(30)
        : supabase
            .from('posts')
            .select(selectCols)
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
          padding: padding ?? const EdgeInsets.all(12),
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = docs[i];
            final text = (p['body'] as String?) ?? '';
            final imageUrl = (p['image_url'] as String?) ?? '';
            final id = (p['id'] as String?) ?? '';
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  if (id.isEmpty) return;
                  // Log history as a post access (store post id)
                  SearchHistoryService().log(query: id, searchType: 'post');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PostDetailPage(post: p)),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((p['author_id'] as String?)?.isNotEmpty ?? false)
                      UserHeader(
                        userId: p['author_id'] as String,
                        subtitle: (p['created_at'] as String?) ?? '',
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      ),
                    if (imageUrl.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Text(text),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
