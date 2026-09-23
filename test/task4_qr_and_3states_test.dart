import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/models/qr_attendance_session.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/state/attendance_session_manager.dart';
import 'package:birdle/widgets/attendance_student_row.dart';
import 'package:birdle/widgets/qr_attendance_dialog.dart';

class MockTask4ApiClient implements AttendanceApiClient {
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
}

void main() {
  group('Task 4: QR Attendance & 3-State Logic Unit Tests', () {
    test('1. cancelQrAttendance keeps current state without marking absent', () async {
      final mockApi = MockTask4ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      expect(manager.students.length, 2);
      expect(manager.records.every((r) => r.status == AttendanceStatus.notYet), true);

      // Bắt đầu phiên QR
      final qrSession = manager.startQrAttendanceSession(sessionNumber: 5);
      expect(qrSession, isNotNull);

      // Giả lập 1 sinh viên (An) quét mã thành công
      qrSession!.markCheckedIn('annv@fpt.edu.vn');
      manager.updateAttendanceStatus('SE180101', AttendanceStatus.present);

      // GV nhấn "Hủy / Đóng QR"
      manager.cancelQrAttendance();

      // Kiểm tra: Sinh viên An vẫn là Present, Sinh viên Bình vẫn giữ Not Yet (KHÔNG bị đánh Absent!)
      final anRecord = manager.records.firstWhere((r) => r.rollNumber == 'SE180101');
      final binhRecord = manager.records.firstWhere((r) => r.rollNumber == 'SE180102');

      expect(anRecord.status, AttendanceStatus.present);
      expect(binhRecord.status, AttendanceStatus.notYet);
      expect(manager.activeQrSession, isNull);
    });

    test('2. finishQrAttendance marks checked-in as Present and unchecked as Absent', () async {
      final mockApi = MockTask4ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      final qrSession = manager.startQrAttendanceSession(sessionNumber: 5);
      expect(qrSession, isNotNull);

      // Sinh viên An quét mã QR
      qrSession!.markCheckedIn('annv@fpt.edu.vn');

      // GV nhấn "Kết thúc điểm danh"
      manager.finishQrAttendance();

      // Kiểm tra: An là Present, Bình là Absent
      final anRecord = manager.records.firstWhere((r) => r.rollNumber == 'SE180101');
      final binhRecord = manager.records.firstWhere((r) => r.rollNumber == 'SE180102');

      expect(anRecord.status, AttendanceStatus.present);
      expect(binhRecord.status, AttendanceStatus.absent);
      expect(manager.activeQrSession, isNull);
    });

    testWidgets('3. AttendanceStudentRow only renders 3 states: Chưa, Có mặt, Vắng (NO Muộn)', (tester) async {
      final student = Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: 'SE1801');
      final record = AttendanceRecord(
        rollNumber: 'SE180101',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.notYet,
      );

      AttendanceStatus? updatedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceStudentRow(
              index: 0,
              student: student,
              record: record,
              onStatusChanged: (roll, st) => updatedStatus = st,
              onNoteChanged: (roll, note) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Phải có đúng 2 nút: Có mặt, Vắng (không có Chưa trên row theo yêu cầu mới)
      expect(find.text('Chưa'), findsNothing);
      expect(find.text('Có mặt'), findsOneWidget);
      expect(find.text('Vắng'), findsOneWidget);
      // Tuyệt đối không còn nút Muộn
      expect(find.text('Muộn'), findsNothing);

      // Thử nhấn Có mặt
      await tester.tap(find.text('Có mặt'));
      expect(updatedStatus, AttendanceStatus.present);

      // Thử nhấn Vắng
      await tester.tap(find.text('Vắng'));
      expect(updatedStatus, AttendanceStatus.absent);
    });

    testWidgets('4. QrAttendanceDialog renders Cancel and Finish buttons with callbacks', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = QrAttendanceSession(
        sessionId: 'test_session',
        className: 'SE1801',
        slot: 1,
        sessionNumber: 5,
        date: DateTime(2026, 9, 22),
        webAppUrl: 'https://script.google.com/test',
      );
      final student = Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: 'SE1801', email: 'annv@fpt.edu.vn');

      var finishedCalled = false;
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrAttendanceDialog(
              session: session,
              students: [student],
              onFinishAttendance: () => finishedCalled = true,
              onCancelAttendance: () => cancelCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Đóng QR (Giữ nguyên)'), findsOneWidget);
      expect(find.text('Kết thúc điểm danh'), findsOneWidget);

      // Nhấn Kết thúc điểm danh
      await tester.tap(find.text('Kết thúc điểm danh'));
      await tester.pumpAndSettle();
      expect(finishedCalled, true);
      expect(cancelCalled, false);
    });
  });
}
