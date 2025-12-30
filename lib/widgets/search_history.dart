import 'package:flutter/material.dart';
import 'package:artefakt_v1/services/search_history_service.dart';

class SearchHistory extends StatelessWidget {
  final void Function(String query, String type)? onSelect;
  final SearchHistoryService _svc = SearchHistoryService();
  SearchHistory({super.key, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.myHistoryStream(limit: 20),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent searches', style: Theme.of(context).textTheme.labelLarge),
                  TextButton(
                    onPressed: () async { await _svc.clearMine(); },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in items)
                    ActionChip(
                      avatar: Icon(
                        (r['search_type'] == 'user') ? Icons.person_outline : Icons.article_outlined,
                        size: 16,
                      ),
                      label: Text((r['query'] as String?) ?? ''),
                      onPressed: onSelect == null
                          ? null
                          : () => onSelect!.call((r['query'] as String?) ?? '', (r['search_type'] as String?) ?? 'post'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

