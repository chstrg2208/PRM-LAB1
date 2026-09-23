import 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

class PlatformFileResult {
  final bool success;
  final String? filePath;
  final String message;

  const PlatformFileResult({
    required this.success,
    this.filePath,
    required this.message,
  });

  @override
  String toString() => 'PlatformFileResult(success: $success, filePath: $filePath, message: $message)';
}

abstract class PlatformHelper {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> openUrl(String url);
  Future<PlatformFileResult> saveOrDownloadCsvFile({
    required String fileName,
    required String csvContent,
    dynamic targetDirectory,
  });

  static PlatformHelper instance = getPlatformHelper();
}


