import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaSummary {
  final String title;
  final String extract;
  final String url;
  final List<String> imageUrls;

  const WikipediaSummary({
    required this.title,
    required this.extract,
    required this.url,
    required this.imageUrls,
  });
}

class WikipediaService {
  Future<WikipediaSummary> fetchSummary({
    required String topic,
    required String languageCode,
  }) async {
    final cleanedTopic = topic.trim();
    if (cleanedTopic.isEmpty) {
      throw Exception('Please enter a topic.');
    }

    final lang = _normalizeLanguage(languageCode);
    if (lang != 'en' && lang != 'ro') {
      throw Exception('Only en and ro are supported right now.');
    }
    final resolvedTitle = await _searchTitle(
      languageCode: lang,
      query: cleanedTopic,
    );
    final requestedTitle = resolvedTitle ?? cleanedTopic;
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'extracts|info|categories',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'redirects': '1',
      'cllimit': '50',
      'origin': '*',
      'titles': requestedTitle,
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Wikipedia request failed (${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final query = data['query'] as Map<String, dynamic>?;
    final pages = query?['pages'] as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) {
      throw Exception('No results found.');
    }

    final first = pages.values.first as Map<String, dynamic>;
    if (first['missing'] != null) {
      throw Exception('No results found.');
    }

    final title = (first['title'] as String?) ?? cleanedTopic;
    final extract = (first['extract'] as String?) ?? '';
    final url = (first['fullurl'] as String?) ?? '';
    final categories = (first['categories'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>)['title'] as String?)
            .whereType<String>()
            .toList() ??
        const [];

    if (!_isArtRelated(categories: categories, languageCode: lang)) {
      throw Exception('Please search for an art or culture related topic.');
    }

    if (extract.trim().isEmpty) {
      throw Exception('No summary available.');
    }

    final images = await _fetchImageUrls(
      languageCode: lang,
      title: title,
      query: cleanedTopic,
    );

    return WikipediaSummary(
      title: title,
      extract: extract,
      url: url,
      imageUrls: images,
    );
  }

  bool _isArtRelated({
    required List<String> categories,
    required String languageCode,
  }) {
    if (categories.isEmpty) return false;
    final lang = _normalizeLanguage(languageCode);
    final allowed = _allowedCategoryMatchers(lang);
    for (final raw in categories) {
      final normalized = _normalizeCategory(raw, lang);
      if (normalized.isEmpty) continue;
      if (_isIgnoredCategory(normalized, lang)) continue;
      if (allowed.any((re) => re.hasMatch(normalized))) return true;
    }
    return false;
  }

  List<RegExp> _allowedCategoryMatchers(String languageCode) {
    if (languageCode == 'ro') {
      return [
        RegExp(r'\barta\b'),
        RegExp(r'\bartist\b'),
        RegExp(r'\bartisti\b'),
        RegExp(r'\bpictor\b'),
        RegExp(r'\bpictori\b'),
        RegExp(r'\bpictura\b'),
        RegExp(r'\bpicturi\b'),
        RegExp(r'\bsculptura\b'),
        RegExp(r'\bsculptor\b'),
        RegExp(r'\bmuzeu\b'),
        RegExp(r'\bmuzee\b'),
        RegExp(r'\bgalerie\b'),
        RegExp(r'\bgalerii\b'),
        RegExp(r'\bcultura\b'),
        RegExp(r'\bistorie a artei\b'),
        RegExp(r'\barhitectura\b'),
        RegExp(r'\bfotografie\b'),
        RegExp(r'\bdesign\b'),
        RegExp(r'\bmiscare artistica\b'),
      ];
    }
    return [
      RegExp(r'\bart\b'),
      RegExp(r'\bartist\b'),
      RegExp(r'\bartists\b'),
      RegExp(r'\bpainting\b'),
      RegExp(r'\bpaintings\b'),
      RegExp(r'\bpainter\b'),
      RegExp(r'\bpainters\b'),
      RegExp(r'\bsculpture\b'),
      RegExp(r'\bsculptor\b'),
      RegExp(r'\bmuseum\b'),
      RegExp(r'\bgallery\b'),
      RegExp(r'\bculture\b'),
      RegExp(r'\bcultural\b'),
      RegExp(r'\bart history\b'),
      RegExp(r'\barchitecture\b'),
      RegExp(r'\bphotography\b'),
      RegExp(r'\bdesign\b'),
      RegExp(r'\bart movement\b'),
    ];
  }

  String _normalizeCategory(String raw, String languageCode) {
    final lower = raw.toLowerCase();
    final prefix = languageCode == 'ro' ? 'categorie:' : 'category:';
    final cleaned = lower.startsWith(prefix) ? lower.substring(prefix.length) : lower;
    return cleaned.trim();
  }

  bool _isIgnoredCategory(String category, String languageCode) {
    final ignored = languageCode == 'ro'
        ? [
            RegExp(r'^articole\b'),
            RegExp(r'^pagini\b'),
            RegExp(r'^formate\b'),
            RegExp(r'^wikidata\b'),
            RegExp(r'^commons\b'),
            RegExp(r'^infocaseta\b'),
            RegExp(r'^date\b'),
            RegExp(r'^coordonate\b'),
            RegExp(r'^redirigari\b'),
            RegExp(r'^wikipedia\b'),
            RegExp(r'^schite\b'),
          ]
        : [
            RegExp(r'^articles\b'),
            RegExp(r'^pages\b'),
            RegExp(r'^cs1\b'),
            RegExp(r'^use dmy dates\b'),
            RegExp(r'^use mdy dates\b'),
            RegExp(r'^short description\b'),
            RegExp(r'^coordinates\b'),
            RegExp(r'^wikidata\b'),
            RegExp(r'^commons\b'),
            RegExp(r'^infobox\b'),
            RegExp(r'^templates?\b'),
            RegExp(r'^redirects?\b'),
            RegExp(r'^wikipedia\b'),
            RegExp(r'^stubs?\b'),
          ];
    return ignored.any((re) => re.hasMatch(category));
  }

  Future<String?> _searchTitle({
    required String languageCode,
    required String query,
  }) async {
    final uri = Uri.https('$languageCode.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'list': 'search',
      'srlimit': '1',
      'srsearch': query,
      'origin': '*',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final queryData = data['query'] as Map<String, dynamic>?;
    final results = queryData?['search'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final title = first['title'] as String?;
    return title;
  }

  Future<List<String>> _fetchImageUrls({
    required String languageCode,
    required String title,
    required String query,
  }) async {
    const maxPool = 12;
    final primary = await _fetchImageUrlsFromRest(
      languageCode: languageCode,
      title: title,
    );
    if (primary.length >= maxPool) {
      return primary.sublist(0, maxPool);
    }

    final fallback = await _fetchImageUrlsFromQuery(
      languageCode: languageCode,
      title: title,
    );

    final combined = <String>[];
    for (final url in [...primary, ...fallback]) {
      if (!combined.contains(url)) combined.add(url);
      if (combined.length >= maxPool) break;
    }

    if (combined.length >= maxPool) return combined;

    final commons = await _fetchImageUrlsFromCommons(
      query: title,
      limit: maxPool - combined.length,
    );
    for (final url in commons) {
      if (!combined.contains(url)) combined.add(url);
      if (combined.length >= maxPool) break;
    }

    if (combined.length < maxPool && query.trim().isNotEmpty && query != title) {
      final extra = await _fetchImageUrlsFromCommons(
        query: query,
        limit: maxPool - combined.length,
      );
      for (final url in extra) {
        if (!combined.contains(url)) combined.add(url);
        if (combined.length >= maxPool) break;
      }
    }

    return combined;
  }

  Future<List<String>> _fetchImageUrlsFromRest({
    required String languageCode,
    required String title,
  }) async {
    final encodedTitle = Uri.encodeComponent(title);
    final uri = Uri.https(
      '$languageCode.wikipedia.org',
      '/api/rest_v1/page/media/$encodedTitle',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return const [];

    final urls = <String>[];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      if (item['type'] != 'image') continue;
      final url = _pickMediaUrl(item);
      if (url == null) continue;
      if (!_isLikelyPhoto(url)) continue;
      if (!urls.contains(url)) urls.add(url);
      if (urls.length >= 7) break;
    }
    return urls;
  }

  String? _pickMediaUrl(Map<String, dynamic> item) {
    final thumb = item['thumbnail'] as Map<String, dynamic>?;
    final original = item['original'] as Map<String, dynamic>?;
    final thumbUrl = thumb?['source'] as String?;
    if (thumbUrl != null) return thumbUrl;
    final originalUrl = original?['source'] as String?;
    if (originalUrl == null) return null;
    if (_isSvgUrl(originalUrl)) return null;
    return originalUrl;
  }

  Future<List<String>> _fetchImageUrlsFromQuery({
    required String languageCode,
    required String title,
  }) async {
    final uri = Uri.https('$languageCode.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'generator': 'images',
      'titles': title,
      'gimlimit': '20',
      'prop': 'imageinfo',
      'iiprop': 'url|mime',
      'iiurlwidth': '600',
      'origin': '*',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final query = data['query'] as Map<String, dynamic>?;
    final pages = query?['pages'] as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) return const [];

    final urls = <String>[];
    for (final value in pages.values) {
      final page = value as Map<String, dynamic>;
      final imageInfo = page['imageinfo'] as List<dynamic>?;
      if (imageInfo == null || imageInfo.isEmpty) continue;
      final url = _pickImageInfoUrl(imageInfo.first as Map<String, dynamic>);
      if (url == null) continue;
      if (!_isLikelyPhoto(url)) continue;
      if (!urls.contains(url)) urls.add(url);
      if (urls.length >= 7) break;
    }
    return urls;
  }

  Future<List<String>> _fetchImageUrlsFromCommons({
    required String query,
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    final searchUri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'list': 'search',
      'srsearch': query,
      'srlimit': limit.toString(),
      'srnamespace': '6',
      'origin': '*',
    });

    final searchRes = await http.get(searchUri);
    if (searchRes.statusCode != 200) return const [];

    final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final queryData = searchData['query'] as Map<String, dynamic>?;
    final results = queryData?['search'] as List<dynamic>?;
    if (results == null || results.isEmpty) return const [];

    final titles = results
        .map((e) => (e as Map<String, dynamic>)['title'] as String?)
        .whereType<String>()
        .toList();
    if (titles.isEmpty) return const [];

    final infoUri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'imageinfo',
      'iiprop': 'url|mime',
      'iiurlwidth': '600',
      'titles': titles.join('|'),
      'origin': '*',
    });

    final infoRes = await http.get(infoUri);
    if (infoRes.statusCode != 200) return const [];

    final infoData = jsonDecode(infoRes.body) as Map<String, dynamic>;
    final pages = (infoData['query'] as Map<String, dynamic>?)?['pages'] as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) return const [];

    final urls = <String>[];
    for (final value in pages.values) {
      final page = value as Map<String, dynamic>;
      final imageInfo = page['imageinfo'] as List<dynamic>?;
      if (imageInfo == null || imageInfo.isEmpty) continue;
      final url = _pickImageInfoUrl(imageInfo.first as Map<String, dynamic>);
      if (url == null) continue;
      if (!_isLikelyPhoto(url)) continue;
      if (!urls.contains(url)) urls.add(url);
      if (urls.length >= limit) break;
    }
    return urls;
  }

  String? _pickImageInfoUrl(Map<String, dynamic> info) {
    final thumb = info['thumburl'] as String?;
    if (thumb != null) return thumb;
    final mime = info['mime'] as String?;
    if (mime != null && mime.toLowerCase() == 'image/svg+xml') return null;
    final url = info['url'] as String?;
    if (url == null) return null;
    if (_isSvgUrl(url)) return null;
    return url;
  }

  bool _isLikelyPhoto(String url) {
    final lower = url.toLowerCase();
    final filename = _filenameFromUrl(lower);
    if (lower.contains('commons-logo')) return false;
    if (_hasBannedImageToken(lower) || _hasBannedImageToken(filename)) return false;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  bool _hasBannedImageToken(String lowerUrl) {
    const banned = [
      'logo',
      'icon',
      'brush',
      'brushes',
      'vector',
      'clipart',
      'pictogram',
      'symbol',
      'emblem',
      'seal',
      'coat_of_arms',
      'flag',
      'diagram',
      'chart',
      'map',
      'placeholder',
      'favicon',
    ];
    for (final token in banned) {
      if (lowerUrl.contains(token)) return true;
    }
    return false;
  }

  String _filenameFromUrl(String lowerUrl) {
    final uri = Uri.tryParse(lowerUrl);
    if (uri == null) return lowerUrl;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return lowerUrl;
    return segments.last;
  }

  bool _isSvgUrl(String url) {
    return url.toLowerCase().endsWith('.svg');
  }

  String _normalizeLanguage(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty) return 'en';
    final dash = cleaned.split('-').first;
    return dash.isEmpty ? 'en' : dash;
  }
}
