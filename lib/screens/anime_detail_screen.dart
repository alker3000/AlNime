import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/anime_entry.dart';
import '../providers/anime_provider.dart';
import 'watch_player_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final String animeId;

  const AnimeDetailScreen({super.key, required this.animeId});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  static final DateFormat _timestampFormatter =
      DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _dateOnlyFormatter = DateFormat('MMM d, yyyy');
  static final DateFormat _timeOnlyFormatter = DateFormat('h:mm a');

  late TextEditingController _titleController;
  late TextEditingController _slugController;
  late TextEditingController _customUrlController;
  late TextEditingController _vibeNotesController;
  late TextEditingController _newTagController;
  late TextEditingController _totalEpsController;

  bool _controllersInitialized = false;

  void _initControllers(AnimeEntry anime) {
    if (_controllersInitialized) return;
    _titleController = TextEditingController(text: anime.title);
    _slugController = TextEditingController(text: anime.slug);
    _customUrlController =
        TextEditingController(text: anime.customStreamUrl ?? '');
    _vibeNotesController = TextEditingController(text: anime.vibeNotes);
    _newTagController = TextEditingController();
    _totalEpsController =
        TextEditingController(text: anime.totalEpisodes.toString());
    _controllersInitialized = true;
  }

  @override
  void dispose() {
    if (_controllersInitialized) {
      _titleController.dispose();
      _slugController.dispose();
      _customUrlController.dispose();
      _vibeNotesController.dispose();
      _newTagController.dispose();
      _totalEpsController.dispose();
    }
    super.dispose();
  }

  /// Opens showDatePicker() to change the date while keeping the existing hour & minute.
  /// If the timestamp was null, also prompts showTimePicker() right after.
  Future<DateTime?> _pickDate(
    BuildContext context,
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !context.mounted) return null;

    if (current == null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      return DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? initial.hour,
        pickedTime?.minute ?? initial.minute,
      );
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      current.hour,
      current.minute,
    );
  }

  /// Opens showTimePicker() directly in 1 tap so the user can edit the exact hour & minute.
  Future<DateTime?> _pickTime(
    BuildContext context,
    DateTime? current,
  ) async {
    final baseDate = current ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate),
    );
    if (pickedTime == null) return null;

    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _saveFieldChanges(
    BuildContext context,
    AnimeProvider provider,
    AnimeEntry current,
  ) async {
    final parsedTotal =
        int.tryParse(_totalEpsController.text.trim()) ?? current.totalEpisodes;
    final updated = current.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : current.title,
      slug: _slugController.text.trim().isNotEmpty
          ? _slugController.text.trim()
          : AnimeEntry.generateSlug(current.title),
      totalEpisodes: parsedTotal < 0 ? 0 : parsedTotal,
      customStreamUrl: _customUrlController.text.trim().isEmpty
          ? null
          : _customUrlController.text.trim(),
      clearCustomStreamUrl: _customUrlController.text.trim().isEmpty,
      vibeNotes: _vibeNotesController.text.trim(),
    );

    await provider.updateEntry(updated);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Anime details & timestamps saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimeProvider>();
    final anime = provider.getById(widget.animeId);

    if (anime == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Details')),
        body: const Center(child: Text('Anime entry no longer exists.')),
      );
    }

    _initControllers(anime);

    final nextEp = anime.totalEpisodes > 0
        ? (anime.watchedEpisodes + 1).clamp(1, anime.totalEpisodes)
        : (anime.watchedEpisodes + 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anime Details & Timestamps'),
        actions: [
          IconButton(
            tooltip: 'Delete Entry',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Anime?'),
                  content: Text(
                    'Remove "${anime.title}" from your tracker permanently?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await provider.deleteEntry(anime.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveFieldChanges(context, provider, anime),
        icon: const Icon(Icons.save_rounded),
        label: const Text(
          'Save Changes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // Top Header Summary + Watch Bridge Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 138,
                  child: anime.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.white10,
                          child: const Icon(Icons.movie_outlined, size: 36),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MAL ID: ${anime.malId > 0 ? anime.malId : "Custom"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
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
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: Text('Watch Ep $nextEp In-App'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Personal Rating & Favorite Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFBBF24),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            anime.userRating != null
                                ? 'Your Rating: ${anime.userRating!.toStringAsFixed(anime.userRating! % 1 == 0 ? 0 : 1)} / 10'
                                : 'Personal Rating (Unrated)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: anime.isFavorite
                            ? 'Remove from Favorites'
                            : 'Mark as Favorite',
                        icon: Icon(
                          anime.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: anime.isFavorite
                              ? const Color(0xFFF43F5E)
                              : Colors.white60,
                        ),
                        onPressed: () => provider.toggleFavorite(anime.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...List.generate(10, (index) {
                          final score = (index + 1).toDouble();
                          final isSelected = anime.userRating == score;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              showCheckmark: false,
                              selected: isSelected,
                              selectedColor: const Color(0xFFEAB308),
                              backgroundColor: const Color(0xFF151923),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white12,
                              ),
                              label: Text(
                                '${index + 1} ⭐',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                              onSelected: (_) {
                                provider.setUserRating(
                                  anime.id,
                                  isSelected ? null : score,
                                );
                              },
                            ),
                          );
                        }),
                        if (anime.userRating != null)
                          TextButton(
                            onPressed: () =>
                                provider.setUserRating(anime.id, null),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status Selector Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watch Status & Episode Counter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AnimeStatus.values.map((status) {
                      final isSelected = anime.status == status;
                      return ChoiceChip(
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
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
                        onSelected: (_) async {
                          final now = DateTime.now();
                          final updated = anime.copyWith(
                            status: status,
                            startedAt: (status == AnimeStatus.watching &&
                                    anime.startedAt == null)
                                ? now
                                : anime.startedAt,
                            completedAt: (status == AnimeStatus.completed &&
                                    anime.completedAt == null)
                                ? now
                                : anime.completedAt,
                          );
                          await provider.updateEntry(updated);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: anime.watchedEpisodes > 0
                            ? () => provider.updateEntry(
                                  anime.copyWith(
                                    watchedEpisodes: anime.watchedEpisodes - 1,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${anime.watchedEpisodes} / ${anime.totalEpisodes > 0 ? anime.totalEpisodes : "?"} Episodes Watched',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: anime.progressFraction,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => provider.completeEpisode(anime.id),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Exact Date + Time Pickers Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Exact Binge Timestamps',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (anime.is24HourBinge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            '⚡ 24-Hr Binge',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Started At Section
                  _TimestampEditorRow(
                    title: 'Started Watching At',
                    icon: Icons.play_arrow_rounded,
                    accentColor: const Color(0xFF38BDF8),
                    timestamp: anime.startedAt,
                    fullFormatter: _timestampFormatter,
                    dateFormatter: _dateOnlyFormatter,
                    timeFormatter: _timeOnlyFormatter,
                    onPickDate: () async {
                      final picked = await _pickDate(context, anime.startedAt);
                      if (picked != null) {
                        await provider.updateEntry(
                          anime.copyWith(startedAt: picked),
                        );
                      }
                    },
                    onPickTime: () async {
                      final picked = await _pickTime(context, anime.startedAt);
                      if (picked != null) {
                        await provider.updateEntry(
                          anime.copyWith(startedAt: picked),
                        );
                      }
                    },
                    onClear: anime.startedAt != null
                        ? () => provider.updateEntry(
                              anime.copyWith(clearStartedAt: true),
                            )
                        : null,
                  ),
                  const Divider(height: 20, color: Colors.white10),

                  // Completed At Section
                  _TimestampEditorRow(
                    title: 'Finished Final Episode At',
                    icon: Icons.flag_rounded,
                    accentColor: const Color(0xFF22C55E),
                    timestamp: anime.completedAt,
                    fullFormatter: _timestampFormatter,
                    dateFormatter: _dateOnlyFormatter,
                    timeFormatter: _timeOnlyFormatter,
                    onPickDate: () async {
                      final picked =
                          await _pickDate(context, anime.completedAt);
                      if (picked != null) {
                        await provider.updateEntry(
                          anime.copyWith(completedAt: picked),
                        );
                      }
                    },
                    onPickTime: () async {
                      final picked =
                          await _pickTime(context, anime.completedAt);
                      if (picked != null) {
                        await provider.updateEntry(
                          anime.copyWith(completedAt: picked),
                        );
                      }
                    },
                    onClear: anime.completedAt != null
                        ? () => provider.updateEntry(
                              anime.copyWith(clearCompletedAt: true),
                            )
                        : null,
                  ),

                  // Calculated Duration Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calculated Binge Duration:',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        Text(
                          '⏱️ ${anime.formattedDuration}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Episode Watch History & Timestamps Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 20,
                            color: Color(0xFFA855F7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Episode Watch History & Logs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${anime.episodeTimestamps.length} Recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (anime.watchedEpisodes == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No episodes watched yet. As you complete episodes or stream in-app, timestamps will appear here automatically!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: anime.watchedEpisodes,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (ctx, idx) {
                          final epNum = idx + 1;
                          final epTimestamp =
                              anime.episodeTimestamps[epNum];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: epTimestamp != null
                                        ? const Color(0xFFA855F7)
                                            .withValues(alpha: 0.15)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$epNum',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: epTimestamp != null
                                          ? const Color(0xFFA855F7)
                                          : Colors.white54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Episode $epNum',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        epTimestamp != null
                                            ? _timestampFormatter
                                                .format(epTimestamp)
                                            : 'No timestamp stamped',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: epTimestamp != null
                                              ? Colors.white70
                                              : Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: epTimestamp != null
                                      ? 'Edit Timestamp'
                                      : 'Stamp Current Time',
                                  icon: Icon(
                                    epTimestamp != null
                                        ? Icons.edit_calendar_rounded
                                        : Icons.add_circle_outline_rounded,
                                    size: 18,
                                    color: const Color(0xFFA855F7),
                                  ),
                                  onPressed: () async {
                                    final pickedDate = await _pickDate(
                                      context,
                                      epTimestamp ?? DateTime.now(),
                                    );
                                    if (pickedDate != null && context.mounted) {
                                      await provider.setEpisodeTimestamp(
                                        anime.id,
                                        epNum,
                                        pickedDate,
                                      );
                                    }
                                  },
                                ),
                                if (epTimestamp != null)
                                  IconButton(
                                    tooltip: 'Clear Timestamp',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white38,
                                    ),
                                    onPressed: () => provider
                                        .setEpisodeTimestamp(
                                      anime.id,
                                      epNum,
                                      null,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stream Bridge Configuration & Metadata
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stream Bridge & Metadata',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Anime Title'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _slugController,
                          decoration: const InputDecoration(
                            labelText: 'URL Slug ({slug})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _totalEpsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Eps',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Stream URL Override (Optional)',
                      hintText: 'https://example.com/watch/{slug}-episode-{ep}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Custom Tags & Vibe Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Tags & Personal Vibe Notes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...anime.tags.map(
                        (tag) => InputChip(
                          label: Text('#$tag'),
                          onDeleted: () {
                            final nextTags = List<String>.from(anime.tags)
                              ..remove(tag);
                            provider.updateEntry(anime.copyWith(tags: nextTags));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagController,
                          decoration: const InputDecoration(
                            hintText: 'Add a tag (e.g. Peak, Rewatch, MAPPA)...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          final raw = _newTagController.text.trim();
                          if (raw.isEmpty) return;
                          final updatedTags = {
                            ...anime.tags,
                            raw,
                          }.toList();
                          _newTagController.clear();
                          provider.updateEntry(
                            anime.copyWith(tags: updatedTags),
                          );
                        },
                        child: const Text('+ Tag'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _vibeNotesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Vibe Notes / Review',
                      hintText:
                          'Write your personal thoughts, favorite episodes, or OST notes...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimestampEditorRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final DateTime? timestamp;
  final DateFormat fullFormatter;
  final DateFormat dateFormatter;
  final DateFormat timeFormatter;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback? onClear;

  const _TimestampEditorRow({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.timestamp,
    required this.fullFormatter,
    required this.dateFormatter,
    required this.timeFormatter,
    required this.onPickDate,
    required this.onPickTime,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp != null
                        ? fullFormatter.format(timestamp!)
                        : 'Not set yet — tap Date or Time below',
                    style: TextStyle(
                      fontSize: 12,
                      color: timestamp != null ? Colors.white : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear Timestamp',
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: onClear,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onPressed: onPickDate,
                icon: Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: accentColor,
                ),
                label: Text(
                  timestamp != null
                      ? dateFormatter.format(timestamp!)
                      : 'Pick Date',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onPressed: onPickTime,
                icon: Icon(
                  Icons.access_time_filled_rounded,
                  size: 16,
                  color: accentColor,
                ),
                label: Text(
                  timestamp != null
                      ? timeFormatter.format(timestamp!)
                      : 'Pick Time',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
