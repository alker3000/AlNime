import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/anime_entry.dart';
import '../providers/anime_provider.dart';
import '../services/storage_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _webhookController;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final provider = context.read<AnimeProvider>();
      _webhookController = TextEditingController(text: provider.webhookUrl);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _webhookController.dispose();
    }
    super.dispose();
  }

  void _showAppsScriptSetupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181D2A),
        title: const Text('Google Apps Script Webhook Setup'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1. Go to script.google.com and create a New Project.\n'
                '2. Paste the 20-line script below.\n'
                '3. Click Deploy > New deployment > Web app.\n'
                '4. Set "Who has access" to "Anyone" and copy the Web App URL into AniAlker.',
                style:
                    TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const SelectableText(
                  StorageSyncService.googleAppsScriptCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(
                  text: StorageSyncService.googleAppsScriptCode,
                ),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('📋 Copied 20-line Google Apps Script to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Script'),
          ),
        ],
      ),
    );
  }

  void _showEditServerTemplateDialog(
    BuildContext context,
    AnimeProvider provider, {
    StreamServerTemplate? existing,
    int? index,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(
      text: existing?.urlTemplate ??
          'https://anistream.one/watch/{slug}-{anilistId}-episode-{ep}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181D2A),
        title:
            Text(existing == null ? 'Add Stream Server' : 'Edit Stream Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supported placeholders: {anilistId}, {malId}, {slug}, {ep}, {title}',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Server Display Name',
                hintText: 'e.g. AniStream',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL Template',
                hintText:
                    'https://anistream.one/watch/{slug}-{anilistId}-episode-{ep}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (name.isEmpty || url.isEmpty) return;

              final updatedList =
                  List<StreamServerTemplate>.from(provider.serverTemplates);
              final item = StreamServerTemplate(
                id: existing?.id ??
                    'server_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                urlTemplate: url,
              );

              if (index != null) {
                updatedList[index] = item;
              } else {
                updatedList.add(item);
              }

              await provider.updateServerTemplates(updatedList);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimeProvider>();
    final lastSyncFormatted = provider.lastCloudSync != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(provider.lastCloudSync!)
        : 'Never synced';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync, Backup & Servers'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          // 1. Google Cloud Sync via Google Apps Script Webhook
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_done_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Google Cloud Sync (Apps Script Webhook)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (provider.isSyncing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Works on any sideloaded APK/iOS/Desktop build without SHA-1 OAuth certificates. Last sync: $lastSyncFormatted',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _webhookController,
                    onChanged: provider.setWebhookUrl,
                    decoration: InputDecoration(
                      labelText: 'Google Apps Script Web App URL',
                      hintText: 'https://script.google.com/macros/s/.../exec',
                      suffixIcon: IconButton(
                        tooltip: 'Save Webhook URL',
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        onPressed: () async {
                          await provider.setWebhookUrl(_webhookController.text);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Saved Google Cloud Webhook URL'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-Sync on Change',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Automatically push JSON backup to Google Drive whenever episodes or timestamps update.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: provider.autoSync,
                    onChanged: provider.setAutoSync,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          onPressed: provider.isSyncing
                              ? null
                              : () async {
                                  await provider
                                      .setWebhookUrl(_webhookController.text);
                                  try {
                                    await provider.backupToCloud();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '☁️ Backed up ${provider.allEntries.length} anime entries to Google Cloud!',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cloud Backup Error: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                          icon:
                              const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Backup to Cloud',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                              vertical: 12,
                            ),
                          ),
                          onPressed: provider.isSyncing
                              ? null
                              : () async {
                                  await provider
                                      .setWebhookUrl(_webhookController.text);
                                  try {
                                    final count =
                                        await provider.restoreFromCloud();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '☁️ Restored $count anime entries from Google Cloud!',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Cloud Restore Error: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(
                            Icons.cloud_download_rounded,
                            size: 16,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Restore Cloud',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _showAppsScriptSetupDialog(context),
                      icon: const Icon(Icons.code_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Copy 20-Line Google Apps Script (doGet / doPost)',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Local JSON Export / Import
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_zip_outlined, color: Color(0xFF22C55E)),
                      SizedBox(width: 10),
                      Text(
                        'Local JSON Database Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Export your entire anime checklist & timestamps to a local .json file or import an existing backup from device storage.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await provider.exportLocalJson();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export failed: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.ios_share_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Export .JSON File',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final count = await provider.importLocalJson();
                              if (!context.mounted || count == null) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '📂 Imported $count anime entries from JSON file!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Import failed: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.file_open_outlined, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Import .JSON File',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Dynamic Stream Server URL Templates
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.play_lesson_rounded,
                            color: Color(0xFFA855F7),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'In-App Stream Server Templates',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Add Server Template',
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () =>
                            _showEditServerTemplateDialog(context, provider),
                      ),
                    ],
                  ),
                  const Text(
                    'Placeholders: {anilistId}, {malId}, {slug}, {ep}, and {title}. Used by the Ad-Blocked InAppWebView Watch Bridge.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(provider.serverTemplates.length, (idx) {
                    final server = provider.serverTemplates[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        server.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        server.urlTemplate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditServerTemplateDialog(
                              context,
                              provider,
                              existing: server,
                              index: idx,
                            ),
                          ),
                          if (provider.serverTemplates.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                final next = List<StreamServerTemplate>.from(
                                  provider.serverTemplates,
                                )..removeAt(idx);
                                provider.updateServerTemplates(next);
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => provider.updateServerTemplates(
                        StreamServerTemplate.defaultTemplates(),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Reset Default Servers',
                          maxLines: 1,
                        ),
                      ),
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
