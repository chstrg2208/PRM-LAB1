import '../models/student.dart';
import 'platform_helper.dart';

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

/// Service tạo nội dung CSV và ghi file báo cáo chuyên cần (Pure Dart cross-platform)
class CsvExportService {
  static const String utf8Bom = '\uFEFF';
  static const String csvHeader = 'Mã SV,Họ và tên,Lớp,Email,Tổng số buổi,Vắng,Có mặt,Tỷ lệ vắng,Trạng thái';

  /// Sanitize className để tránh path traversal và ký tự không hợp lệ trên Windows/macOS/Linux
  static String sanitizeClassName(String className) {
    var sanitized = className.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    sanitized = sanitized.replaceAll('..', '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return sanitized.isEmpty ? 'UnknownClass' : sanitized;
  }

  /// Escape chuẩn CSV RFC 4180: quote khi chứa ký tự phân cách, nháy kép hoặc newline; nhân đôi nháy kép
  static String escapeCsvField(String field, {String delimiter = ','}) {
    if (field.contains(delimiter) || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Sinh chuỗi nội dung CSV cơ bản hoàn chỉnh với BOM UTF-8
  static String generateCsvContent({
    required List<Student> students,
    String? className,
    String delimiter = ',',
  }) {
    final buffer = StringBuffer();
    buffer.write(utf8Bom);
    final headers = [
      'Mã SV',
      'Họ và tên',
      'Lớp',
      'Email',
      'Tổng số buổi',
      'Vắng',
      'Có mặt',
      'Tỷ lệ vắng',
      'Trạng thái',
    ];
    buffer.writeln(headers.join(delimiter));

    for (final s in students) {
      final rollNumber = escapeCsvField(s.rollNumber, delimiter: delimiter);
      final fullName = escapeCsvField(s.fullName, delimiter: delimiter);
      final cName = escapeCsvField(s.className.isNotEmpty ? s.className : (className ?? ''), delimiter: delimiter);
      final email = escapeCsvField(s.email, delimiter: delimiter);
      final totalSlots = s.totalSlots;
      final absentSlots = s.absentSlots;
      final presentSlots = (totalSlots - absentSlots) > 0 ? (totalSlots - absentSlots) : 0;
      final absentRate = '${s.absentRate.toStringAsFixed(1)}%';
      final status = escapeCsvField(s.trainingStatusLabel, delimiter: delimiter);

      buffer.writeln('$rollNumber$delimiter$fullName$delimiter$cName$delimiter$email$delimiter$totalSlots$delimiter$absentSlots$delimiter$presentSlots$delimiter$absentRate$delimiter$status');
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
    String delimiter = ',',
  }) {
    final buffer = StringBuffer();
    buffer.write(utf8Bom);

    final headers = [
      'Mã SV',
      'Họ và tên',
      'Lớp',
      'Email',
      'Tổng số buổi',
      'Vắng',
      'Có mặt',
      'Tỷ lệ vắng',
      'Trạng thái',
      ...List.generate(20, (idx) => 'B${idx + 1}'),
    ];
    buffer.writeln(headers.join(delimiter));

    for (final s in students) {
      final rollNumber = escapeCsvField(s.rollNumber, delimiter: delimiter);
      final fullName = escapeCsvField(s.fullName, delimiter: delimiter);
      final cName = escapeCsvField(s.className.isNotEmpty ? s.className : (className ?? ''), delimiter: delimiter);
      final email = escapeCsvField(s.email, delimiter: delimiter);
      final totalSlots = s.totalSlots;
      final absentSlots = s.absentSlots;
      final presentSlots = (totalSlots - absentSlots) > 0 ? (totalSlots - absentSlots) : 0;
      final absentRate = '${s.absentRate.toStringAsFixed(1)}%';
      final status = escapeCsvField(s.trainingStatusLabel, delimiter: delimiter);
      final slotCols = List.generate(20, (idx) => escapeCsvField(s.getSlot20Status(idx + 1), delimiter: delimiter)).join(delimiter);

      buffer.writeln('$rollNumber$delimiter$fullName$delimiter$cName$delimiter$email$delimiter$totalSlots$delimiter$absentSlots$delimiter$presentSlots$delimiter$absentRate$delimiter$status$delimiter$slotCols');
    }

    return buffer.toString();
  }

  /// Tạo tên file chuẩn hóa an toàn cho báo cáo chuyên cần
  static String generateFileName({
    required String className,
    DateTime? timestamp,
    String? customPrefix,
  }) {
    final cleanClass = sanitizeClassName(className);
    if (timestamp != null) {
      final y = timestamp.year.toString();
      final m = timestamp.month.toString().padLeft(2, '0');
      final d = timestamp.day.toString().padLeft(2, '0');
      final h = timestamp.hour.toString().padLeft(2, '0');
      final min = timestamp.minute.toString().padLeft(2, '0');
      final s = timestamp.second.toString().padLeft(2, '0');
      final timeStr = '$y$m${d}_$h$min$s';
      return '${customPrefix ?? "Birdle_BaoCao"}_${cleanClass}_$timeStr.csv';
    }
    final prefix = customPrefix ?? 'BaoCao_ChuyenCan';
    final timeEpoch = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${cleanClass}_$timeEpoch.csv';
  }

  /// Ghi file CSV thật hoặc kích hoạt tải xuống trình duyệt (hỗ trợ cross-platform)
  static Future<CsvExportResult> exportToFile({
    required List<Student> students,
    required String className,
    String delimiter = ',',
    dynamic targetDirectory,
    DateTime? timestamp,
  }) async {
    try {
      final filename = generateFileName(className: className, timestamp: timestamp);
      final csvContent = generateDetailedCsvContent(
        students: students,
        className: className,
        delimiter: delimiter,
      );



      final platformResult = await PlatformHelper.instance.saveOrDownloadCsvFile(
        fileName: filename,
        csvContent: csvContent,
        targetDirectory: targetDirectory,
      );

      return CsvExportResult(
        success: platformResult.success,
        filePath: platformResult.filePath,
        message: platformResult.message,
      );
    } catch (e) {
      return CsvExportResult(
        success: false,
        message: 'Lỗi trong quá trình xuất file CSV: $e',
      );
    }
  }
}

