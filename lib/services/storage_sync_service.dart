import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_entry.dart';

class StorageSyncService {
  static const String _animeListKey = 'anialker_anime_entries_v1';
  static const String _serverTemplatesKey = 'anialker_server_templates_v1';
  static const String _webhookUrlKey = 'anialker_gas_webhook_url_v1';
  static const String _autoSyncKey = 'anialker_auto_sync_v1';
  static const String _lastCloudSyncKey = 'anialker_last_cloud_sync_v1';

  /// Ready-to-copy 20-line Google Apps Script for serverless Google Drive JSON backup.
  static const String googleAppsScriptCode = '''
function doPost(e) {
  var data = e.postData.contents;
  var files = DriveApp.getFilesByName("anialker_backup.json");
  if (files.hasNext()) {
    files.next().setContent(data);
  } else {
    DriveApp.createFile("anialker_backup.json", data, MimeType.PLAIN_TEXT);
  }
  return ContentService.createTextOutput(JSON.stringify({"status":"ok","updatedAt":new Date().toISOString()}))
    .setMimeType(ContentService.MimeType.JSON);
}

function doGet(e) {
  var files = DriveApp.getFilesByName("anialker_backup.json");
  var content = files.hasNext() ? files.next().getBlob().getDataAsString() : "[]";
  return ContentService.createTextOutput(content)
    .setMimeType(ContentService.MimeType.JSON);
}''';

  // ===========================================================================
  // Local Persistence (SharedPreferences)
  // ===========================================================================

  Future<List<AnimeEntry>> loadAnimeList() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_animeListKey);
    if (rawJson == null || rawJson.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AnimeEntry.fromJson)
        .toList();
  }

  Future<void> saveAnimeList(List<AnimeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_animeListKey, encoded);
  }

  Future<List<StreamServerTemplate>> loadServerTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_serverTemplatesKey);
    if (rawJson == null || rawJson.isEmpty) {
      return StreamServerTemplate.defaultTemplates();
    }
    final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
    final list = decoded
        .whereType<Map<String, dynamic>>()
        .map(StreamServerTemplate.fromJson)
        .toList();
    return list.isEmpty ? StreamServerTemplate.defaultTemplates() : list;
  }

  Future<void> saveServerTemplates(List<StreamServerTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(templates.map((t) => t.toJson()).toList());
    await prefs.setString(_serverTemplatesKey, encoded);
  }

  Future<String> loadWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_webhookUrlKey) ?? '';
  }

  Future<void> saveWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webhookUrlKey, url.trim());
  }

  Future<bool> loadAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }

  Future<void> saveAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  Future<DateTime?> loadLastCloudSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastCloudSyncKey);
    return raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
  }

  Future<void> _recordCloudSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCloudSyncKey, DateTime.now().toIso8601String());
  }

  // ===========================================================================
  // Google Cloud Sync via Google Apps Script Webhook (Handles 302 Redirects)
  // ===========================================================================

  Future<void> backupToGoogleCloud({
    required String webhookUrl,
    required List<AnimeEntry> entries,
  }) async {
    final cleanUrl = webhookUrl.trim();
    if (cleanUrl.isEmpty) {
      throw Exception('Google Apps Script Webhook URL is empty.');
    }

    final payload = jsonEncode({
      'app': 'AniAlker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    });

    final client = http.Client();
    try {
      var response = await client
          .post(
            Uri.parse(cleanUrl),
            headers: {'Content-Type': 'text/plain; charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 20));

      // Google Apps Script Web Apps respond with HTTP 302 redirecting to script.googleusercontent.com
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectLocation = response.headers['location'];
        if (redirectLocation != null && redirectLocation.isNotEmpty) {
          response = await client
              .get(Uri.parse(redirectLocation))
              .timeout(const Duration(seconds: 20));
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw Exception(
          'Cloud backup failed with status ${response.statusCode}',
        );
      }

      await _recordCloudSyncTimestamp();
    } finally {
      client.close();
    }
  }

  Future<List<AnimeEntry>> restoreFromGoogleCloud({
    required String webhookUrl,
  }) async {
    final cleanUrl = webhookUrl.trim();
    if (cleanUrl.isEmpty) {
      throw Exception('Google Apps Script Webhook URL is empty.');
    }

    final response = await http
        .get(Uri.parse(cleanUrl))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Cloud restore failed with HTTP ${response.statusCode}',
      );
    }

    final entries = parseBackupJsonString(response.body);
    await _recordCloudSyncTimestamp();
    return entries;
  }

  // ===========================================================================
  // Local JSON File Export / Import
  // ===========================================================================

  Future<void> exportJsonFile(List<AnimeEntry> entries) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${directory.path}/anialker_backup_$timestamp.json');

    final prettyPayload = const JsonEncoder.withIndent('  ').convert({
      'app': 'AniAlker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    });

    await file.writeAsString(prettyPayload);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'AniAlker Anime Backup ($timestamp)',
    );
  }

  Future<List<AnimeEntry>?> importJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    String content;
    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      throw Exception('Unable to read selected JSON file.');
    }

    return parseBackupJsonString(content);
  }

  List<AnimeEntry> parseBackupJsonString(String rawContent) {
    final decoded = jsonDecode(rawContent);
    List<dynamic> rawEntries;

    if (decoded is List) {
      rawEntries = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['entries'] is List) {
      rawEntries = decoded['entries'] as List<dynamic>;
    } else {
      throw const FormatException('Invalid AniAlker backup JSON structure.');
    }

    return rawEntries
        .whereType<Map<String, dynamic>>()
        .map(AnimeEntry.fromJson)
        .toList();
  }
}
