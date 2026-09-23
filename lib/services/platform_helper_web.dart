// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
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

  @override
  Future<PlatformFileResult> saveOrDownloadCsvFile({
    required String fileName,
    required String csvContent,
    dynamic targetDirectory,
  }) async {

    try {
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      return PlatformFileResult(
        success: true,
        filePath: 'Downloads/$fileName',
        message: 'Đã tải xuống file CSV thành công qua trình duyệt.',
      );
    } catch (e) {
      return PlatformFileResult(
        success: false,
        message: 'Lỗi tải xuống trên Web: $e',
      );
    }
  }
}

PlatformHelper getPlatformHelper() => PlatformHelperWeb();

