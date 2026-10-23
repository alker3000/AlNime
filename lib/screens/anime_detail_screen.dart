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

  /// Combines Flutter's showDatePicker() and showTimePicker() so the user can
  /// inspect or edit the exact date and minute of startedAt or completedAt.
  Future<DateTime?> _pickExactDateTime(
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

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
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
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
                        label: Text('▶ Watch Ep $nextEp In-App'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
                        avatar: Icon(
                          status.icon,
                          size: 16,
                          color: isSelected ? Colors.white : status.color,
                        ),
                        label: Text(status.label),
                        selected: isSelected,
                        selectedColor: status.color.withValues(alpha: 0.3),
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

                  // Started At Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x2238BDF8),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    title: const Text(
                      'Started Watching At',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      anime.startedAt != null
                          ? _timestampFormatter.format(anime.startedAt!)
                          : 'Not started yet (tap to pick date & time)',
                      style: TextStyle(
                        color: anime.startedAt != null
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Date & Time',
                          icon: const Icon(Icons.edit_calendar_rounded),
                          onPressed: () async {
                            final picked = await _pickExactDateTime(
                              context,
                              anime.startedAt,
                            );
                            if (picked != null) {
                              await provider.updateEntry(
                                anime.copyWith(startedAt: picked),
                              );
                            }
                          },
                        ),
                        if (anime.startedAt != null)
                          IconButton(
                            tooltip: 'Clear Timestamp',
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => provider.updateEntry(
                              anime.copyWith(clearStartedAt: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 12, color: Colors.white10),

                  // Completed At Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x2222C55E),
                      child: Icon(
                        Icons.flag_rounded,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    title: const Text(
                      'Finished Final Episode At',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      anime.completedAt != null
                          ? _timestampFormatter.format(anime.completedAt!)
                          : 'Not completed yet (tap to pick date & time)',
                      style: TextStyle(
                        color: anime.completedAt != null
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Date & Time',
                          icon: const Icon(Icons.edit_calendar_rounded),
                          onPressed: () async {
                            final picked = await _pickExactDateTime(
                              context,
                              anime.completedAt,
                            );
                            if (picked != null) {
                              await provider.updateEntry(
                                anime.copyWith(completedAt: picked),
                              );
                            }
                          },
                        ),
                        if (anime.completedAt != null)
                          IconButton(
                            tooltip: 'Clear Timestamp',
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => provider.updateEntry(
                              anime.copyWith(clearCompletedAt: true),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Calculated Duration Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
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
