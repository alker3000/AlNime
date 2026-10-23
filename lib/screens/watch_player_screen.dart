import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/anime_entry.dart';
import '../providers/anime_provider.dart';

class WatchPlayerScreen extends StatefulWidget {
  final String animeId;
  final int initialEpisode;

  const WatchPlayerScreen({
    super.key,
    required this.animeId,
    required this.initialEpisode,
  });

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> {
  InAppWebViewController? _webViewController;
  late int _currentEpisode;
  int _selectedServerIndex = 0;
  double _loadingProgress = 0.0;
  int _blockedAdRedirects = 0;
  bool _isLandscapeLocked = false;

  static final DateFormat _timestampFormatter =
      DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    _currentEpisode = max(1, widget.initialEpisode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndTriggerAutoStartTimestamp();
    });
  }

  @override
  void dispose() {
    _restoreSystemOrientations();
    super.dispose();
  }

  Future<void> _restoreSystemOrientations() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _toggleLandscapeMode() async {
    if (_isLandscapeLocked) {
      await _restoreSystemOrientations();
      if (mounted) setState(() => _isLandscapeLocked = false);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (mounted) setState(() => _isLandscapeLocked = true);
    }
  }

  /// Auto-Start Trigger: If startedAt == null when opening Episode 1,
  /// automatically set startedAt = DateTime.now() and status = AnimeStatus.watching.
  Future<void> _checkAndTriggerAutoStartTimestamp() async {
    if (_currentEpisode != 1) return;
    final provider = context.read<AnimeProvider>();
    final stampedNow =
        await provider.ensureStartedForEpisodeOne(widget.animeId);
    if (stampedNow && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Start date & time recorded!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    }
  }

  String _resolveStreamUrl(AnimeEntry anime, List<StreamServerTemplate> servers) {
    final activeServer = servers.isNotEmpty
        ? servers[_selectedServerIndex.clamp(0, servers.length - 1)]
        : StreamServerTemplate.defaultTemplates().first;
    return activeServer.resolveUrl(anime, _currentEpisode);
  }

  String _extractRootDomain(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return '';
    final parts = uri.host.toLowerCase().split('.');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}.${parts.last}';
    }
    return uri.host.toLowerCase();
  }

  void _loadEpisodeInWebView(
    AnimeEntry anime,
    List<StreamServerTemplate> servers,
  ) {
    final targetUrl = _resolveStreamUrl(anime, servers);
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targetUrl)),
    );
  }

  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openSlugAndUrlFixerDialog(BuildContext context, AnimeEntry anime) {
    final slugCtrl = TextEditingController(text: anime.slug);
    final customUrlCtrl =
        TextEditingController(text: anime.customStreamUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181D2A),
        title: const Text('Slug & Custom Stream URL Fixer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adjust the kebab-case slug or set a per-anime custom URL template (supports {ep}, {slug}, {malId}).',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: slugCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anime Slug ({slug})',
                  hintText: 'e.g. solo-leveling',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Stream URL Override (Optional)',
                  hintText: 'https://example.com/watch/{slug}-ep-{ep}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final provider = context.read<AnimeProvider>();
              final updated = anime.copyWith(
                slug: slugCtrl.text.trim().isEmpty
                    ? AnimeEntry.generateSlug(anime.title)
                    : slugCtrl.text.trim(),
                customStreamUrl: customUrlCtrl.text.trim().isEmpty
                    ? null
                    : customUrlCtrl.text.trim(),
                clearCustomStreamUrl: customUrlCtrl.text.trim().isEmpty,
              );
              await provider.updateEntry(updated);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadEpisodeInWebView(updated, provider.serverTemplates);
            },
            child: const Text('Save & Reload Stream'),
          ),
        ],
      ),
    );
  }

  void _showCelebratoryBingeDialog(
    BuildContext context,
    AnimeEntry completedAnime,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🏆 '),
            Expanded(
              child: Text(
                'Final Episode Completed!',
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
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL BINGE DURATION',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '⏱️ ${completedAnime.formattedDuration}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(height: 18, color: Colors.white12),
                  if (completedAnime.startedAt != null)
                    Text(
                      'Started: ${_timestampFormatter.format(completedAnime.startedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (completedAnime.completedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Finished: ${_timestampFormatter.format(completedAnime.completedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (completedAnime.is24HourBinge) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '24-Hour Binge Achievement Unlocked!',
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
            child: const Text('Celebrate & Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimeProvider>();
    final anime = provider.getById(widget.animeId);

    if (anime == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: const Center(child: Text('Anime entry not found.')),
      );
    }

    final servers = provider.serverTemplates;
    final resolvedStreamUrl = _resolveStreamUrl(anime, servers);
    final allowedRootDomain = _extractRootDomain(resolvedStreamUrl);

    final episodeChipCount = anime.totalEpisodes > 0
        ? anime.totalEpisodes
        : max(anime.watchedEpisodes + 12, 24);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anime.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Episode $_currentEpisode • Shield: $_blockedAdRedirects ads blocked',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Slug / URL Fixer',
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: () => _openSlugAndUrlFixerDialog(context, anime),
          ),
          IconButton(
            tooltip: 'Rotate Landscape',
            icon: Icon(
              _isLandscapeLocked
                  ? Icons.screen_lock_landscape_rounded
                  : Icons.screen_rotation_rounded,
            ),
            onPressed: _toggleLandscapeMode,
          ),
          IconButton(
            tooltip: 'Open in External Browser / Player',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openInExternalBrowser(resolvedStreamUrl),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingProgress > 0 && _loadingProgress < 1.0)
            LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 3,
              color: const Color(0xFFA855F7),
            ),
          // 1. Server Selector Strip
          Container(
            color: const Color(0xFF121620),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.dns_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: servers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, idx) {
                        final server = servers[idx];
                        final selected = idx == _selectedServerIndex;
                        return ChoiceChip(
                          label: Text(
                            server.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) {
                            setState(() => _selectedServerIndex = idx);
                            _loadEpisodeInWebView(anime, servers);
                          },
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Reload Player',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () => _webViewController?.reload(),
                ),
              ],
            ),
          ),

          // 2. Ad-Blocked Native InAppWebView Player
          Expanded(
            flex: _isLandscapeLocked ? 10 : 5,
            child: Container(
              color: Colors.black,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(resolvedStreamUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  useShouldOverrideUrlLoading: true,
                  transparentBackground: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (_, progress) {
                  setState(() => _loadingProgress = progress / 100.0);
                },
                onEnterFullscreen: (_) async {
                  await SystemChrome.setEnabledSystemUIMode(
                    SystemUiMode.immersiveSticky,
                  );
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                },
                onExitFullscreen: (_) async {
                  if (!_isLandscapeLocked) {
                    await _restoreSystemOrientations();
                  }
                },
                // Block all popup windows spawned by ad scripts
                onCreateWindow: (_, __) async {
                  if (mounted) {
                    setState(() => _blockedAdRedirects++);
                  }
                  return false;
                },
                // Domain-lock top-frame navigation to prevent redirect ads
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final reqUri = navigationAction.request.url;
                  if (reqUri == null) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  final scheme = reqUri.scheme.toLowerCase();
                  if (scheme != 'http' && scheme != 'https') {
                    if (mounted) setState(() => _blockedAdRedirects++);
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Allow sub-frame video embeds while locking main-frame redirects to the active streaming host
                  if (navigationAction.isForMainFrame) {
                    final targetRoot = _extractRootDomain(reqUri.toString());
                    if (allowedRootDomain.isNotEmpty &&
                        targetRoot.isNotEmpty &&
                        targetRoot != allowedRootDomain) {
                      if (mounted) setState(() => _blockedAdRedirects++);
                      return NavigationActionPolicy.CANCEL;
                    }
                  }

                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
          ),

          // 3. Auto-Timestamp & Episode Control Bar (Below Player)
          if (!_isLandscapeLocked)
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF0F131C),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent One-Tap Completion Bridge Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final completedAll = await provider.completeEpisode(
                              anime.id,
                              specificEpisode: _currentEpisode,
                            );
                            if (!context.mounted) return;
                            final refreshed = provider.getById(anime.id);

                            if (completedAll && refreshed != null) {
                              _showCelebratoryBingeDialog(context, refreshed);
                            } else {
                              final nextEp = _currentEpisode + 1;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✓ Logged Ep $_currentEpisode! Advancing to Ep $nextEp...',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setState(() => _currentEpisode = nextEp);
                              if (refreshed != null) {
                                _loadEpisodeInWebView(refreshed, servers);
                              }
                            }
                          },
                          icon: const Icon(Icons.task_alt_rounded, size: 22),
                          label: Text(
                            '✓ Finished Ep $_currentEpisode (+1 & Log Time)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active Timestamps & Slug Status Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171C28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Watched: ${anime.watchedEpisodes} / ${anime.totalEpisodes > 0 ? anime.totalEpisodes : "?"} Eps',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _openSlugAndUrlFixerDialog(context, anime),
                                  child: Text(
                                    'Slug: ${anime.slug} ✎',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              anime.startedAt != null
                                  ? '⏱️ Started: ${_timestampFormatter.format(anime.startedAt!)}'
                                  : '⏱️ Start timestamp will record automatically on Ep 1',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            if (anime.completedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '🏁 Finished: ${_timestampFormatter.format(anime.completedAt!)} (${anime.formattedDuration})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Horizontal Scrollable Episode Selector Chips
                      const Text(
                        'Select Episode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: episodeChipCount,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, index) {
                            final epNumber = index + 1;
                            final isCurrent = epNumber == _currentEpisode;
                            final isWatched = epNumber <= anime.watchedEpisodes;

                            return ChoiceChip(
                              label: Text('Ep $epNumber'),
                              selected: isCurrent,
                              avatar: isWatched
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Color(0xFF22C55E),
                                    )
                                  : null,
                              onSelected: (_) {
                                setState(() => _currentEpisode = epNumber);
                                if (epNumber == 1) {
                                  _checkAndTriggerAutoStartTimestamp();
                                }
                                _loadEpisodeInWebView(anime, servers);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
