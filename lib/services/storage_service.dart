import 'dart:convert';
import 'platform_helper.dart';

class StorageService {
  static const String _defaultSettingsKey = 'fap_attendance_settings';
  static const String _defaultCacheKey = 'fap_attendance_cache';

  static Map<String, dynamic> _settings = {};
  static Map<String, dynamic> _cache = {};
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final settingsStr = await PlatformHelper.instance.getString(_defaultSettingsKey);
      if (settingsStr != null && settingsStr.isNotEmpty) {
        _settings = jsonDecode(settingsStr) as Map<String, dynamic>;
      }
    } catch (_) {
      _settings = {};
    }

    try {
      final cacheStr = await PlatformHelper.instance.getString(_defaultCacheKey);
      if (cacheStr != null && cacheStr.isNotEmpty) {
        _cache = jsonDecode(cacheStr) as Map<String, dynamic>;
      }
    } catch (_) {
      _cache = {};
    }

    _initialized = true;
  }

  static String getGoogleSheetUrl() {
    return _settings['googleSheetUrl'] as String? ?? '';
  }

  static Future<void> setGoogleSheetUrl(String url) async {
    _settings['googleSheetUrl'] = url.trim();
    await _saveSettings();
  }

  static String getSelectedClass() {
    return _settings['selectedClass'] as String? ?? 'SE1801';
  }

  static Future<void> setSelectedClass(String className) async {
    _settings['selectedClass'] = className;
    await _saveSettings();
  }

  static String getGeminiApiKey() {
    return _settings['geminiApiKey'] as String? ?? '';
  }

  static Future<void> setGeminiApiKey(String apiKey) async {
    _settings['geminiApiKey'] = apiKey.trim();
    await _saveSettings();
  }

  static Future<void> _saveSettings() async {
    try {
      await PlatformHelper.instance.saveString(_defaultSettingsKey, jsonEncode(_settings));
    } catch (_) {}
  }

  static Future<void> saveCachedStudents(String className, List<dynamic> studentsJson) async {
    _cache['students_$className'] = studentsJson;
    await _saveCache();
  }

  static List<dynamic>? loadCachedStudents(String className) {
    return _cache['students_$className'] as List<dynamic>?;
  }

  static Future<void> saveCachedAttendance(String key, List<dynamic> recordsJson) async {
    _cache['attendance_$key'] = recordsJson;
    await _saveCache();
  }

  static List<dynamic>? loadCachedAttendance(String key) {
    return _cache['attendance_$key'] as List<dynamic>?;
  }

  static Future<void> _saveCache() async {
    try {
      await PlatformHelper.instance.saveString(_defaultCacheKey, jsonEncode(_cache));
    } catch (_) {}
  }

  /// Open external URL in browser
  static Future<void> openBrowser(String url) async {
    try {
      await PlatformHelper.instance.openUrl(url);
    } catch (_) {}
  }
}
