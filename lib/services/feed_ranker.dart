import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

class FeedRanker {
  FeedRanker._();

  static final FeedRanker instance = FeedRanker._();

  static const _defaultWeights = {
    'is_following': 1.2,
    'is_unseen': 0.7,
    'has_image': 0.15,
    'body_len': 0.25,
    'age_hours': -1.0,
    'likes': 0.35,
    'comments': 0.45,
    'shares': 0.5,
  };

  bool _loaded = false;
  double _bias = 0.0;
  Map<String, double> _weights = Map<String, double>.from(_defaultWeights);
  double _ageHoursCap = 336.0;
  double _bodyLenCap = 500.0;
  double _likesCap = 30.0;
  double _commentsCap = 20.0;
  double _sharesCap = 10.0;

  Future<void> loadFromAssets() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await rootBundle.loadString('assets/models/ranking_weights.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final bias = data['bias'];
      final weights = data['weights'];
      final norms = data['norms'];
      if (bias is num) _bias = bias.toDouble();
      if (weights is Map<String, dynamic>) {
        final parsed = <String, double>{};
        for (final entry in weights.entries) {
          final value = entry.value;
          if (value is num) parsed[entry.key] = value.toDouble();
        }
        if (parsed.isNotEmpty) _weights = parsed;
      }
      if (norms is Map<String, dynamic>) {
        final age = norms['age_hours_cap'];
        final body = norms['body_len_cap'];
        final likes = norms['likes_cap'];
        final comments = norms['comments_cap'];
        final shares = norms['shares_cap'];
        if (age is num && age > 0) _ageHoursCap = age.toDouble();
        if (body is num && body > 0) _bodyLenCap = body.toDouble();
        if (likes is num && likes > 0) _likesCap = likes.toDouble();
        if (comments is num && comments > 0) _commentsCap = comments.toDouble();
        if (shares is num && shares > 0) _sharesCap = shares.toDouble();
      }
    } catch (_) {
      // Use defaults if asset is missing or invalid.
    }
  }

  List<Map<String, dynamic>> rankPosts({
    required List<Map<String, dynamic>> posts,
    required Set<String> followingIds,
    required Set<String> seenIds,
    required String? currentUserId,
  }) {
    if (posts.isEmpty) return posts;

    final now = DateTime.now();
    final scored = <_ScoredPost>[];
    for (final post in posts) {
      final score = _scorePost(
        post: post,
        now: now,
        followingIds: followingIds,
        seenIds: seenIds,
        currentUserId: currentUserId,
      );
      scored.add(_ScoredPost(post, score));
    }

    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return _createdAtFor(b.post).compareTo(_createdAtFor(a.post));
    });

    return [for (final entry in scored) entry.post];
  }

  double _scorePost({
    required Map<String, dynamic> post,
    required DateTime now,
    required Set<String> followingIds,
    required Set<String> seenIds,
    required String? currentUserId,
  }) {
    final postId = (post['id'] as String?) ?? '';
    final authorId = (post['author_id'] as String?) ?? '';
    final body = (post['body'] as String?) ?? (post['content_text'] as String?) ?? '';
    final imageUrl = (post['image_url'] as String?) ?? '';

    final isFollowing = followingIds.contains(authorId) ? 1.0 : 0.0;
    final isSeen = (postId.isNotEmpty && seenIds.contains(postId)) ? 1.0 : 0.0;
    final isUnseen = isSeen > 0 ? 0.0 : 1.0;
    final hasImage = imageUrl.isNotEmpty ? 1.0 : 0.0;

    final likesCount = _intFrom(post, 'likes_count');
    final commentsCount = _intFrom(post, 'comments_count');
    final sharesCount = _intFrom(post, 'shares_count');

    final bodyLen = body.length.toDouble();
    final normalizedBodyLen = (bodyLen / _bodyLenCap).clamp(0.0, 1.0);

    final createdAt = _createdAtFor(post);
    final ageHours = now.difference(createdAt).inMinutes.abs() / 60.0;
    final normalizedAge = (ageHours / _ageHoursCap).clamp(0.0, 1.0);

    final normalizedLikes = _normalizeCount(likesCount, _likesCap);
    final normalizedComments = _normalizeCount(commentsCount, _commentsCap);
    final normalizedShares = _normalizeCount(sharesCount, _sharesCap);

    final ownPostBoost = (currentUserId != null && currentUserId == authorId) ? -0.2 : 0.0;

    var score = _bias + ownPostBoost;
    score += _weight('is_following') * isFollowing;
    score += _weight('is_unseen') * isUnseen;
    score += _weight('has_image') * hasImage;
    score += _weight('body_len') * normalizedBodyLen;
    score += _weight('age_hours') * normalizedAge;
    score += _weight('likes') * normalizedLikes;
    score += _weight('comments') * normalizedComments;
    score += _weight('shares') * normalizedShares;

    return score;
  }

  double _weight(String key) => _weights[key] ?? 0.0;

  double _normalizeCount(int count, double cap) {
    if (count <= 0) return 0.0;
    final safeCap = cap <= 0 ? 1.0 : cap;
    final numerator = math.log(1 + count);
    final denominator = math.log(1 + safeCap);
    if (denominator == 0) return 0.0;
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  int _intFrom(Map<String, dynamic> post, String key) {
    final raw = post[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  DateTime _createdAtFor(Map<String, dynamic> post) {
    final raw = post['created_at'];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _ScoredPost {
  final Map<String, dynamic> post;
  final double score;

  const _ScoredPost(this.post, this.score);
}
