import 'dart:io';
import 'platform_helper.dart';

class PlatformHelperIo implements PlatformHelper {
  @override
  Future<void> saveString(String key, String value) async {
    try {
      final file = File('$key.json');
      await file.writeAsString(value);
    } catch (_) {}
  }

  @override
  Future<String?> getString(String key) async {
    try {
      final file = File('$key.json');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> openUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }
}

PlatformHelper getPlatformHelper() => PlatformHelperIo();
