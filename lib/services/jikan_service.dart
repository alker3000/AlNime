import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime_entry.dart';

class JikanAnimeResult {
  final int malId;
  final int anilistId;
  final String title;
  final String slug;
  final String imageUrl;
  final int totalEpisodes;
  final String? synopsis;
  final double? score;
  final int? year;
  final List<String> genres;

  const JikanAnimeResult({
    required this.malId,
    this.anilistId = 0,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.totalEpisodes,
    this.synopsis,
    this.score,
    this.year,
    this.genres = const [],
  });

  factory JikanAnimeResult.fromJikanJson(Map<String, dynamic> json) {
    final englishTitle = json['title_english']?.toString();
    final defaultTitle = json['title']?.toString() ?? 'Unknown Title';
    final resolvedTitle =
        (englishTitle != null && englishTitle.trim().isNotEmpty)
            ? englishTitle.trim()
            : defaultTitle.trim();

    String imageUrl = '';
    if (json['images'] is Map && json['images']['jpg'] is Map) {
      final jpgMap = json['images']['jpg'] as Map;
      imageUrl = (jpgMap['large_image_url'] ?? jpgMap['image_url'] ?? '')
          .toString();
    }

    final genresList = <String>[];
    if (json['genres'] is List) {
      for (final g in json['genres'] as List) {
        if (g is Map && g['name'] != null) {
          genresList.add(g['name'].toString());
        }
      }
    }

    final parsedMalId = (json['mal_id'] is int)
        ? json['mal_id'] as int
        : int.tryParse(json['mal_id']?.toString() ?? '0') ?? 0;

    return JikanAnimeResult(
      malId: parsedMalId,
      anilistId: 0,
      title: resolvedTitle,
      slug: AnimeEntry.generateSlug(resolvedTitle),
      imageUrl: imageUrl,
      totalEpisodes: (json['episodes'] is int)
          ? json['episodes'] as int
          : int.tryParse(json['episodes']?.toString() ?? '0') ?? 0,
      synopsis: json['synopsis']?.toString(),
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : null,
      year: (json['year'] is int) ? json['year'] as int : null,
      genres: genresList,
    );
  }

  factory JikanAnimeResult.fromAniListJson(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>? ?? {};
    final englishTitle = titleMap['english']?.toString();
    final romajiTitle = titleMap['romaji']?.toString() ?? 'Unknown Title';
    final resolvedTitle =
        (englishTitle != null && englishTitle.trim().isNotEmpty)
            ? englishTitle.trim()
            : romajiTitle.trim();

    final coverMap = json['coverImage'] as Map<String, dynamic>? ?? {};
    final imageUrl =
        (coverMap['extraLarge'] ?? coverMap['large'] ?? '').toString();

    final genresList = (json['genres'] is List)
        ? (json['genres'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final rawScore = json['averageScore'];
    final double? normalizedScore = (rawScore is num)
        ? double.parse((rawScore.toDouble() / 10.0).toStringAsFixed(1))
        : null;

    final anilistId = (json['id'] is int)
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0;

    final malId = (json['idMal'] is int)
        ? json['idMal'] as int
        : anilistId;

    return JikanAnimeResult(
      malId: malId,
      anilistId: anilistId,
      title: resolvedTitle,
      slug: AnimeEntry.generateSlug(resolvedTitle),
      imageUrl: imageUrl,
      totalEpisodes: (json['episodes'] is int)
          ? json['episodes'] as int
          : int.tryParse(json['episodes']?.toString() ?? '0') ?? 0,
      synopsis: json['description']?.toString(),
      score: normalizedScore,
      year: (json['seasonYear'] is int) ? json['seasonYear'] as int : null,
      genres: genresList,
    );
  }
}

class JikanService {
  static const String _aniListUrl = 'https://graphql.anilist.co';
  static const String _jikanBaseUrl = 'https://api.jikan.moe/v4/anime';

  static const String _aniListQuery = '''
query (\$search: String) {
  Page(perPage: 10) {
    media(search: \$search, type: ANIME, isAdult: false, sort: SEARCH_MATCH) {
      id
      idMal
      title {
        romaji
        english
      }
      episodes
      averageScore
      seasonYear
      genres
      coverImage {
        extraLarge
        large
      }
    }
  }
}
''';

  /// Searches AniList GraphQL first (fast, globally reachable, returns both anilistId & malId)
  /// and automatically falls back to Jikan API v4 if needed.
  Future<List<JikanAnimeResult>> searchAnime(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // 1. Primary: AniList GraphQL
    try {
      final response = await http
          .post(
            Uri.parse(_aniListUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': _aniListQuery,
              'variables': {'search': trimmed},
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final mediaList =
            decoded['data']?['Page']?['media'] as List<dynamic>? ?? [];
        return mediaList
            .whereType<Map<String, dynamic>>()
            .map(JikanAnimeResult.fromAniListJson)
            .toList();
      }
    } catch (_) {
      // Fall through to Jikan v4 backup
    }

    // 2. Fallback: Jikan API v4
    final uri = Uri.parse(
      '$_jikanBaseUrl?q=${Uri.encodeQueryComponent(trimmed)}&limit=10&sfw=true',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Anime search API returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final dataList = decoded['data'] as List<dynamic>? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map(JikanAnimeResult.fromJikanJson)
        .toList();
  }

  /// Resolves an official AniList ID for an existing anime entry using its MAL ID.
  Future<int?> resolveAnilistIdFromMalId(int malId) async {
    if (malId <= 0) return null;
    const query = '''
query (\$idMal: Int) {
  Media(idMal: \$idMal, type: ANIME) {
    id
  }
}
''';
    try {
      final response = await http
          .post(
            Uri.parse(_aniListUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': query,
              'variables': {'idMal': malId},
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final id = decoded['data']?['Media']?['id'];
        if (id is int && id > 0) return id;
      }
    } catch (_) {}
    return null;
  }
}
