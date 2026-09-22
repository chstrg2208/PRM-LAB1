import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/google_sheet_service.dart';
import '../services/storage_service.dart';
import '../services/ai_analytics_service.dart';
import '../services/csv_export_service.dart';

/// Function type cho phép Dependency Injection khi xuất CSV
typedef CsvExporter = Future<CsvExportResult> Function({
  required List<Student> students,
  required String className,
});

/// Kết quả của các thao tác đồng bộ / lưu điểm danh
class OperationResult {
  final bool success;
  final String message;
  final bool requiresConfiguration;

  const OperationResult({
    required this.success,
    required this.message,
    this.requiresConfiguration = false,
  });
}

/// Abstract API Client cho phép Dependency Injection và Unit Testing mà không gọi Google Apps Script thật
abstract class AttendanceApiClient {
  Future<Map<String, dynamic>> testConnection(String sheetUrl);
  Future<List<String>> fetchClasses(String sheetUrl);
  Future<List<Student>> fetchStudents(String sheetUrl, String className);
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot);
  Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
  });
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  });
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className);
}

/// Default Client chuyển tiếp sang GoogleSheetService
class DefaultAttendanceApiClient implements AttendanceApiClient {
  const DefaultAttendanceApiClient();

  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) =>
      GoogleSheetService.testConnection(sheetUrl);

  @override
  Future<List<String>> fetchClasses(String sheetUrl) =>
      GoogleSheetService.fetchClasses(sheetUrl);

  @override
  Future<List<Student>> fetchStudents(String sheetUrl, String className) =>
      GoogleSheetService.fetchStudents(sheetUrl, className);

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) =>
      GoogleSheetService.fetchAttendance(sheetUrl, className, date, slot);

  @override
  Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
  }) =>
      GoogleSheetService.saveAttendance(
        webAppUrl: webAppUrl,
        className: className,
        date: date,
        slot: slot,
        records: records,
      );

  @override
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) =>
      GoogleSheetService.syncStudents(
        webAppUrl: webAppUrl,
        className: className,
        students: students,
      );

  @override
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className) =>
      GoogleSheetService.fetchAnalyticsLogs(sheetUrl, className);
}

/// State Manager quản lý phiên làm việc điểm danh, danh sách sinh viên và logs phân tích
class AttendanceSessionManager extends ChangeNotifier {
  final AttendanceApiClient apiClient;
  final CsvExporter _csvExporter;

  String _currentClass;
  List<String> _availableClasses = [];
  bool _isLoadingClasses = false;
  String? _classesError;
  int _classesRequestId = 0;

  int _currentSlot;
  DateTime _currentDate;
  String _sheetUrl;
  bool _isSheetConnected = false;
  bool _isLoading = false;
  String? _dataError;
  bool _isReloadError = false;
  bool _isExporting = false;

  List<Student> _students = [];
  List<AttendanceRecord> _records = [];
  List<Map<String, dynamic>> _historyLogs = [];
  AnalyticsDataStatus _analyticsStatus = AnalyticsDataStatus.unconfigured;
  String? _analyticsError;
  bool _isLoadingAnalytics = false;

  int _dataRequestId = 0;
  int _analyticsRequestId = 0;
  bool _disposed = false;

  AttendanceSessionManager({
    this.apiClient = const DefaultAttendanceApiClient(),
    CsvExporter? csvExporter,
    String initialClass = 'SE1801',
    List<String> initialClasses = const [],
    int initialSlot = 1,
    DateTime? initialDate,
    String initialSheetUrl = '',
  })  : _csvExporter = csvExporter ?? CsvExportService.exportToFile,
        _currentClass = initialClass,
        _availableClasses = List.from(initialClasses),
        _currentSlot = initialSlot,
        _currentDate = initialDate ?? DateTime.now(),
        _sheetUrl = initialSheetUrl;

  // Getters
  String get currentClass => _currentClass;
  List<String> get availableClasses => List.unmodifiable(_availableClasses);
  bool get isLoadingClasses => _isLoadingClasses;
  String? get classesError => _classesError;
  int get currentSlot => _currentSlot;
  DateTime get currentDate => _currentDate;
  String get sheetUrl => _sheetUrl;
  bool get isSheetConnected => _isSheetConnected;
  bool get isSheetConfigured => _sheetUrl.trim().isNotEmpty;
  bool get isLoading => _isLoading;
  String? get dataError => _dataError;
  bool get isReloadError => _isReloadError;
  bool get isExporting => _isExporting;

  List<Student> get students => List.unmodifiable(_students);
  List<AttendanceRecord> get records => List.unmodifiable(_records);
  List<Map<String, dynamic>> get historyLogs => List.unmodifiable(_historyLogs);
  AnalyticsDataStatus get analyticsStatus => _analyticsStatus;
  String? get analyticsError => _analyticsError;
  bool get isLoadingAnalytics => _isLoadingAnalytics;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Khởi tạo dữ liệu ban đầu từ StorageService hoặc giá trị đã nạp
  Future<void> initialize({bool loadStorage = true}) async {
    if (loadStorage) {
      await StorageService.init();
      final savedUrl = StorageService.getGoogleSheetUrl();
      final savedClass = StorageService.getSelectedClass();
      if (savedUrl.isNotEmpty) _sheetUrl = savedUrl;
      if (savedClass.isNotEmpty) _currentClass = savedClass;
    }

    _isLoading = true;
    notifyListeners();

    if (_sheetUrl.isNotEmpty) {
      try {
        final res = await apiClient.testConnection(_sheetUrl);
        _isSheetConnected = res['success'] == true;
      } catch (_) {
        _isSheetConnected = false;
      }
    } else {
      _isSheetConnected = false;
    }

    if (_isSheetConnected) {
      await loadClasses(forceReloadDataIfClassMatches: true);
    } else {
      await loadStudentsAndAttendance(isClassChange: true);
      await loadAnalyticsLogs();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tải danh sách lớp hợp lệ từ Google Sheet
  Future<void> loadClasses({bool forceReloadDataIfClassMatches = false}) async {
    final cleanUrl = _sheetUrl.trim();
    if (cleanUrl.isEmpty) {
      _availableClasses = [];
      _isLoadingClasses = false;
      _classesError = null;
      notifyListeners();
      return;
    }

    final requestId = ++_classesRequestId;
    _isLoadingClasses = true;
    _classesError = null;
    notifyListeners();

    try {
      final classes = await apiClient.fetchClasses(cleanUrl);

      // Chống race condition khi URL đổi hoặc manager đã dispose
      if (requestId != _classesRequestId || _disposed) return;

      _availableClasses = classes;
      _isLoadingClasses = false;
      _classesError = null;

      if (_availableClasses.isEmpty) {
        // Nếu danh sách rỗng, không tự bịa lớp và không gọi tải/sync điểm danh với tên lớp rỗng
        _currentClass = '';
        _students = [];
        _records = [];
        _dataError = null;
        notifyListeners();
        return;
      }

      // Xử lý chọn lớp:
      final classStillExists = _currentClass.isNotEmpty && _availableClasses.contains(_currentClass);
      if (classStillExists) {
        // Lớp đang chọn vẫn còn tồn tại: giữ nguyên!
        // Không tự tải lại dữ liệu nếu lớp không đổi (tránh mất state đang nhập dở)
        notifyListeners();
        if (forceReloadDataIfClassMatches) {
          await Future.wait([
            loadStudentsAndAttendance(isClassChange: true),
            loadAnalyticsLogs(_currentClass),
          ]);
        }
      } else {
        // Lớp hiện tại không còn tồn tại: chọn lớp đầu tiên một cách xác định
        _currentClass = _availableClasses.first;
        StorageService.setSelectedClass(_currentClass);
        notifyListeners();
        await Future.wait([
          loadStudentsAndAttendance(isClassChange: true),
          loadAnalyticsLogs(_currentClass),
        ]);
      }
    } catch (e) {
      if (requestId != _classesRequestId || _disposed) return;
      _isLoadingClasses = false;
      _classesError = e is GoogleSheetException ? e.message : 'Không thể tải danh sách lớp: $e';
      notifyListeners();
    }
  }

  /// Chuyển lớp đang chọn và nạp lại dữ liệu
  Future<void> selectClass(String newClass) async {
    final trimmed = newClass.trim();
    if (trimmed.isEmpty) return;
    if (_availableClasses.isNotEmpty && !_availableClasses.contains(trimmed)) return;
    if (_currentClass == trimmed && _students.isNotEmpty) return;

    _currentClass = trimmed;
    _students = [];
    _records = [];
    _dataError = null;
    _isReloadError = false;
    notifyListeners();

    if (_availableClasses.isEmpty || _availableClasses.contains(trimmed)) {
      StorageService.setSelectedClass(trimmed);
    }
    await Future.wait([
      loadStudentsAndAttendance(isClassChange: true),
      loadAnalyticsLogs(trimmed),
    ]);
  }

  /// Chuyển slot học đang chọn
  Future<void> selectSlot(int newSlot) async {
    if (_currentSlot == newSlot) return;
    _currentSlot = newSlot;
    notifyListeners();
    await loadStudentsAndAttendance(isClassChange: false);
  }

  /// Đổi ngày điểm danh
  Future<void> selectDate(DateTime newDate) async {
    _currentDate = newDate;
    notifyListeners();
    await loadStudentsAndAttendance(isClassChange: false);
  }

  /// Cập nhật và lưu Google Sheet Web App URL
  Future<void> setSheetUrl(String url) async {
    _sheetUrl = url;
    _isSheetConnected = url.trim().isNotEmpty;
    _classesError = null;
    _availableClasses = [];
    notifyListeners();

    StorageService.setGoogleSheetUrl(url);
    if (_isSheetConnected) {
      await loadClasses(forceReloadDataIfClassMatches: true);
    } else {
      _currentClass = '';
      _students = [];
      _records = [];
      notifyListeners();
    }
  }

  /// Tải danh sách sinh viên và bản ghi điểm danh với cơ chế chống race condition
  Future<String?> loadStudentsAndAttendance({bool isClassChange = false}) async {
    final cleanUrl = _sheetUrl.trim();
    if (cleanUrl.isEmpty || _currentClass.trim().isEmpty) {
      _students = [];
      _records = [];
      _isLoading = false;
      _dataError = null;
      _isReloadError = false;
      notifyListeners();
      return null;
    }

    final requestId = ++_dataRequestId;
    _isLoading = true;
    if (isClassChange) {
      _students = [];
      _records = [];
      _dataError = null;
      _isReloadError = false;
    }
    notifyListeners();

    try {
      final students = await apiClient.fetchStudents(cleanUrl, _currentClass);
      final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';

      List<AttendanceRecord> existingRecords = [];
      try {
        existingRecords = await apiClient.fetchAttendance(
          cleanUrl,
          _currentClass,
          dateStr,
          _currentSlot,
        );
      } catch (_) {
        // Attendance logs may not exist yet for this class/slot
      }

      if (_disposed || requestId != _dataRequestId) return null;

      final records = <AttendanceRecord>[];
      for (final s in students) {
        final found = existingRecords.where((r) => r.rollNumber == s.rollNumber).firstOrNull;
        if (found != null) {
          records.add(found);
        } else {
          records.add(
            AttendanceRecord(
              rollNumber: s.rollNumber,
              className: _currentClass,
              date: dateStr,
              slot: _currentSlot,
              status: AttendanceStatus.present,
            ),
          );
        }
      }

      _students = students;
      _records = records;
      _isLoading = false;
      _dataError = null;
      _isReloadError = false;
      notifyListeners();
      return null;
    } catch (e) {
      if (_disposed || requestId != _dataRequestId) return null;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();

      _isLoading = false;
      _dataError = errorMsg;
      if (isClassChange || _students.isEmpty) {
        _students = [];
        _records = [];
        _isReloadError = false;
      } else {
        _isReloadError = true;
      }
      notifyListeners();
      return errorMsg;
    }
  }

  /// Nạp logs lịch sử điểm danh với cơ chế chống race condition
  Future<void> loadAnalyticsLogs([String? targetClass]) async {
    final className = (targetClass ?? _currentClass).trim();
    if (_sheetUrl.isEmpty || className.isEmpty) {
      _analyticsStatus = _sheetUrl.isEmpty ? AnalyticsDataStatus.unconfigured : AnalyticsDataStatus.empty;
      _historyLogs = [];
      _analyticsError = null;
      _isLoadingAnalytics = false;
      notifyListeners();
      return;
    }

    final currentRequestId = ++_analyticsRequestId;
    _isLoadingAnalytics = true;
    _analyticsError = null;
    notifyListeners();

    try {
      final logs = await apiClient.fetchAnalyticsLogs(_sheetUrl, className);
      if (_disposed || currentRequestId != _analyticsRequestId) return;

      _historyLogs = logs;
      _isLoadingAnalytics = false;
      _analyticsStatus = logs.isEmpty ? AnalyticsDataStatus.empty : AnalyticsDataStatus.loaded;
      _analyticsError = null;
      notifyListeners();
    } catch (e) {
      if (_disposed || currentRequestId != _analyticsRequestId) return;
      _historyLogs = [];
      _isLoadingAnalytics = false;
      _analyticsStatus = AnalyticsDataStatus.error;
      _analyticsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Tải lại toàn bộ dữ liệu hiện tại
  Future<String?> reload() async {
    final err = await loadStudentsAndAttendance(isClassChange: false);
    await loadAnalyticsLogs();
    return err;
  }

  /// Cập nhật trạng thái điểm danh cho 1 sinh viên (Present/Absent/Late)
  void updateAttendanceStatus(String rollNumber, AttendanceStatus newStatus) {
    final rec = _records.where((r) => r.rollNumber == rollNumber).firstOrNull;
    if (rec != null && rec.status != newStatus) {
      rec.status = newStatus;
      notifyListeners();
    }
  }

  /// Cập nhật ghi chú điểm danh cho 1 sinh viên
  void updateNote(String rollNumber, String newNote) {
    final rec = _records.where((r) => r.rollNumber == rollNumber).firstOrNull;
    if (rec != null && rec.note != newNote) {
      rec.note = newNote;
      notifyListeners();
    }
  }

  /// Đánh dấu tất cả có mặt
  void markAllPresent() {
    var changed = false;
    for (final r in _records) {
      if (r.status != AttendanceStatus.present) {
        r.status = AttendanceStatus.present;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Đánh dấu tất cả vắng
  void markAllAbsent() {
    var changed = false;
    for (final r in _records) {
      if (r.status != AttendanceStatus.absent) {
        r.status = AttendanceStatus.absent;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Lưu điểm danh lên Google Sheets (idempotent, không race condition, cập nhật analytics khi thành công)
  Future<OperationResult> saveAttendance() async {
    if (_sheetUrl.isEmpty) {
      return const OperationResult(
        success: false,
        message: '⚠️ Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt trước!',
        requiresConfiguration: true,
      );
    }

    _isLoading = true;
    notifyListeners();

    final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    try {
      final result = await apiClient.saveAttendance(
        webAppUrl: _sheetUrl,
        className: _currentClass,
        date: dateStr,
        slot: _currentSlot,
        records: _records,
      );
      _isLoading = false;
      notifyListeners();

      final isSuccess = result['success'] == true;
      if (isSuccess) {
        await loadAnalyticsLogs();
      }

      return OperationResult(
        success: isSuccess,
        message: result['message']?.toString() ?? (isSuccess ? '✓ Đã lưu điểm danh lên Google Sheets!' : 'Lỗi khi lưu điểm danh.'),
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return OperationResult(
        success: false,
        message: e.toString().replaceAll('Exception: ', '').trim(),
      );
    }
  }

  /// Đồng bộ danh sách sinh viên lên Google Sheets
  Future<OperationResult> syncStudents() async {
    if (_sheetUrl.isEmpty) {
      return const OperationResult(
        success: false,
        message: '⚠️ Vui lòng cấu hình URL Google Sheet trong mục Cài đặt!',
        requiresConfiguration: true,
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await apiClient.syncStudents(
        webAppUrl: _sheetUrl,
        className: _currentClass,
        students: _students,
      );
      _isLoading = false;
      notifyListeners();

      final isSuccess = res['success'] == true;
      return OperationResult(
        success: isSuccess,
        message: res['message']?.toString() ?? (isSuccess ? '✓ Đã đồng bộ sinh viên lên Google Sheets!' : 'Lỗi đồng bộ.'),
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return OperationResult(
        success: false,
        message: e.toString().replaceAll('Exception: ', '').trim(),
      );
    }
  }

  /// Import danh sách sinh viên mới từ FAP và khởi tạo records tương ứng
  void importStudents(List<Student> newStudents) {
    _students = newStudents;
    _dataError = null;
    _isReloadError = false;
    final dateStr = _currentDate.toIso8601String();
    _records = newStudents.map((s) {
      return AttendanceRecord(
        rollNumber: s.rollNumber,
        className: _currentClass,
        date: dateStr,
        slot: _currentSlot,
        status: AttendanceStatus.present,
      );
    }).toList();
    notifyListeners();
  }

  /// Cập nhật danh sách sinh viên trong bộ nhớ
  void updateStudents(List<Student> updated) {
    _students = updated;
    notifyListeners();
  }

  /// Xuất báo cáo chuyên cần hiện tại ra file CSV
  Future<CsvExportResult> exportCurrentReportCsv() async {
    if (_isExporting) {
      return const CsvExportResult(
        success: false,
        message: 'Đang trong quá trình xuất file CSV, vui lòng chờ.',
      );
    }

    if (_students.isEmpty) {
      return const CsvExportResult(
        success: false,
        message: 'Chưa có dữ liệu sinh viên để xuất báo cáo.',
      );
    }

    _isExporting = true;
    notifyListeners();

    try {
      final result = await _csvExporter(
        students: _students,
        className: _currentClass,
      );
      _isExporting = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isExporting = false;
      notifyListeners();
      return CsvExportResult(
        success: false,
        message: 'Lỗi trong quá trình xuất file CSV: $e',
      );
    }
  }
}
