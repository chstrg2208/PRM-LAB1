// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'platform_helper.dart';

class PlatformHelperWeb implements PlatformHelper {
  @override
  Future<void> saveString(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  @override
  Future<String?> getString(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (_) {}
    return null;
  }

  @override
  Future<void> openUrl(String url) async {
    try {
      html.window.open(url, '_blank');
    } catch (_) {}
  }
}

PlatformHelper getPlatformHelper() => PlatformHelperWeb();
