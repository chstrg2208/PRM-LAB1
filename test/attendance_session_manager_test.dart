import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/state/attendance_session_manager.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/screens/main_desktop_screen.dart';

class FakeAttendanceApiClient implements AttendanceApiClient {
  Future<Map<String, dynamic>> Function(String sheetUrl)? onTestConnection;
  Future<List<String>> Function(String sheetUrl)? onFetchClasses;
  Future<List<Student>> Function(String sheetUrl, String className)? onFetchStudents;
  Future<List<AttendanceRecord>> Function(String sheetUrl, String className, String date, int slot)? onFetchAttendance;
  Future<Map<String, dynamic>> Function({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
  })? onSaveAttendance;
  Future<Map<String, dynamic>> Function({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  })? onSyncStudents;
  Future<List<Map<String, dynamic>>> Function(String sheetUrl, String className)? onFetchAnalyticsLogs;

  int saveCallCount = 0;
  int fetchAnalyticsLogsCallCount = 0;

  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) async {
    if (onTestConnection != null) {
      return onTestConnection!(sheetUrl);
    }
    return {'success': sheetUrl.isNotEmpty};
  }

  @override
  Future<List<String>> fetchClasses(String sheetUrl) async {
    if (onFetchClasses != null) {
      return onFetchClasses!(sheetUrl);
    }
    return ['SE1801', 'SE1802', 'INIT', 'CLASS_SLOW', 'CLASS_FAST'];
  }

  @override
  Future<List<Student>> fetchStudents(String sheetUrl, String className) async {
    if (onFetchStudents != null) {
      return onFetchStudents!(sheetUrl, className);
    }
    return [];
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async {
    if (onFetchAttendance != null) {
      return onFetchAttendance!(sheetUrl, className, date, slot);
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
    int? sessionNumber,
    bool bypassDateLock = false,
  }) async {
    saveCallCount++;
    if (onSaveAttendance != null) {
      return onSaveAttendance!(
        webAppUrl: webAppUrl,
        className: className,
        date: date,
        slot: slot,
        records: records,
      );
    }
    return {'success': true, 'message': 'Đã lưu điểm danh thành công'};
  }

  @override
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) async {
    if (onSyncStudents != null) {
      return onSyncStudents!(
        webAppUrl: webAppUrl,
        className: className,
        students: students,
      );
    }
    return {'success': true, 'message': 'Đồng bộ thành công'};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className) async {
    fetchAnalyticsLogsCallCount++;
    if (onFetchAnalyticsLogs != null) {
      return onFetchAnalyticsLogs!(sheetUrl, className);
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String sheetUrl, {DateTime? date}) async {
    return [];
  }
}

void main() {
  group('BK-08: AttendanceSessionManager Unit Tests', () {
    test('1. Manager initialization without sheetUrl sets empty state without errors', () async {
      final fakeApi = FakeAttendanceApiClient();
      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: '',
        initialClass: 'SE1801',
      );

      await manager.initialize(loadStorage: false);

      expect(manager.isSheetConfigured, false);
      expect(manager.isSheetConnected, false);
      expect(manager.isLoading, false);
      expect(manager.dataError, isNull);
      expect(manager.students, isEmpty);
      expect(manager.records, isEmpty);

      // Calling load when unconfigured does not crash
      await manager.loadStudentsAndAttendance();
      expect(manager.students, isEmpty);
      expect(manager.dataError, isNull);

      manager.dispose();
    });

    test('1.1. Manager loads students and attendance with real API response', () async {
      final fakeApi = FakeAttendanceApiClient();
      fakeApi.onFetchStudents = (url, className) async => [
        Student(
          member: 'SE170123',
          code: 'SE170123',
          surname: 'Nguyễn',
          middleName: 'Văn',
          givenName: 'An',
          className: className,
        ),
      ];
      fakeApi.onFetchAttendance = (url, className, date, slot) async => [
        AttendanceRecord(
          rollNumber: 'SE170123',
          className: className,
          date: date,
          slot: slot,
          status: AttendanceStatus.absent,
          note: 'Báo ốm',
        ),
      ];

      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
        initialClass: 'SE1801',
      );

      await manager.initialize(loadStorage: false);

      expect(manager.isLoading, false);
      expect(manager.students.length, 1);
      expect(manager.students.first.fullName, 'Nguyễn Văn An');
      expect(manager.records.length, 1);
      expect(manager.records.first.status, AttendanceStatus.absent);
      expect(manager.records.first.note, 'Báo ốm');

      manager.dispose();
    });

    test('2. Class and Slot change updates session state and triggers reload', () async {
      final fakeApi = FakeAttendanceApiClient();
      fakeApi.onFetchStudents = (url, className) async => [
        Student(rollNumber: '${className}_01', fullName: 'Student 1', className: className),
      ];

      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      expect(manager.currentClass, 'SE1801');
      expect(manager.students.first.rollNumber, 'SE1801_01');

      // Switch Class
      await manager.selectClass('SE1802');
      expect(manager.currentClass, 'SE1802');
      expect(manager.students.first.rollNumber, 'SE1802_01');

      // Switch Slot
      await manager.selectSlot(3);
      expect(manager.currentSlot, 3);

      manager.dispose();
    });

    test('3. Race Condition protection: slower earlier request does not overwrite faster latest request', () async {
      final fakeApi = FakeAttendanceApiClient();

      // Class A will take 80ms, Class B will take 10ms
      fakeApi.onFetchStudents = (url, className) async {
        if (className == 'CLASS_SLOW') {
          await Future.delayed(const Duration(milliseconds: 80));
          return [Student(rollNumber: 'SLOW_01', fullName: 'Slow', className: className)];
        } else {
          await Future.delayed(const Duration(milliseconds: 10));
          return [Student(rollNumber: 'FAST_01', fullName: 'Fast', className: className)];
        }
      };

      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'INIT',
      );
      await manager.initialize(loadStorage: false);

      // Fire SLOW then immediately FAST
      final slowFuture = manager.selectClass('CLASS_SLOW');
      final fastFuture = manager.selectClass('CLASS_FAST');

      await Future.wait([slowFuture, fastFuture]);

      // State MUST be CLASS_FAST
      expect(manager.currentClass, 'CLASS_FAST');
      expect(manager.students.length, 1);
      expect(manager.students.first.rollNumber, 'FAST_01');

      manager.dispose();
    });

    test('4. Attendance record operations (status, note, markAllPresent, markAllAbsent)', () async {
      final fakeApi = FakeAttendanceApiClient();
      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: '',
      );

      final sampleStudents = [
        Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801'),
        Student(rollNumber: 'SE2', fullName: 'SV 2', className: 'SE1801'),
      ];
      manager.importStudents(sampleStudents);

      expect(manager.students.length, 2);
      expect(manager.records.length, 2);
      expect(manager.records.every((r) => r.status == AttendanceStatus.present), true);

      // Update individual status & note
      manager.updateAttendanceStatus('SE1', AttendanceStatus.absent);
      manager.updateNote('SE1', 'Nghỉ có phép');

      expect(manager.records.firstWhere((r) => r.rollNumber == 'SE1').status, AttendanceStatus.absent);
      expect(manager.records.firstWhere((r) => r.rollNumber == 'SE1').note, 'Nghỉ có phép');

      // Mark All Absent
      manager.markAllAbsent();
      expect(manager.records.every((r) => r.status == AttendanceStatus.absent), true);

      // Mark All Present
      manager.markAllPresent();
      expect(manager.records.every((r) => r.status == AttendanceStatus.present), true);

      manager.dispose();
    });

    test('5. Save attendance triggers reloadAnalyticsLogs on success and handles failures', () async {
      final fakeApi = FakeAttendanceApiClient();
      bool shouldFailSave = false;

      fakeApi.onSaveAttendance = ({
        required webAppUrl,
        required className,
        required date,
        required slot,
        required records,
      }) async {
        if (shouldFailSave) {
          throw Exception('Network disconnected');
        }
        return {'success': true, 'message': 'Đã lưu điểm danh thành công'};
      };

      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      manager.importStudents([Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801')]);

      final initialAnalyticsLogsCalls = fakeApi.fetchAnalyticsLogsCallCount;

      // 5.1 Success save
      final resSuccess = await manager.saveAttendance();
      expect(resSuccess.success, true);
      expect(resSuccess.message.contains('thành công'), true);
      expect(fakeApi.saveCallCount, 1);
      expect(fakeApi.fetchAnalyticsLogsCallCount, initialAnalyticsLogsCalls + 1);

      // 5.2 Failure save
      shouldFailSave = true;
      final resFailure = await manager.saveAttendance();
      expect(resFailure.success, false);
      expect(resFailure.message.contains('Network disconnected'), true);

      // 5.3 Save without sheet configured
      await manager.setSheetUrl('');
      final resUnconfigured = await manager.saveAttendance();
      expect(resUnconfigured.success, false);
      expect(resUnconfigured.requiresConfiguration, true);

      manager.dispose();
    });

    test('6. Listener lifecycle: notifies on state change and does not notify after dispose', () async {
      final fakeApi = FakeAttendanceApiClient();
      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: '',
      );

      int notifyCount = 0;
      manager.addListener(() {
        notifyCount++;
      });

      manager.updateNote('NON_EXISTENT', 'test'); // Not found, no notify
      expect(notifyCount, 0);

      manager.importStudents([Student(rollNumber: 'S1', fullName: 'SV 1', className: 'C1')]);
      expect(notifyCount > 0, true);

      final prevCount = notifyCount;
      manager.dispose();

      // Calling operations after dispose must be safe and not throw / notify
      manager.updateNote('S1', 'After dispose');
      expect(notifyCount, prevCount);
    });

    testWidgets('7. MainDesktopScreen integration smoke test with AttendanceSessionManager', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeAttendanceApiClient();
      fakeApi.onFetchStudents = (url, className) async => [
        Student(rollNumber: 'SE170123', fullName: 'Nguyễn Văn An', className: className),
      ];

      final manager = AttendanceSessionManager(
        apiClient: fakeApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      await tester.pumpWidget(
        MaterialApp(
          home: MainDesktopScreen(sessionManager: manager),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('BIRDLE'), findsOneWidget);
      expect(find.text('Sheets: Connected'), findsOneWidget);
      // ATD-04: Default screen is now Overview (index 0)
      expect(find.text('Attendance / Overview'), findsOneWidget);

      // Verify sidebar contains the 6 required navigation items (Overview added)
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('FAP Sync'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify Dashboard and Students are decoupled from navigation
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Students'), findsNothing);

      manager.dispose();
    });
  });
}
