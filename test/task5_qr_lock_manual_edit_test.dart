import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/state/attendance_session_manager.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/widgets/attendance_student_row.dart';

class MockTask5ApiClient implements AttendanceApiClient {
  @override
  Future<Map<String, dynamic>> testConnection(String url) async => {'success': true};

  @override
  Future<List<String>> fetchClasses(String url) async => ['SE1801'];

  @override
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String url, {DateTime? date}) async => [];

  @override
  Future<List<Student>> fetchStudents(String url, String className) async {
    return [
      Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: 'SE1801', email: 'annv@fpt.edu.vn'),
      Student(rollNumber: 'SE180102', fullName: 'Trần Thị Bình', className: 'SE1801', email: 'binhtt@fpt.edu.vn'),
    ];
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String url, String className) async => [];

  @override
  Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
    int? sessionNumber,
    bool bypassDateLock = false,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) async => {'success': true};

  @override
  Future<AttendanceOverview> fetchAttendanceOverview(String sheetUrl) async => const AttendanceOverview();
}

void main() {
  group('Task 5: QR Attendance Lock & Manual Override Tests', () {
    test('1. Session Manager locks QR after finishQrAttendance or saveAttendance', () async {
      final mockApi = MockTask5ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      expect(manager.isQrAttendanceLocked, false);

      // Start QR session
      final session = manager.startQrAttendanceSession(sessionNumber: 3);
      expect(session, isNotNull);

      // Student 1 checks in
      session!.markCheckedIn('annv@fpt.edu.vn');

      // Finish session
      manager.finishQrAttendance();
      expect(manager.isQrAttendanceLocked, true);
      expect(manager.isSessionCompleted, true);

      // Attempting to start normal QR session should be blocked
      final blockedSession = manager.startQrAttendanceSession(sessionNumber: 3);
      expect(blockedSession, isNull);

      // Reopening QR should be permitted
      final reopenedSession = manager.reopenQrAttendanceSession(sessionNumber: 3);
      expect(reopenedSession, isNotNull);
      expect(manager.isReopenedQr, true);
    });

    test('2. Manual Override works when QR is locked', () async {
      final mockApi = MockTask5ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      // Mark session as completed (QR locked)
      manager.startQrAttendanceSession(sessionNumber: 3);
      manager.finishQrAttendance();
      expect(manager.isQrAttendanceLocked, true);

      // Giảng viên hoàn toàn có quyền sửa tay từng sinh viên
      manager.updateAttendanceStatus('SE180101', AttendanceStatus.present);
      manager.updateAttendanceStatus('SE180102', AttendanceStatus.absent);

      final rec1 = manager.records.firstWhere((r) => r.rollNumber == 'SE180101');
      final rec2 = manager.records.firstWhere((r) => r.rollNumber == 'SE180102');

      expect(rec1.status, AttendanceStatus.present);
      expect(rec2.status, AttendanceStatus.absent);

      // Lưu lên Sheet vẫn thành công
      final saveResult = await manager.saveAttendance(bypassDateLock: true);
      expect(saveResult.success, true);
    });

    testWidgets('3. AttendanceView UI shows Locked QR button and opens Reopen dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool reopened = false;
      AttendanceStatus? modifiedStatus;

      final students = [
        Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: 'SE1801', email: 'annv@fpt.edu.vn'),
      ];
      final records = [
        AttendanceRecord(rollNumber: 'SE180101', className: 'SE1801', date: '2026-09-22', slot: 1, status: AttendanceStatus.present),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1600,
              height: 900,
              child: AttendanceView(
                currentClass: 'SE1801',
                availableClasses: const ['SE1801'],
                onClassChanged: (_) {},
                currentDate: DateTime(2026, 9, 22),
                onDateChanged: (_) {},
                currentSlot: 1,
                onSlotChanged: (_) {},
                students: students,
                records: records,
                onStatusChanged: (roll, status) {
                  modifiedStatus = status;
                },
                onNoteChanged: (roll, note) {},
                onMarkAllPresent: () {},
                onMarkAllAbsent: () {},
                onSaveToSheet: () {},
                onReloadFromSheet: () {},
                onGoToFapSync: () {},
                onImportStudents: (_) {},
                isLoading: false,
                isDateLocked: false,
                isQrAttendanceLocked: true,
                isSessionCompleted: true,
                onStartQrAttendance: () => null,
                onReopenQrAttendance: () {
                  reopened = true;
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Check button text is "Đã chốt QR (Khóa)"
      expect(find.text('Đã chốt QR (Khóa)'), findsOneWidget);

      // Click the locked button
      await tester.tap(find.text('Đã chốt QR (Khóa)'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Điểm danh QR đã chốt'), findsOneWidget);
      expect(find.textContaining('Toàn quyền sửa thủ công'), findsOneWidget);

      // Click "Mở lại QR (30s)"
      await tester.tap(find.text('Mở lại QR (30s)'));
      await tester.pumpAndSettle();

      expect(reopened, true);

      // Test Manual Override pill (Change to Absent)
      expect(find.byType(AttendanceStudentRow), findsOneWidget);
      await tester.tap(find.text('Vắng'));
      await tester.pumpAndSettle();

      expect(modifiedStatus, AttendanceStatus.absent);
    });
  });
}
