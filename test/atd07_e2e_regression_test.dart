import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/screens/attendance_overview_view.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/screens/main_desktop_screen.dart';
import 'package:birdle/screens/reports_view.dart';
import 'package:birdle/screens/ai_insights_view.dart';
import 'package:birdle/screens/fap_sync_view.dart';
import 'package:birdle/screens/settings_view.dart';
import 'package:birdle/services/google_sheet_service.dart';
import 'package:birdle/state/attendance_session_manager.dart';
import 'package:birdle/widgets/apps_script_template_card.dart';
import 'package:birdle/widgets/weekly_schedule_view.dart';

class MockAtd07ApiClient implements AttendanceApiClient {
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
      Student(rollNumber: 'SE170001', fullName: 'Nguyễn Văn An', className: className),
      Student(rollNumber: 'SE170002', fullName: 'Trần Thị Bình', className: className),
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
          currentSession: 5,
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
          currentSession: 8,
          totalSessions: 20,
          sessionStatus: SessionStatus.notYet,
          lastSession: 7,
          lastDate: DateTime(2026, 9, 18),
          lastStatus: 'present',
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleSheetService.lastClassMetadata.clear();
  });

  group('ATD-07: Regression Test & Đồng Bộ Settings', () {
    test('1. Code.gs contains complete implementation of getAttendanceOverview & core actions', () {
      final file = File('google-apps-script/Code.gs');
      expect(file.existsSync(), isTrue, reason: 'google-apps-script/Code.gs must exist in repo root');

      final content = file.readAsStringSync();
      expect(content.contains('SpreadsheetApp'), isTrue);
      expect(content.contains('getAttendanceOverview'), isTrue,
          reason: 'Code.gs must implement getAttendanceOverview action');
      expect(content.contains('saveAttendance'), isTrue);
      expect(content.contains('getStudents'), isTrue);
      expect(content.contains('syncStudents'), isTrue);
      expect(content.contains('getClasses'), isTrue);
      expect(content.contains('LockService'), isTrue);
    });

    testWidgets('2. Sidebar contains exactly 5 items and excludes Dashboard and Students',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = MockAtd07ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );
      await manager.initialize(loadStorage: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainDesktopScreen(sessionManager: manager),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify exactly 5 items on the sidebar
      expect(find.widgetWithText(InkWell, 'Attendance'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Reports'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'AI Insights'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'FAP Sync'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Settings'), findsOneWidget);

      // Verify Dashboard and Students are NOT present on sidebar
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Students'), findsNothing);

      manager.dispose();
    });

    testWidgets('3. Navigation across all 5 modules works properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = MockAtd07ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );
      await manager.initialize(loadStorage: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainDesktopScreen(sessionManager: manager),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Initial tab: Attendance Overview Hub
      expect(find.byType(AttendanceOverviewView), findsOneWidget);
      expect(find.byType(WeeklyScheduleView), findsOneWidget);

      // 2. Navigate to Reports
      await tester.tap(find.widgetWithText(InkWell, 'Reports'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReportsView), findsOneWidget);

      // 3. Navigate to AI Insights
      await tester.tap(find.widgetWithText(InkWell, 'AI Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AiInsightsView), findsOneWidget);

      // 4. Navigate to FAP Sync
      await tester.tap(find.widgetWithText(InkWell, 'FAP Sync'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FapSyncView), findsOneWidget);

      // 5. Navigate to Settings
      await tester.tap(find.widgetWithText(InkWell, 'Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.byType(AppsScriptTemplateCard), findsOneWidget);

      // 6. Return to Attendance (resets to Hub)
      await tester.tap(find.widgetWithText(InkWell, 'Attendance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AttendanceOverviewView), findsOneWidget);

      manager.dispose();
    });

    testWidgets('4. Class tile click navigates to student attendance list and back button returns to Hub',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = MockAtd07ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );
      await manager.initialize(loadStorage: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainDesktopScreen(sessionManager: manager),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Click class SE1801 on the timetable
      final actionBtn = find.textContaining('SE1801').first;
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Now inside AttendanceView detail
      expect(find.byType(AttendanceView), findsOneWidget);
      expect(find.byKey(const Key('btnBackToOverview')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('btnBackToOverview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Returned to Overview Hub
      expect(find.byType(AttendanceOverviewView), findsOneWidget);
      expect(find.byType(WeeklyScheduleView), findsOneWidget);

      manager.dispose();
    });
  });
}
