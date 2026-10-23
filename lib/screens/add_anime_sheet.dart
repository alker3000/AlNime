import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anime_entry.dart';
import '../providers/anime_provider.dart';
import '../services/jikan_service.dart';

class AddAnimeSheet extends StatefulWidget {
  const AddAnimeSheet({super.key});

  @override
  State<AddAnimeSheet> createState() => _AddAnimeSheetState();
}

class _AddAnimeSheetState extends State<AddAnimeSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final JikanService _jikanService = JikanService();

  // Jikan Live Search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<JikanAnimeResult> _results = [];
  JikanAnimeResult? _selectedResult;
  final TextEditingController _selectedSlugController = TextEditingController();

  // Manual Offline Form state
  final _manualFormKey = GlobalKey<FormState>();
  final TextEditingController _manualTitleController = TextEditingController();
  final TextEditingController _manualSlugController = TextEditingController();
  final TextEditingController _manualMalIdController = TextEditingController();
  final TextEditingController _manualEpisodesController =
      TextEditingController(text: '12');
  final TextEditingController _manualImageUrlController =
      TextEditingController();
  final TextEditingController _manualTagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _manualTitleController.addListener(() {
      _manualSlugController.text =
          AnimeEntry.generateSlug(_manualTitleController.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _selectedSlugController.dispose();
    _manualTitleController.dispose();
    _manualSlugController.dispose();
    _manualMalIdController.dispose();
    _manualEpisodesController.dispose();
    _manualImageUrlController.dispose();
    _manualTagsController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final items = await _jikanService.searchAnime(query);
        if (!mounted) return;
        setState(() {
          _results = items;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not reach Jikan API. Use Manual Add offline.';
        });
      }
    });
  }

  Future<void> _saveSelectedJikan(
    BuildContext context, {
    required bool startWatchingNow,
  }) async {
    final selected = _selectedResult;
    if (selected == null) return;

    final provider = context.read<AnimeProvider>();
    await provider.addAnime(
      malId: selected.malId,
      title: selected.title,
      slug: _selectedSlugController.text.trim(),
      imageUrl: selected.imageUrl,
      totalEpisodes: selected.totalEpisodes,
      startWatchingNow: startWatchingNow,
      tags: selected.genres.take(4).toList(),
    );

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          startWatchingNow
              ? '▶️ Started watching "${selected.title}" (Start time logged!)'
              : '🔖 Added "${selected.title}" to Wishlist',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveManualAnime(
    BuildContext context, {
    required bool startWatchingNow,
  }) async {
    if (!_manualFormKey.currentState!.validate()) return;

    final title = _manualTitleController.text.trim();
    final slug = _manualSlugController.text.trim();
    final malId = int.tryParse(_manualMalIdController.text.trim()) ?? 0;
    final totalEps = int.tryParse(_manualEpisodesController.text.trim()) ?? 0;
    final imageUrl = _manualImageUrlController.text.trim();
    final tags = _manualTagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final provider = context.read<AnimeProvider>();
    await provider.addAnime(
      malId: malId,
      title: title,
      slug: slug,
      imageUrl: imageUrl,
      totalEpisodes: totalEps,
      startWatchingNow: startWatchingNow,
      tags: tags,
    );

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          startWatchingNow
              ? '▶️ Started watching "$title" (Start time logged!)'
              : '🔖 Added "$title" to Wishlist',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.travel_explore_rounded, size: 18),
                  text: 'Jikan MAL Search',
                ),
                Tab(
                  icon: Icon(Icons.edit_note_rounded, size: 18),
                  text: 'Manual Add (Offline)',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildJikanSearchTab(context),
                  _buildManualAddTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJikanSearchTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search anime on MyAnimeList (Jikan v4)...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_selectedResult != null) _buildSelectedJikanCard(context),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.amberAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Type an anime title above to search Jikan API v4.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final item = _results[i];
                            final isSelected =
                                _selectedResult?.malId == item.malId;
                            return Card(
                              color: isSelected
                                  ? const Color(0xFFA855F7)
                                      .withValues(alpha: 0.18)
                                  : const Color(0xFF181D2A),
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedResult = item;
                                    _selectedSlugController.text = item.slug;
                                  });
                                },
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 44,
                                    height: 62,
                                    child: item.imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item.imageUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(color: Colors.white10),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'MAL #${item.malId} • ${item.totalEpisodes > 0 ? "${item.totalEpisodes} Eps" : "Airing / ?"} ${item.score != null ? "• ⭐ ${item.score}" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                trailing: Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: isSelected
                                      ? const Color(0xFFA855F7)
                                      : Colors.white54,
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSelectedJikanCard(BuildContext context) {
    final selected = _selectedResult!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2436),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected: ${selected.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA855F7),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _selectedResult = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _selectedSlugController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Stream Slug (kebab-case)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveSelectedJikan(
                    context,
                    startWatchingNow: false,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Add to Wishlist'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveSelectedJikan(
                    context,
                    startWatchingNow: true,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start Watching Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualAddTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _manualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _manualTitleController,
              decoration: const InputDecoration(
                labelText: 'Anime Title *',
                hintText: 'e.g. Solo Leveling',
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manualSlugController,
              decoration: const InputDecoration(
                labelText: 'Stream URL Slug (kebab-case)',
                hintText: 'e.g. solo-leveling',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _manualEpisodesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Episodes (0 if unknown)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _manualMalIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'MAL ID (Optional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manualImageUrlController,
              decoration: const InputDecoration(
                labelText: 'Poster Image URL (Optional)',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manualTagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                hintText: 'Action, Fantasy, Peak',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveManualAnime(
                      context,
                      startWatchingNow: false,
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Add to Wishlist'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveManualAnime(
                      context,
                      startWatchingNow: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Watching Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
