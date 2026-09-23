import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_schedule.dart';
import '../models/class_session.dart';
import '../models/class_overview_item.dart';
import '../models/qr_attendance_session.dart';

export '../models/class_overview_item.dart';
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
    int? sessionNumber,
    bool bypassDateLock = false,
  });
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  });
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className);
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String sheetUrl, {DateTime? date});
  Future<AttendanceOverview> fetchAttendanceOverview(String sheetUrl) async =>
      const AttendanceOverview();
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
    int? sessionNumber,
    bool bypassDateLock = false,
  }) =>
      GoogleSheetService.saveAttendance(
        webAppUrl: webAppUrl,
        className: className,
        date: date,
        slot: slot,
        records: records,
        sessionNumber: sessionNumber,
        bypassDateLock: bypassDateLock,
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

  @override
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String sheetUrl, {DateTime? date}) =>
      GoogleSheetService.fetchTodayClasses(sheetUrl, date: date);

  @override
  Future<AttendanceOverview> fetchAttendanceOverview(String sheetUrl) =>
      GoogleSheetService.fetchAttendanceOverview(sheetUrl);
}

/// State Manager quản lý phiên làm việc điểm danh, danh sách sinh viên và logs phân tích
class AttendanceSessionManager extends ChangeNotifier {
  final AttendanceApiClient apiClient;
  final CsvExporter? _customExporter;

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

  List<Map<String, dynamic>> _todayClasses = [];
  bool _isLoadingTodayClasses = false;
  QrAttendanceSession? _activeQrSession;
  int _currentSessionNumber = 1;
  bool _isQrCompleted = false;
  bool _isReopenedQr = false;
  String _sheetSessionStatus = '';

  AttendanceOverview? _attendanceOverview;
  bool _isLoadingOverview = false;
  String? _overviewError;

  AttendanceSessionManager({
    this.apiClient = const DefaultAttendanceApiClient(),
    CsvExporter? csvExporter,
    String initialClass = 'SE1801',
    List<String> initialClasses = const [],
    int initialSlot = 1,
    DateTime? initialDate,
    String initialSheetUrl = '',
  })  : _customExporter = csvExporter,
        _currentClass = initialClass,
        _availableClasses = List.from(initialClasses),
        _currentSlot = initialSlot,
        _currentDate = initialDate ?? DateTime.now(),
        _sheetUrl = initialSheetUrl {
    _currentSessionNumber = _calculateSessionNumber(_currentClass, _currentDate);
  }

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

  /// Kiểm tra buổi học có bị khóa ngày hay không (Chỉ mở điểm danh sau 00:00 của ngày học)
  bool get isSessionDateLocked {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sessionDayStart = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    return sessionDayStart.isAfter(todayStart);
  }

  /// Buổi học đã hoàn tất điểm danh (đã lưu lên Sheet hoặc đã hoàn tất phiên QR)
  bool get isSessionCompleted {
    if (_isQrCompleted) return true;
    final statusLower = _sheetSessionStatus.trim().toLowerCase();
    if (statusLower == 'đã điểm danh' || statusLower == 'done' || statusLower == 'completed') {
      return true;
    }
    if (_records.isNotEmpty && _records.every((r) => r.status != AttendanceStatus.notYet)) {
      return true;
    }
    return false;
  }

  /// Nút điểm danh QR có bị khóa chống gian lận hay không
  bool get isQrAttendanceLocked {
    if (isSessionDateLocked) return true;
    if (isSessionCompleted && !_isReopenedQr) return true;
    return false;
  }

  /// Phiên QR đang mở lại hay không
  bool get isReopenedQr => _isReopenedQr;

  List<Map<String, dynamic>> get todayClasses => List.unmodifiable(_todayClasses);
  bool get isLoadingTodayClasses => _isLoadingTodayClasses;
  QrAttendanceSession? get activeQrSession => _activeQrSession;
  int get currentSessionNumber => _currentSessionNumber;

  /// Thông tin lịch học chuẩn FPT của lớp hiện tại
  ClassSchedule get currentSchedule {
    final clean = _currentClass.trim().toUpperCase();
    final isIA = clean.startsWith('IA');
    return ClassSchedule(
      className: _currentClass,
      subjectCode: isIA ? 'CSN101' : 'PRM393',
      slot: _currentSlot,
      daysOfWeek: isIA ? 'T3-T6' : 'T2-T5',
      room: isIA ? 'NVH-603' : 'NVH-611',
      startDate: DateTime(2026, 9, 7),
      currentSession: _currentSessionNumber > 0 ? _currentSessionNumber : 1,
      totalSessions: 20,
    );
  }

  List<Student> get students => List.unmodifiable(_students);
  List<AttendanceRecord> get records => List.unmodifiable(_records);
  List<Map<String, dynamic>> get historyLogs => List.unmodifiable(_historyLogs);
  AnalyticsDataStatus get analyticsStatus => _analyticsStatus;
  String? get analyticsError => _analyticsError;
  bool get isLoadingAnalytics => _isLoadingAnalytics;

  AttendanceOverview? get attendanceOverview => _attendanceOverview;
  bool get isLoadingOverview => _isLoadingOverview;
  String? get overviewError => _overviewError;

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
    await Future.wait([
      loadTodayClasses(),
      loadAttendanceOverview(),
    ]);

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
    _currentSessionNumber = _calculateSessionNumber(trimmed, _currentDate);
    notifyListeners();

    if (_availableClasses.isEmpty || _availableClasses.contains(trimmed)) {
      StorageService.setSelectedClass(trimmed);
    }
    await Future.wait([
      loadStudentsAndAttendance(isClassChange: true),
      loadAnalyticsLogs(trimmed),
    ]);
  }

  /// ATD-05: Nạp dữ liệu Hub tổng quan lớp học
  Future<void> loadAttendanceOverview({bool force = false}) async {
    final cleanUrl = _sheetUrl.trim();
    if (cleanUrl.isEmpty) {
      _attendanceOverview = null;
      _isLoadingOverview = false;
      _overviewError = null;
      notifyListeners();
      return;
    }
    if (_isLoadingOverview && !force) return;
    _isLoadingOverview = true;
    _overviewError = null;
    notifyListeners();
    try {
      _attendanceOverview = await apiClient.fetchAttendanceOverview(cleanUrl);
    } catch (e) {
      _overviewError = e.toString();
    } finally {
      _isLoadingOverview = false;
      notifyListeners();
    }
  }

  /// Chuyển slot học đang chọn
  Future<void> selectSlot(int newSlot) async {
    if (_currentSlot == newSlot) return;
    _currentSlot = newSlot;
    _currentSessionNumber = _calculateSessionNumber(_currentClass, _currentDate);
    notifyListeners();
    await loadStudentsAndAttendance(isClassChange: false);
  }

  /// Đổi ngày điểm danh
  Future<void> selectDate(DateTime newDate) async {
    _currentDate = newDate;
    _currentSessionNumber = _calculateSessionNumber(_currentClass, newDate);
    notifyListeners();
    await Future.wait([
      loadStudentsAndAttendance(isClassChange: false),
      loadTodayClasses(newDate),
    ]);
  }

  /// Đổi buổi học (Session number 1..20) và đồng bộ trạng thái sinh viên theo cột buổi học đó
  void selectSessionNumber(int newSession) {
    if (newSession < 1 || newSession > 20) return;
    _currentSessionNumber = newSession;
    final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    _records = _students.map((s) {
      final slotVal = (newSession >= 1 && newSession <= s.slots20.length)
          ? s.slots20[newSession - 1]
          : '';
      final initialStatus = slotVal.isNotEmpty
          ? AttendanceStatus.fromString(slotVal)
          : AttendanceStatus.notYet;
      return AttendanceRecord(
        rollNumber: s.rollNumber,
        className: _currentClass,
        date: dateStr,
        slot: _currentSlot,
        status: initialStatus,
      );
    }).toList();

    final hasCompleted = _records.isNotEmpty &&
        _records.any((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.absent);
    _isQrCompleted = hasCompleted;
    _isReopenedQr = false;
    notifyListeners();
  }

  int _calculateSessionNumber(String className, DateTime date) {
    final metaSession = GoogleSheetService.lastClassMetadata['currentSession'];
    if (metaSession is int && metaSession >= 1 && metaSession <= 20) {
      return metaSession;
    }
    final clean = className.trim().toUpperCase();
    final sched = ClassSchedule(
      className: className,
      subjectCode: 'PRM393',
      slot: _currentSlot,
      daysOfWeek: clean.startsWith('IA') ? 'T3-T6' : 'T2-T5',
      room: 'BE-302',
      startDate: DateTime(2026, 9, 1),
    );
    return sched.calculateSessionNumber(date);
  }

  /// Tải danh sách các lớp có tiết học hôm nay theo chuẩn FPT
  Future<void> loadTodayClasses([DateTime? date]) async {
    final targetDate = date ?? _currentDate;
    _isLoadingTodayClasses = true;
    notifyListeners();

    try {
      if (_sheetUrl.trim().isNotEmpty) {
        final res = await apiClient.fetchTodayClasses(_sheetUrl, date: targetDate);
        if (res.isNotEmpty) {
          _todayClasses = res;
          _isLoadingTodayClasses = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // Fallback thông minh: Tự động lọc dựa trên thứ trong tuần của targetDate
    final fallbackList = <Map<String, dynamic>>[];
    final weekday = targetDate.weekday;

    // SE1801 học T2-T5 slot 1
    if (weekday == DateTime.monday || weekday == DateTime.thursday) {
      final schedSE = ClassSchedule(
        className: 'SE1801',
        subjectCode: 'PRM393',
        slot: 1,
        daysOfWeek: 'T2-T5',
        room: 'BE-302',
        startDate: DateTime(2026, 9, 1),
      );
      fallbackList.add({
        'className': 'SE1801',
        'subjectCode': 'PRM393',
        'slot': 1,
        'slotTime': ClassSession.getSlotTime(1),
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'sessionNumber': schedSE.calculateSessionNumber(targetDate),
        'totalSessions': 20,
        'totalStudents': _students.isNotEmpty && _currentClass == 'SE1801' ? _students.length : 10,
        'isAttendanceDone': false,
        'date': '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
      });
    }

    // IA1601 học T3-T6 slot 2
    if (weekday == DateTime.tuesday || weekday == DateTime.friday) {
      final schedIA = ClassSchedule(
        className: 'IA1601',
        subjectCode: 'PRM393',
        slot: 2,
        daysOfWeek: 'T3-T6',
        room: 'BE-304',
        startDate: DateTime(2026, 9, 1),
      );
      fallbackList.add({
        'className': 'IA1601',
        'subjectCode': 'PRM393',
        'slot': 2,
        'slotTime': ClassSession.getSlotTime(2),
        'daysOfWeek': 'T3-T6',
        'room': 'BE-304',
        'sessionNumber': schedIA.calculateSessionNumber(targetDate),
        'totalSessions': 20,
        'totalStudents': 5,
        'isAttendanceDone': false,
        'date': '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
      });
    }

    _todayClasses = fallbackList;
    _isLoadingTodayClasses = false;
    notifyListeners();
  }

  /// Khởi tạo phiên điểm danh QR động 30s
  QrAttendanceSession? startQrAttendanceSession({int? sessionNumber, bool forceReopen = false}) {
    if (isSessionDateLocked) return null;
    if (isQrAttendanceLocked && !forceReopen) return null;
    if (forceReopen) {
      _isReopenedQr = true;
    }
    final sessNo = sessionNumber ?? _currentSessionNumber;
    _activeQrSession = QrAttendanceSession(
      sessionId: '${_currentClass}_slot${_currentSlot}_buoi$sessNo',
      className: _currentClass,
      slot: _currentSlot,
      sessionNumber: sessNo,
      date: _currentDate,
      webAppUrl: _sheetUrl,
    );
    notifyListeners();
    return _activeQrSession;
  }

  /// Mở lại phiên điểm danh QR (cho phép giảng viên kích hoạt lại khi có sự cố)
  QrAttendanceSession? reopenQrAttendanceSession({int? sessionNumber}) {
    _isReopenedQr = true;
    return startQrAttendanceSession(sessionNumber: sessionNumber, forceReopen: true);
  }

  /// Lấy danh sách email sinh viên đã quét mã QR thành công từ backend
  Future<void> pollQrCheckIns() async {
    if (_activeQrSession == null) return;
    if (_sheetUrl.trim().isNotEmpty) {
      try {
        final checkedEmails = await GoogleSheetService.fetchQrCheckedInEmails(
          _sheetUrl,
          className: _currentClass,
          slot: _currentSlot,
          date: _currentDate,
        );
        for (final rawEmail in checkedEmails) {
          final email = rawEmail.trim().toLowerCase();
          _activeQrSession!.markCheckedIn(email);
          final student = _students.cast<Student?>().firstWhere(
            (s) {
              if (s == null) return false;
              final sEmail = s.email.trim().toLowerCase();
              final sRoll = s.rollNumber.trim().toLowerCase();
              return sEmail == email ||
                  sRoll == email ||
                  (sRoll.isNotEmpty && (email.contains(sRoll) || sRoll.contains(email))) ||
                  (sEmail.isNotEmpty && (email.contains(sEmail) || sEmail.contains(email)));
            },
            orElse: () => null,
          );
          if (student != null) {
            updateAttendanceStatus(student.rollNumber, AttendanceStatus.present);
          }
        }
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Hủy hoặc đóng phiên QR mà không làm thay đổi trạng thái sinh viên chưa quét
  void cancelQrAttendance() {
    _activeQrSession = null;
    notifyListeners();
  }

  /// Kết thúc điểm danh QR: Các sinh viên CHƯA quét mã tự động bị đánh Absent (vắng)
  void finishQrAttendance() {
    if (_activeQrSession == null) return;

    final checkedEmails = _activeQrSession!.checkedInEmails;

    for (final s in _students) {
      final emailClean = s.email.trim().toLowerCase();
      final rollClean = s.rollNumber.trim().toLowerCase();
      final isPresent = checkedEmails.contains(emailClean) ||
          checkedEmails.contains(rollClean) ||
          checkedEmails.any((e) {
            if (e.isEmpty) return false;
            if (rollClean.isNotEmpty && (e == rollClean || e.contains(rollClean) || rollClean.contains(e))) {
              return true;
            }
            if (emailClean.isNotEmpty && (e == emailClean || e.contains(emailClean) || emailClean.contains(e))) {
              return true;
            }
            return false;
          });

      if (isPresent) {
        updateAttendanceStatus(s.rollNumber, AttendanceStatus.present);
      } else {
        updateAttendanceStatus(s.rollNumber, AttendanceStatus.absent);
      }
    }

    _activeQrSession = null;
    _isQrCompleted = true;
    _isReopenedQr = false;
    _sheetSessionStatus = 'Đã điểm danh';
    notifyListeners();
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

      // Tự động nhận diện slot và currentSession từ Sheet nếu có
      final metaSlot = GoogleSheetService.lastClassMetadata['slot'];
      if (metaSlot is int && metaSlot >= 1 && metaSlot <= 6) {
        _currentSlot = metaSlot;
      }
      final metaSession = GoogleSheetService.lastClassMetadata['currentSession'];
      if (metaSession is int && metaSession >= 1 && metaSession <= 20) {
        _currentSessionNumber = metaSession;
      } else if (isClassChange && students.isNotEmpty) {
        int nextSess = 1;
        for (int sn = 0; sn < 20; sn++) {
          final hasEmpty = students.any((s) => sn >= s.slots20.length || s.slots20[sn].isEmpty);
          if (hasEmpty) {
            nextSess = sn + 1;
            break;
          }
        }
        _currentSessionNumber = nextSess;
      }

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
          final slotVal = (_currentSessionNumber >= 1 && _currentSessionNumber <= s.slots20.length)
              ? s.slots20[_currentSessionNumber - 1]
              : '';
          final initialStatus = slotVal.isNotEmpty
              ? AttendanceStatus.fromString(slotVal)
              : AttendanceStatus.notYet;

          records.add(
            AttendanceRecord(
              rollNumber: s.rollNumber,
              className: _currentClass,
              date: dateStr,
              slot: _currentSlot,
              status: initialStatus,
            ),
          );
        }
      }

      _students = students;
      _records = records;
      _isLoading = false;
      _dataError = null;
      _isReloadError = false;

      final hasCompletedAttendance = records.isNotEmpty &&
          records.any((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.absent);
      if (hasCompletedAttendance) {
        _isQrCompleted = true;
      } else {
        _isQrCompleted = false;
      }
      _isReopenedQr = false;

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
    final className = (targetClass != null && targetClass.trim().isNotEmpty)
        ? targetClass.trim()
        : (_currentClass.trim().isNotEmpty
            ? _currentClass.trim()
            : (_availableClasses.isNotEmpty ? _availableClasses.first : 'SE1801_PRM393'));

    if (_sheetUrl.isEmpty) {
      _historyLogs = GoogleSheetService.getSampleAnalyticsLogs(className);
      _analyticsStatus = _historyLogs.isEmpty ? AnalyticsDataStatus.empty : AnalyticsDataStatus.loaded;
      _analyticsError = null;
      _isLoadingAnalytics = false;
      notifyListeners();
      return;
    }

    if (className.isEmpty) {
      _analyticsStatus = AnalyticsDataStatus.empty;
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
    await Future.wait([
      loadAnalyticsLogs(),
      loadAttendanceOverview(force: true),
    ]);
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

  /// Lưu điểm danh lên Google Sheets (idempotent, không race condition, cập nhật analytics khi thành công)  /// Lưu điểm danh hiện tại lên Google Sheets
  Future<OperationResult> saveAttendance({bool bypassDateLock = false}) async {
    if (_sheetUrl.isEmpty) {
      return const OperationResult(
        success: false,
        message: '⚠️ Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt trước!',
        requiresConfiguration: true,
      );
    }

    if (!bypassDateLock && isSessionDateLocked) {
      return OperationResult(
        success: false,
        message: 'Buổi học ngày ${_currentDate.day.toString().padLeft(2, '0')}/${_currentDate.month.toString().padLeft(2, '0')}/${_currentDate.year} chưa diễn ra! Chỉ được phép điểm danh sau 00:00 ngày học.',
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
        sessionNumber: _currentSessionNumber,
        bypassDateLock: bypassDateLock,
      );
      _isLoading = false;
      notifyListeners();

      final isSuccess = result['success'] == true;
      if (isSuccess) {
        _isQrCompleted = true;
        _isReopenedQr = false;
        _sheetSessionStatus = 'Đã điểm danh';
        await Future.wait([
          loadAnalyticsLogs(),
          loadTodayClasses(),
        ]);
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

  /// Xuất báo cáo chuyên cần hiện tại ra file CSV (hỗ trợ chọn dấu phân cách ; hoặc ,)
  Future<CsvExportResult> exportCurrentReportCsv({String delimiter = ';'}) async {
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
      final exporter = _customExporter;
      final result = exporter != null
          ? await exporter(
              students: _students,
              className: _currentClass,
            )
          : await CsvExportService.exportToFile(
              students: _students,
              className: _currentClass,
              delimiter: delimiter,
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
