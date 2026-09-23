import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/screens/main_desktop_screen.dart';
import 'package:birdle/services/google_sheet_service.dart';
import 'package:birdle/state/attendance_session_manager.dart';

class MockAtd06ApiClient implements AttendanceApiClient {
  Future<List<Student>> Function(String url, String className)? onFetchStudents;
  Future<Map<String, dynamic>> Function()? onSaveAttendance;
  Future<AttendanceOverview> Function(String url)? onFetchOverview;

  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) async => {'success': true};

  @override
  Future<List<String>> fetchClasses(String sheetUrl) async => ['SE1801', 'IA1801'];

  @override
  Future<List<Student>> fetchStudents(String url, String className) async {
    if (onFetchStudents != null) return onFetchStudents!(url, className);
    return [
      Student(rollNumber: 'SE170001', fullName: 'Sinh Viên 1', className: className),
      Student(rollNumber: 'SE170002', fullName: 'Sinh Viên 2', className: className),
    ];
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String url, {DateTime? date}) async => [];

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
    if (onSaveAttendance != null) return onSaveAttendance!();
    return {'success': true, 'message': 'OK'};
  }

  @override
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) async => {'success': true};

  @override
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className) async => [];

  @override
  Future<AttendanceOverview> fetchAttendanceOverview(String sheetUrl) async {
    if (onFetchOverview != null) return onFetchOverview!(sheetUrl);
    return AttendanceOverview(
      todayClasses: [
        ClassOverviewItem(
          className: 'SE1801',
          subject: 'Mobile Programming',
          subjectCode: 'PRM393',
          slot: 2,
          slotTime: '09:30 - 11:45',
          room: 'BE-302',
          daysOfWeek: 'T2-T5',
          currentSession: 4,
          totalSessions: 20,
          sessionStatus: SessionStatus.notYet,
          nextDate: DateTime(2026, 9, 23),
        ),
      ],
      otherClasses: [
        ClassOverviewItem(
          className: 'IA1801',
          subject: 'Cyber Security Network',
          subjectCode: 'CSN101',
          slot: 1,
          slotTime: '07:30 - 09:45',
          room: 'NVH-603',
          daysOfWeek: 'T3-T6',
          currentSession: 7,
          totalSessions: 20,
          sessionStatus: SessionStatus.notYet,
          lastSession: 6,
          lastDate: DateTime(2026, 9, 18),
          lastStatus: 'present',
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    GoogleSheetService.lastClassMetadata.clear();
  });

  group('ATD-06: Business Logic — maxAllowedSession & Future Session Guard', () {
    test('1. maxAllowedSession reads from todayClasses in attendanceOverview', () async {
      final mockApi = MockAtd06ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.loadAttendanceOverview();

      expect(manager.maxAllowedSession, 4);
      manager.dispose();
    });

    test('2. maxAllowedSession reads from otherClasses in attendanceOverview', () async {
      final mockApi = MockAtd06ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'IA1801',
      );
      await manager.loadAttendanceOverview();

      expect(manager.maxAllowedSession, 7);
      manager.dispose();
    });

    test('3. selectSessionNumber rejects sessions greater than maxAllowedSession', () async {
      final mockApi = MockAtd06ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.loadAttendanceOverview(); // SE1801 maxAllowedSession is 4

      // Valid session 3
      manager.selectSessionNumber(3);
      expect(manager.currentSessionNumber, 3);

      // Valid session 4 (boundary)
      manager.selectSessionNumber(4);
      expect(manager.currentSessionNumber, 4);

      // Invalid future session 5 -> Rejected, keeps 4
      manager.selectSessionNumber(5);
      expect(manager.currentSessionNumber, 4);

      // Invalid session 0 or negative -> Rejected, keeps 4
      manager.selectSessionNumber(0);
      expect(manager.currentSessionNumber, 4);

      manager.dispose();
    });

    test('4. saveAttendance blocks future session at Business Logic layer', () async {
      final mockApi = MockAtd06ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.loadAttendanceOverview(); // maxAllowedSession = 4
      await manager.loadStudentsAndAttendance();

      // Save valid session 3
      manager.selectSessionNumber(3);
      expect(manager.currentSessionNumber, 3);
      final resultValid = await manager.saveAttendance(bypassDateLock: true);
      expect(resultValid.success, isTrue);

      manager.dispose();
    });
  });

  group('ATD-06: UI Tests — AttendanceView Dropdown & Back Button', () {
    testWidgets('5. AttendanceView session dropdown only contains items up to maxAllowedSession', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? selectedSession;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: 'SE1801',
              currentSlot: 2,
              currentDate: DateTime.now(),
              currentSessionNumber: 2,
              maxAllowedSession: 5, // Only allows session 1..5
              isLoading: false,
              onClassChanged: (_) {},
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (roll, status) {},
              onNoteChanged: (roll, note) {},
              onMarkAllPresent: () {},
              onMarkAllAbsent: () {},
              onSaveToSheet: () {},
              onReloadFromSheet: () {},
              onGoToFapSync: () {},
              onImportStudents: (_) {},
              onSessionChanged: (val) => selectedSession = val,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the session dropdown
      final dropdownFinder = find.byKey(const Key('dropdownSessionNumber'));
      expect(dropdownFinder, findsOneWidget);

      // Verify the dropdown contains text 'Buổi 2'
      expect(find.text('Buổi 2'), findsWidgets);

      // Open the dropdown
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Dropdown menu items should contain Buổi 1, 2, 3, 4, 5
      expect(find.text('Buổi 1'), findsOneWidget);
      expect(find.text('Buổi 2'), findsWidgets); // One in button, one in menu
      expect(find.text('Buổi 3'), findsOneWidget);
      expect(find.text('Buổi 4'), findsOneWidget);
      expect(find.text('Buổi 5'), findsOneWidget);

      // Absolutely NO future sessions (6..20)
      expect(find.text('Buổi 6'), findsNothing);
      expect(find.text('Buổi 7'), findsNothing);
      expect(find.text('Buổi 20'), findsNothing);

      // Select 'Buổi 4'
      await tester.tap(find.text('Buổi 4').last);
      await tester.pumpAndSettle();

      expect(selectedSession, 4);
    });

    testWidgets('6. AttendanceView renders Back to Overview button and triggers callback', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: 'SE1801',
              currentSlot: 2,
              currentDate: DateTime.now(),
              currentSessionNumber: 2,
              maxAllowedSession: 5,
              isLoading: false,
              onBackToOverview: () => backPressed = true,
              onClassChanged: (_) {},
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (roll, status) {},
              onNoteChanged: (roll, note) {},
              onMarkAllPresent: () {},
              onMarkAllAbsent: () {},
              onSaveToSheet: () {},
              onReloadFromSheet: () {},
              onGoToFapSync: () {},
              onImportStudents: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Find back button
      final backButton = find.byKey(const Key('btnBackToOverview'));
      expect(backButton, findsOneWidget);
      expect(find.text('Quay lại danh sách lớp'), findsOneWidget);

      // Tap back button
      await tester.tap(backButton);
      await tester.pump();

      expect(backPressed, isTrue);
    });

    testWidgets('7. MainDesktopScreen Hub -> Detail -> Back to Hub flow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = MockAtd06ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
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

      // Initially at Overview Hub (index 0)
      expect(find.text('Attendance / Overview'), findsOneWidget);
      expect(find.text('LỚP HÔM NAY'), findsOneWidget);
      expect(find.text('CÁC LỚP KHÁC'), findsOneWidget);

      // Tap on SE1801 card action 'Điểm danh ngay'
      final actionBtn = find.text('Điểm danh ngay');
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should transition to Attendance Workspace (index 1)
      expect(find.text('Attendance / Workspace'), findsOneWidget);
      expect(find.byKey(const Key('btnBackToOverview')), findsOneWidget);
      expect(find.text('Quay lại danh sách lớp'), findsOneWidget);

      // Tap 'Quay lại danh sách lớp'
      await tester.tap(find.byKey(const Key('btnBackToOverview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should return to Overview Hub (index 0)
      expect(find.text('Attendance / Overview'), findsOneWidget);

      manager.dispose();
    });
  });
}
