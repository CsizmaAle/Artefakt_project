import 'package:flutter/material.dart';
import 'package:artefakt_v1/supabase_config.dart';
import 'package:artefakt_v1/pages/post_detail_page.dart';
import 'package:artefakt_v1/widgets/user_header.dart';

class RecentPosts extends StatelessWidget {
  const RecentPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final historyStream = supabase
        .from('search_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: historyStream,
      builder: (context, snap) {
        final rows = (snap.data ?? const [])
            .where((r) => (r['search_type'] as String?) == 'post')
            .toList();
        final seen = <String>{};
        final ids = <String>[];
        for (final r in rows) {
          final q = (r['query'] as String?) ?? '';
          if (q.isEmpty || seen.contains(q)) continue;
          seen.add(q);
          ids.add(q);
          if (ids.length >= 3) break;
        }
        if (ids.isEmpty) return const SizedBox.shrink();

        final futures = ids.map((id) => supabase
            .from('posts')
            .select('id, body, image_url, author_id, created_at')
            .eq('id', id)
            .maybeSingle());

        return FutureBuilder<List<Map<String, dynamic>?>>(
          future: Future.wait(futures),
          builder: (context, postSnap) {
            final ordered = (postSnap.data ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList();
            if (ordered.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 18),
                          const SizedBox(width: 8),
                          Text('Recent posts', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...ordered.map((p) {
                      final imageUrl = (p['image_url'] as String?) ?? '';
                      final body = (p['body'] as String?) ?? '';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
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
                              if (body.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                  child: Text(body),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
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
