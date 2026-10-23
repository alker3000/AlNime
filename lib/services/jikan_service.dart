import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime_entry.dart';

class JikanAnimeResult {
  final int malId;
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
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.totalEpisodes,
    this.synopsis,
    this.score,
    this.year,
    this.genres = const [],
  });

  factory JikanAnimeResult.fromJson(Map<String, dynamic> json) {
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

    return JikanAnimeResult(
      malId: (json['mal_id'] is int)
          ? json['mal_id'] as int
          : int.tryParse(json['mal_id']?.toString() ?? '0') ?? 0,
      title: resolvedTitle,
      slug: AnimeEntry.generateSlug(defaultTitle),
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
}

class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4/anime';

  Future<List<JikanAnimeResult>> searchAnime(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse(
      '$_baseUrl?q=${Uri.encodeQueryComponent(trimmed)}&limit=10&sfw=true',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Jikan API returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final dataList = decoded['data'] as List<dynamic>? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map(JikanAnimeResult.fromJson)
        .toList();
  }
}
