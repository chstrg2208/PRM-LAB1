import 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

abstract class PlatformHelper {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> openUrl(String url);

  static PlatformHelper instance = getPlatformHelper();
}
