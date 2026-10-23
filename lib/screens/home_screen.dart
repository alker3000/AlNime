import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/anime_entry.dart';
import '../providers/anime_provider.dart';
import 'add_anime_sheet.dart';
import 'anime_detail_screen.dart';
import 'settings_screen.dart';
import 'watch_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  static final DateFormat _timestampFormatter =
      DateFormat('MMM d, yyyy • h:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddAnimeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF121620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddAnimeSheet(),
    );
  }

  void _openSortSheet(BuildContext context, AnimeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort Anime By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...AnimeSortOption.values.map((option) {
                  final isSelected = provider.sortOption == option;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white54,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      provider.setSortOption(option);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompletionDialog(BuildContext context, AnimeEntry completedAnime) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎉 '),
            Expanded(
              child: Text(
                'Anime Completed!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              completedAnime.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA855F7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⏱️ Total Binge Duration: ${completedAnime.formattedDuration}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (completedAnime.startedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Started: ${_timestampFormatter.format(completedAnime.startedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (completedAnime.completedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Finished: ${_timestampFormatter.format(completedAnime.completedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (completedAnime.is24HourBinge) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '24-Hour Binge Badge Unlocked!',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimeProvider>();
    final entries = provider.filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('AniAlker'),
            if (provider.isSyncing) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cloud Sync & Settings',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAnimeSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Anime',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: !provider.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildBingeStatsHeader(provider),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchAndFilterBar(context, provider),
                ),
                if (entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context, provider),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final anime = entries[index];
                        return _buildAnimeCard(context, provider, anime);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  /// 2x2 Stacked Grid for Binge Stats Header (2 rows x 2 columns)
  Widget _buildBingeStatsHeader(AnimeProvider provider) {
    final fastest = provider.fastestBingeRecord;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatSummaryCard(
                  title: 'Completed',
                  value: '${provider.completedCount}',
                  subtitle: '${provider.totalEpisodesWatched} total eps watched',
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatSummaryCard(
                  title: 'Watching',
                  value: '${provider.watchingCount}',
                  subtitle: 'Active streams',
                  icon: Icons.play_circle_fill_rounded,
                  accentColor: const Color(0xFFA855F7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatSummaryCard(
                  title: 'Wishlist',
                  value: '${provider.wishlistCount}',
                  subtitle: 'Queued to start',
                  icon: Icons.bookmark_rounded,
                  accentColor: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatSummaryCard(
                  title: 'Fastest Binge Record',
                  value: fastest != null ? fastest.formattedDuration : '—',
                  subtitle: fastest != null ? fastest.title : 'Complete an anime!',
                  icon: Icons.bolt_rounded,
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    AnimeProvider provider,
  ) {
    final selectedStatus = provider.selectedStatusFilter;
    final isAllSelected = selectedStatus == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search title, slug, or #tags...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: provider.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Sort (${provider.sortOption.label})',
                onPressed: () => _openSortSheet(context, provider),
                icon: const Icon(Icons.sort_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      'All (${provider.allEntries.length})',
                      style: TextStyle(
                        color: isAllSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isAllSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    selected: isAllSelected,
                    selectedColor: const Color(0xFF7C3AED),
                    backgroundColor: const Color(0xFF151923),
                    side: BorderSide(
                      color: isAllSelected
                          ? const Color(0xFFA855F7)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                    onSelected: (_) => provider.setStatusFilter(null),
                  ),
                ),
                ...AnimeStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(
                        status.icon,
                        size: 16,
                        color: isSelected ? Colors.white : status.color,
                      ),
                      label: Text(
                        status.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF7C3AED),
                      backgroundColor: const Color(0xFF151923),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFA855F7)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                      onSelected: (_) => provider.setStatusFilter(
                        isSelected ? null : status,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeCard(
    BuildContext context,
    AnimeProvider provider,
    AnimeEntry anime,
  ) {
    final nextEp = anime.totalEpisodes > 0
        ? (anime.watchedEpisodes + 1).clamp(1, anime.totalEpisodes)
        : (anime.watchedEpisodes + 1);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnimeDetailScreen(animeId: anime.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 82,
                      height: 118,
                      child: anime.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: anime.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.white10,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.movie_creation_outlined,
                                  color: Colors.white38,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.movie_creation_outlined,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Badges Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusPill(status: anime.status),
                            if (anime.bingeDuration != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏱️ ${anime.formattedDuration}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (anime.is24HourBinge)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  '⚡ 24-Hr Binge',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          anime.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Episode Progress Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress: ${anime.watchedEpisodes} / ${anime.totalEpisodes > 0 ? anime.totalEpisodes : "?"} Eps',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${(anime.progressFraction * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: anime.status.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: anime.progressFraction,
                            minHeight: 6,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              anime.status.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Exact Timestamp Badges
                        if (anime.startedAt != null)
                          _TimestampBadge(
                            icon: Icons.play_arrow_rounded,
                            label: 'Started',
                            formattedTime:
                                _timestampFormatter.format(anime.startedAt!),
                            color: const Color(0xFF38BDF8),
                          ),
                        if (anime.completedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _TimestampBadge(
                              icon: Icons.flag_rounded,
                              label: 'Finished',
                              formattedTime: _timestampFormatter
                                  .format(anime.completedAt!),
                              color: const Color(0xFF22C55E),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (anime.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: anime.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              // Quick Action Buttons Row
              if (anime.status == AnimeStatus.wishlist ||
                  anime.status == AnimeStatus.watching) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Colors.white10),
                ),
                if (anime.status == AnimeStatus.wishlist)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await provider.startWatching(anime.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '⏱️ Started watching "${anime.title}" at ${_timestampFormatter.format(DateTime.now())}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Start Watching',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else if (anime.status == AnimeStatus.watching)
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          final completedNow =
                              await provider.completeEpisode(anime.id);
                          if (!context.mounted) return;
                          final updated = provider.getById(anime.id);
                          if (completedNow && updated != null) {
                            _showCompletionDialog(context, updated);
                          }
                        },
                        child: const Text(
                          '+1 Ep',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WatchPlayerScreen(
                                  animeId: anime.id,
                                  initialEpisode: nextEp,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Watch Ep $nextEp',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AnimeProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              provider.allEntries.isEmpty
                  ? 'Your Anime Tracker is Empty'
                  : 'No Matching Anime Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.allEntries.isEmpty
                  ? 'Search AniList/MAL or add entries offline to track your exact start & finish timestamps and stream episodes in-app.'
                  : 'Try clearing your search filter or switching status tabs.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (provider.allEntries.isEmpty)
              FilledButton.icon(
                onPressed: () => _openAddAnimeSheet(context),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search & Add Anime'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _StatSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151923),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AnimeStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimestampBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String formattedTime;
  final Color color;

  const _TimestampBadge({
    required this.icon,
    required this.label,
    required this.formattedTime,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$label: $formattedTime',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
