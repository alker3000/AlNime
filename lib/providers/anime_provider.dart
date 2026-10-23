import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/anime_entry.dart';
import '../services/jikan_service.dart';
import '../services/storage_sync_service.dart';

enum AnimeSortOption {
  recentlyUpdated('Recently Updated'),
  fastestBinge('Fastest Binge'),
  highestRated('Highest Rated ⭐'),
  startDate('Start Date'),
  titleAZ('Title A-Z');

  final String label;
  const AnimeSortOption(this.label);
}

class AnimeProvider extends ChangeNotifier {
  final StorageSyncService _storageService;
  final Uuid _uuid = const Uuid();

  List<AnimeEntry> _entries = [];
  List<StreamServerTemplate> _serverTemplates =
      StreamServerTemplate.defaultTemplates();
  AnimeStatus? _selectedStatusFilter; // null means 'All'
  String _searchQuery = '';
  AnimeSortOption _sortOption = AnimeSortOption.recentlyUpdated;

  String _webhookUrl = '';
  bool _autoSync = false;
  DateTime? _lastCloudSync;
  bool _isSyncing = false;
  bool _isInitialized = false;
  int _lastSelectedServerIndex = 0;

  AnimeProvider(this._storageService) {
    initialize();
  }

  // ===========================================================================
  // Getters
  // ===========================================================================

  List<AnimeEntry> get allEntries => List.unmodifiable(_entries);
  List<StreamServerTemplate> get serverTemplates =>
      List.unmodifiable(_serverTemplates);
  AnimeStatus? get selectedStatusFilter => _selectedStatusFilter;
  String get searchQuery => _searchQuery;
  AnimeSortOption get sortOption => _sortOption;
  String get webhookUrl => _webhookUrl;
  bool get autoSync => _autoSync;
  DateTime? get lastCloudSync => _lastCloudSync;
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;
  int get lastSelectedServerIndex => _lastSelectedServerIndex;

  int get completedCount =>
      _entries.where((e) => e.status == AnimeStatus.completed).length;

  int get watchingCount =>
      _entries.where((e) => e.status == AnimeStatus.watching).length;

  int get wishlistCount =>
      _entries.where((e) => e.status == AnimeStatus.wishlist).length;

  int get totalEpisodesWatched =>
      _entries.fold(0, (sum, item) => sum + item.watchedEpisodes);

  AnimeEntry? get fastestBingeRecord {
    final completedWithDuration = _entries
        .where((e) =>
            e.status == AnimeStatus.completed &&
            e.bingeDuration != null &&
            e.totalEpisodes >= 1)
        .toList();

    if (completedWithDuration.isEmpty) return null;

    completedWithDuration.sort(
      (a, b) => a.bingeDuration!.compareTo(b.bingeDuration!),
    );
    return completedWithDuration.first;
  }

  List<AnimeEntry> get filteredEntries {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _entries.where((entry) {
      if (_selectedStatusFilter != null &&
          entry.status != _selectedStatusFilter) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchesTitle = entry.title.toLowerCase().contains(query);
        final matchesSlug = entry.slug.toLowerCase().contains(query);
        final matchesTag =
            entry.tags.any((tag) => tag.toLowerCase().contains(query));
        return matchesTitle || matchesSlug || matchesTag;
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case AnimeSortOption.recentlyUpdated:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case AnimeSortOption.fastestBinge:
        filtered.sort((a, b) {
          final dA = a.bingeDuration;
          final dB = b.bingeDuration;
          if (dA == null && dB == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (dA == null) return 1;
          if (dB == null) return -1;
          return dA.compareTo(dB);
        });
        break;
      case AnimeSortOption.highestRated:
        filtered.sort((a, b) {
          final rA = a.userRating;
          final rB = b.userRating;
          if (rA == null && rB == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (rA == null) return 1;
          if (rB == null) return -1;
          return rB.compareTo(rA);
        });
        break;
      case AnimeSortOption.startDate:
        filtered.sort((a, b) {
          final sA = a.startedAt;
          final sB = b.startedAt;
          if (sA == null && sB == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (sA == null) return 1;
          if (sB == null) return -1;
          return sB.compareTo(sA);
        });
        break;
      case AnimeSortOption.titleAZ:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  AnimeEntry? getById(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  // ===========================================================================
  // Initialization & Persistence
  // ===========================================================================

  Future<void> initialize() async {
    _entries = await _storageService.loadAnimeList();
    _serverTemplates = await _storageService.loadServerTemplates();
    _webhookUrl = await _storageService.loadWebhookUrl();
    _autoSync = await _storageService.loadAutoSync();
    _lastCloudSync = await _storageService.loadLastCloudSync();
    _lastSelectedServerIndex = await _storageService.loadLastSelectedServerIndex();
    _isInitialized = true;
    notifyListeners();

    _backfillMissingAnilistIds();
  }

  Future<void> _backfillMissingAnilistIds() async {
    final jikanService = JikanService();
    bool updatedAny = false;
    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.anilistId == 0 && entry.malId > 0) {
        final resolvedId =
            await jikanService.resolveAnilistIdFromMalId(entry.malId);
        if (resolvedId != null && resolvedId > 0) {
          _entries[i] = entry.copyWith(
            anilistId: resolvedId,
            updatedAt: entry.updatedAt,
          );
          updatedAny = true;
        }
      }
    }
    if (updatedAny) {
      await _storageService.saveAnimeList(_entries);
      notifyListeners();
    }
  }

  Future<void> _persistAndMaybeSync() async {
    await _storageService.saveAnimeList(_entries);
    notifyListeners();

    if (_autoSync && _webhookUrl.trim().isNotEmpty) {
      try {
        await backupToCloud();
      } catch (_) {
        // Silent background fail on auto-sync so offline usage is never interrupted
      }
    }
  }

  // ===========================================================================
  // Filter & Sort Controls
  // ===========================================================================

  void setStatusFilter(AnimeStatus? status) {
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(AnimeSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  // ===========================================================================
  // CRUD & Timestamp Actions
  // ===========================================================================

  Future<AnimeEntry> addAnime({
    required int malId,
    int anilistId = 0,
    required String title,
    String? slug,
    required String imageUrl,
    required int totalEpisodes,
    required bool startWatchingNow,
    List<String> tags = const [],
    String vibeNotes = '',
  }) async {
    final existingIndex = _entries.indexWhere(
      (e) =>
          (malId > 0 && e.malId == malId) ||
          (anilistId > 0 && e.anilistId == anilistId),
    );

    final now = DateTime.now();
    final entry = AnimeEntry(
      id: malId > 0
          ? malId.toString()
          : (anilistId > 0 ? anilistId.toString() : _uuid.v4()),
      malId: malId,
      anilistId: anilistId,
      title: title.trim(),
      slug: (slug != null && slug.trim().isNotEmpty)
          ? slug.trim()
          : AnimeEntry.generateSlug(title),
      imageUrl: imageUrl.trim(),
      totalEpisodes: totalEpisodes,
      watchedEpisodes: 0,
      status: startWatchingNow ? AnimeStatus.watching : AnimeStatus.wishlist,
      startedAt: startWatchingNow ? now : null,
      completedAt: null,
      vibeNotes: vibeNotes,
      tags: tags,
      updatedAt: now,
    );

    if (existingIndex >= 0) {
      _entries[existingIndex] = entry;
    } else {
      _entries.insert(0, entry);
    }

    await _persistAndMaybeSync();
    return entry;
  }

  Future<void> updateEntry(AnimeEntry updated) async {
    final index = _entries.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;
    _entries[index] = updated.copyWith(updatedAt: DateTime.now());
    await _persistAndMaybeSync();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _persistAndMaybeSync();
  }

  /// Moves a wishlist item to Watching and stamps the exact local startedAt timestamp.
  Future<void> startWatching(String id) async {
    final entry = getById(id);
    if (entry == null) return;

    final now = DateTime.now();
    final updated = entry.copyWith(
      status: AnimeStatus.watching,
      startedAt: entry.startedAt ?? now,
      updatedAt: now,
    );
    await updateEntry(updated);
  }

  /// Auto-starts an entry if startedAt == null when opening Episode 1 in WatchPlayerScreen.
  /// Returns true if a new start timestamp was recorded.
  Future<bool> ensureStartedForEpisodeOne(String id) async {
    final entry = getById(id);
    if (entry == null) return false;
    if (entry.startedAt != null) return false;

    final now = DateTime.now();
    final updated = entry.copyWith(
      status: entry.status == AnimeStatus.wishlist
          ? AnimeStatus.watching
          : entry.status,
      startedAt: now,
      updatedAt: now,
    );
    await updateEntry(updated);
    return true;
  }

  /// Marks a specific episode (or +1) as watched.
  /// Returns true if this action caused the anime to reach completion.
  Future<bool> completeEpisode(String id, {int? specificEpisode}) async {
    final entry = getById(id);
    if (entry == null) return false;

    final now = DateTime.now();
    final targetWatched = specificEpisode != null
        ? (specificEpisode > entry.watchedEpisodes
            ? specificEpisode
            : entry.watchedEpisodes + 1)
        : entry.watchedEpisodes + 1;

    final clampedWatched = entry.totalEpisodes > 0
        ? targetWatched.clamp(0, entry.totalEpisodes)
        : targetWatched;

    final reachedFinalEpisode =
        entry.totalEpisodes > 0 && clampedWatched >= entry.totalEpisodes;

    final updatedTimestamps = Map<int, DateTime>.from(entry.episodeTimestamps);
    for (int ep = entry.watchedEpisodes + 1; ep <= clampedWatched; ep++) {
      updatedTimestamps[ep] = now;
    }

    final updated = entry.copyWith(
      watchedEpisodes: clampedWatched,
      status: reachedFinalEpisode ? AnimeStatus.completed : AnimeStatus.watching,
      startedAt: entry.startedAt ?? now,
      completedAt: reachedFinalEpisode ? (entry.completedAt ?? now) : entry.completedAt,
      episodeTimestamps: updatedTimestamps,
      updatedAt: now,
    );

    await updateEntry(updated);
    return reachedFinalEpisode;
  }

  Future<void> setEpisodeTimestamp(
    String id,
    int episode,
    DateTime? timestamp,
  ) async {
    final entry = getById(id);
    if (entry == null) return;
    final updatedTimestamps = Map<int, DateTime>.from(entry.episodeTimestamps);
    if (timestamp != null) {
      updatedTimestamps[episode] = timestamp;
    } else {
      updatedTimestamps.remove(episode);
    }
    final updated = entry.copyWith(
      episodeTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );
    await updateEntry(updated);
  }

  Future<void> toggleFavorite(String id) async {
    final entry = getById(id);
    if (entry == null) return;
    final updated = entry.copyWith(
      isFavorite: !entry.isFavorite,
      updatedAt: DateTime.now(),
    );
    await updateEntry(updated);
  }

  Future<void> setUserRating(String id, double? rating) async {
    final entry = getById(id);
    if (entry == null) return;
    final updated = entry.copyWith(
      userRating: rating,
      clearUserRating: rating == null,
      updatedAt: DateTime.now(),
    );
    await updateEntry(updated);
  }

  Future<void> setLastSelectedServerIndex(int index) async {
    _lastSelectedServerIndex = index;
    await _storageService.saveLastSelectedServerIndex(index);
    notifyListeners();
  }

  // ===========================================================================
  // Server Templates & Cloud Sync Settings
  // ===========================================================================

  Future<void> updateServerTemplates(
    List<StreamServerTemplate> templates,
  ) async {
    _serverTemplates = List<StreamServerTemplate>.from(templates);
    await _storageService.saveServerTemplates(_serverTemplates);
    notifyListeners();
  }

  Future<void> setWebhookUrl(String url) async {
    _webhookUrl = url.trim();
    await _storageService.saveWebhookUrl(_webhookUrl);
    notifyListeners();
  }

  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    await _storageService.saveAutoSync(value);
    notifyListeners();
  }

  Future<void> backupToCloud() async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _storageService.backupToGoogleCloud(
        webhookUrl: _webhookUrl,
        entries: _entries,
      );
      _lastCloudSync = await _storageService.loadLastCloudSync();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<int> restoreFromCloud() async {
    _isSyncing = true;
    notifyListeners();
    try {
      final restored = await _storageService.restoreFromGoogleCloud(
        webhookUrl: _webhookUrl,
      );
      _entries = restored;
      await _storageService.saveAnimeList(_entries);
      _lastCloudSync = await _storageService.loadLastCloudSync();
      _backfillMissingAnilistIds();
      return _entries.length;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> exportLocalJson() async {
    await _storageService.exportJsonFile(_entries);
  }

  Future<int?> importLocalJson() async {
    final imported = await _storageService.importJsonFile();
    if (imported == null) return null;
    _entries = imported;
    await _persistAndMaybeSync();
    _backfillMissingAnilistIds();
    return _entries.length;
  }
}
