import 'package:flutter/material.dart';

enum AnimeStatus {
  wishlist,
  watching,
  completed,
  onHold,
  dropped;

  String get label {
    switch (this) {
      case AnimeStatus.wishlist:
        return 'Wishlist';
      case AnimeStatus.watching:
        return 'Watching';
      case AnimeStatus.completed:
        return 'Completed';
      case AnimeStatus.onHold:
        return 'On Hold';
      case AnimeStatus.dropped:
        return 'Dropped';
    }
  }

  Color get color {
    switch (this) {
      case AnimeStatus.wishlist:
        return const Color(0xFF38BDF8); // Sky Blue
      case AnimeStatus.watching:
        return const Color(0xFFA855F7); // Vivid Purple
      case AnimeStatus.completed:
        return const Color(0xFF22C55E); // Emerald Green
      case AnimeStatus.onHold:
        return const Color(0xFFF59E0B); // Amber
      case AnimeStatus.dropped:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case AnimeStatus.wishlist:
        return Icons.bookmark_outline_rounded;
      case AnimeStatus.watching:
        return Icons.play_circle_fill_rounded;
      case AnimeStatus.completed:
        return Icons.check_circle_rounded;
      case AnimeStatus.onHold:
        return Icons.pause_circle_filled_rounded;
      case AnimeStatus.dropped:
        return Icons.cancel_rounded;
    }
  }

  static AnimeStatus fromString(String value) {
    return AnimeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AnimeStatus.wishlist,
    );
  }
}

class StreamServerTemplate {
  final String id;
  final String name;
  final String urlTemplate;

  const StreamServerTemplate({
    required this.id,
    required this.name,
    required this.urlTemplate,
  });

  String resolveUrl(AnimeEntry anime, int episode) {
    final activeTemplate = (anime.customStreamUrl != null &&
            anime.customStreamUrl!.trim().isNotEmpty)
        ? anime.customStreamUrl!.trim()
        : urlTemplate;

    return activeTemplate
        .replaceAll('{malId}', anime.malId.toString())
        .replaceAll('{slug}', anime.slug)
        .replaceAll('{ep}', episode.toString())
        .replaceAll('{title}', Uri.encodeComponent(anime.title));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'urlTemplate': urlTemplate,
      };

  factory StreamServerTemplate.fromJson(Map<String, dynamic> json) {
    return StreamServerTemplate(
      id: json['id']?.toString() ?? 'server_1',
      name: json['name']?.toString() ?? 'Server 1',
      urlTemplate: json['urlTemplate']?.toString() ??
          'https://vidsrc.cc/v2/embed/anime/{malId}/{ep}/sub',
    );
  }

  static List<StreamServerTemplate> defaultTemplates() => const [
        StreamServerTemplate(
          id: 'vidsrc_sub',
          name: 'VidSrc (Sub)',
          urlTemplate: 'https://vidsrc.cc/v2/embed/anime/{malId}/{ep}/sub',
        ),
        StreamServerTemplate(
          id: 'vidsrc_dub',
          name: 'VidSrc (Dub)',
          urlTemplate: 'https://vidsrc.cc/v2/embed/anime/{malId}/{ep}/dub',
        ),
        StreamServerTemplate(
          id: 'hianime_slug',
          name: 'Slug Bridge',
          urlTemplate: 'https://gogoanime3.co/{slug}-episode-{ep}',
        ),
      ];
}

class AnimeEntry {
  final String id;
  final int malId;
  final String title;
  final String slug;
  final String imageUrl;
  final int totalEpisodes;
  final int watchedEpisodes;
  final AnimeStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String vibeNotes;
  final List<String> tags;
  final String? customStreamUrl;
  final DateTime updatedAt;

  const AnimeEntry({
    required this.id,
    required this.malId,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.totalEpisodes,
    required this.watchedEpisodes,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.vibeNotes = '',
    this.tags = const [],
    this.customStreamUrl,
    required this.updatedAt,
  });

  /// Converts any anime title into a clean kebab-case slug for streaming URL templates.
  static String generateSlug(String rawTitle) {
    final cleaned = rawTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return cleaned.isEmpty ? 'anime-entry' : cleaned;
  }

  /// 1. Computed Getter: Exact duration between startedAt and completedAt.
  Duration? get bingeDuration {
    if (startedAt != null && completedAt != null) {
      final diff = completedAt!.difference(startedAt!);
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  /// 2. Computed Getter: Formats bingeDuration into "Xd Yh Zm" or "Yh Zm".
  String get formattedDuration {
    final duration = bingeDuration;
    if (duration == null) return '—';

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  /// 3. Computed Getter: True if completed, at least 6 episodes, and finished within 24 hours.
  bool get is24HourBinge {
    final duration = bingeDuration;
    if (duration == null) return false;
    return status == AnimeStatus.completed &&
        totalEpisodes >= 6 &&
        duration.inMinutes <= 24 * 60;
  }

  double get progressFraction {
    if (totalEpisodes <= 0) {
      return status == AnimeStatus.completed ? 1.0 : 0.0;
    }
    return (watchedEpisodes / totalEpisodes).clamp(0.0, 1.0);
  }

  AnimeEntry copyWith({
    String? id,
    int? malId,
    String? title,
    String? slug,
    String? imageUrl,
    int? totalEpisodes,
    int? watchedEpisodes,
    AnimeStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? vibeNotes,
    List<String>? tags,
    String? customStreamUrl,
    bool clearCustomStreamUrl = false,
    DateTime? updatedAt,
  }) {
    return AnimeEntry(
      id: id ?? this.id,
      malId: malId ?? this.malId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      imageUrl: imageUrl ?? this.imageUrl,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      vibeNotes: vibeNotes ?? this.vibeNotes,
      tags: tags ?? List<String>.from(this.tags),
      customStreamUrl: clearCustomStreamUrl
          ? null
          : (customStreamUrl ?? this.customStreamUrl),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'malId': malId,
      'title': title,
      'slug': slug,
      'imageUrl': imageUrl,
      'totalEpisodes': totalEpisodes,
      'watchedEpisodes': watchedEpisodes,
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'vibeNotes': vibeNotes,
      'tags': tags,
      'customStreamUrl': customStreamUrl,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AnimeEntry.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString() ?? 'Unknown Anime';
    return AnimeEntry(
      id: json['id']?.toString() ??
          (json['malId']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString()),
      malId: (json['malId'] is int)
          ? json['malId'] as int
          : int.tryParse(json['malId']?.toString() ?? '0') ?? 0,
      title: rawTitle,
      slug: (json['slug'] != null && json['slug'].toString().trim().isNotEmpty)
          ? json['slug'].toString().trim()
          : AnimeEntry.generateSlug(rawTitle),
      imageUrl: json['imageUrl']?.toString() ?? '',
      totalEpisodes: (json['totalEpisodes'] is int)
          ? json['totalEpisodes'] as int
          : int.tryParse(json['totalEpisodes']?.toString() ?? '0') ?? 0,
      watchedEpisodes: (json['watchedEpisodes'] is int)
          ? json['watchedEpisodes'] as int
          : int.tryParse(json['watchedEpisodes']?.toString() ?? '0') ?? 0,
      status: AnimeStatus.fromString(json['status']?.toString() ?? 'wishlist'),
      startedAt: json['startedAt'] != null &&
              json['startedAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['startedAt'].toString())?.toLocal()
          : null,
      completedAt: json['completedAt'] != null &&
              json['completedAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['completedAt'].toString())?.toLocal()
          : null,
      vibeNotes: json['vibeNotes']?.toString() ?? '',
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      customStreamUrl: json['customStreamUrl']?.toString(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
    );
  }
}
