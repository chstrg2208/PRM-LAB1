import 'dart:io';
import '../models/student.dart';

/// Kết quả xuất file CSV
class CsvExportResult {
  final bool success;
  final String? filePath;
  final String message;

  const CsvExportResult({
    required this.success,
    this.filePath,
    required this.message,
  });

  @override
  String toString() => 'CsvExportResult(success: $success, filePath: $filePath, message: $message)';
}

/// Service tạo nội dung CSV và ghi file báo cáo chuyên cần
class CsvExportService {
  static const String utf8Bom = '\uFEFF';
  static const String csvHeader = 'Mã SV,Họ và tên,Lớp,Email,Tổng số buổi,Vắng,Có mặt,Tỷ lệ vắng,Trạng thái';

  /// Sanitize className để tránh path traversal và ký tự không hợp lệ cho filename
  static String sanitizeClassName(String className) {
    var sanitized = className.trim().replaceAll(RegExp(r'[\/\\:*?"<>|]'), '_');
    sanitized = sanitized.replaceAll('..', '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return sanitized.isEmpty ? 'UnknownClass' : sanitized;
  }

  /// Escape chuẩn CSV RFC 4180: quote khi chứa dấu phẩy, nháy kép hoặc newline; nhân đôi nháy kép
  static String escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Sinh chuỗi nội dung CSV hoàn chỉnh với BOM UTF-8
  static String generateCsvContent({
    required List<Student> students,
    String? className,
  }) {
    final buffer = StringBuffer();
    buffer.write(utf8Bom);
    buffer.writeln(csvHeader);

    for (final s in students) {
      final rollNumber = escapeCsvField(s.rollNumber);
      final fullName = escapeCsvField(s.fullName);
      final cName = escapeCsvField(s.className.isNotEmpty ? s.className : (className ?? ''));
      final email = escapeCsvField(s.email);
      final totalSlots = s.totalSlots;
      final absentSlots = s.absentSlots;
      final presentSlots = (totalSlots - absentSlots) > 0 ? (totalSlots - absentSlots) : 0;
      final absentRate = '${s.absentRate.toStringAsFixed(1)}%';
      final status = escapeCsvField(s.trainingStatusLabel);

      buffer.writeln('$rollNumber,$fullName,$cName,$email,$totalSlots,$absentSlots,$presentSlots,$absentRate,$status');
    }

    return buffer.toString();
  }

  /// Header CSV chi tiết bao gồm ma trận 20 buổi học FPT
  static const String detailedCsvHeader =
      'Mã SV,Họ và tên,Lớp,Email,Tổng số buổi,Vắng,Có mặt,Tỷ lệ vắng,Trạng thái,B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20';

  /// Sinh chuỗi nội dung CSV chi tiết kèm ma trận 20 buổi học
  static String generateDetailedCsvContent({
    required List<Student> students,
    String? className,
  }) {
    final buffer = StringBuffer();
    buffer.write(utf8Bom);
    buffer.writeln(detailedCsvHeader);

    for (final s in students) {
      final rollNumber = escapeCsvField(s.rollNumber);
      final fullName = escapeCsvField(s.fullName);
      final cName = escapeCsvField(s.className.isNotEmpty ? s.className : (className ?? ''));
      final email = escapeCsvField(s.email);
      final totalSlots = s.totalSlots;
      final absentSlots = s.absentSlots;
      final presentSlots = (totalSlots - absentSlots) > 0 ? (totalSlots - absentSlots) : 0;
      final absentRate = '${s.absentRate.toStringAsFixed(1)}%';
      final status = escapeCsvField(s.trainingStatusLabel);
      final slotCols = List.generate(20, (idx) => escapeCsvField(s.getSlot20Status(idx + 1))).join(',');

      buffer.writeln('$rollNumber,$fullName,$cName,$email,$totalSlots,$absentSlots,$presentSlots,$absentRate,$status,$slotCols');
    }

    return buffer.toString();
  }

  /// Tạo tên file an toàn cho báo cáo chuyên cần
  static String generateFileName({
    required String className,
    DateTime? timestamp,
  }) {
    final cleanClass = sanitizeClassName(className);
    final dt = timestamp ?? DateTime.now();
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final timeStr = '$y$m${d}_$h$min$s';
    return 'Birdle_BaoCao_${cleanClass}_$timeStr.csv';
  }

  /// Xác định thư mục Downloads mặc định an toàn trên hệ điều hành
  static Directory? resolveDefaultDownloadDirectory({
    Map<String, String>? environment,
    bool? isWindows,
  }) {
    try {
      final env = environment ?? Platform.environment;
      final win = isWindows ?? Platform.isWindows;

      if (win) {
        final userProfile = env['USERPROFILE'];
        if (userProfile != null && userProfile.trim().isNotEmpty) {
          final downloadDir = Directory('$userProfile\\Downloads');
          if (downloadDir.existsSync()) {
            return downloadDir;
          }
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.trim().isNotEmpty) {
          final downloadDir = Directory('$home/Downloads');
          if (downloadDir.existsSync()) {
            return downloadDir;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ghi file CSV thật vào filesystem
  static Future<CsvExportResult> exportToFile({
    required List<Student> students,
    required String className,
    Directory? targetDirectory,
    DateTime? timestamp,
  }) async {
    final dir = targetDirectory ?? resolveDefaultDownloadDirectory();
    if (dir == null) {
      return const CsvExportResult(
        success: false,
        message: 'Không thể xác định thư mục tải xuống (Downloads). Vui lòng chọn đường dẫn thư mục đích hợp lệ.',
      );
    }

    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      return CsvExportResult(
        success: false,
        message: 'Không có quyền ghi hoặc không thể tạo thư mục đích: ${dir.path} ($e)',
      );
    }

    final filename = generateFileName(className: className, timestamp: timestamp);
    final separator = Platform.pathSeparator;
    var filePath = '${dir.path}$separator$filename';

    // Đảm bảo không ghi đè nếu file đã tồn tại bằng cách thêm suffix
    var targetFile = File(filePath);
    int counter = 1;
    final baseName = filename.substring(0, filename.length - 4); // drop .csv
    while (targetFile.existsSync()) {
      filePath = '${dir.path}$separator${baseName}_$counter.csv';
      targetFile = File(filePath);
      counter++;
    }

    try {
      final csvContent = generateCsvContent(students: students, className: className);
      await targetFile.writeAsString(csvContent, flush: true);

      return CsvExportResult(
        success: true,
        filePath: targetFile.absolute.path,
        message: 'Đã xuất báo cáo CSV chuyên cần thành công!',
      );
    } catch (e) {
      return CsvExportResult(
        success: false,
        message: 'Lỗi trong quá trình ghi file CSV: $e',
      );
    }
  }
}
