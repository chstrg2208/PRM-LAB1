import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/state/attendance_session_manager.dart';

class MockTask3ApiClient implements AttendanceApiClient {
  int saveCallCount = 0;

  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) async => {'success': true};

  @override
  Future<List<String>> fetchClasses(String sheetUrl) async => ['SE1801'];

  @override
  Future<List<Student>> fetchStudents(String sheetUrl, String className) async => [
        Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: className),
      ];

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async => [];

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
    return {'success': true, 'message': 'Đã lưu điểm danh thành công'};
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
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String sheetUrl, {DateTime? date}) async => [];

  @override
  Future<AttendanceOverview> fetchAttendanceOverview(String sheetUrl) async => const AttendanceOverview();
}

void main() {
  group('Task 3: Not Yet Status & Date Lock Tests', () {
    test('1. AttendanceStatus.notYet mapping and parsing', () {
      expect(AttendanceStatus.fromString(null), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString(''), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('   '), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('-'), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('notyet'), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('Not yet'), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('chưa điểm danh'), AttendanceStatus.notYet);
      expect(AttendanceStatus.fromString('P'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('A'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromString('L'), AttendanceStatus.late);

      expect(AttendanceStatus.notYet.label, 'Chưa điểm danh');
      expect(AttendanceStatus.notYet.fapValue, 'Not yet');
    });

    test('2. AttendanceSessionManager isSessionDateLocked logic', () {
      final now = DateTime.now();

      // Ngày tương lai (ngày mai) -> Phải bị khóa
      final futureDate = now.add(const Duration(days: 1));
      final managerFuture = AttendanceSessionManager(
        apiClient: MockTask3ApiClient(),
        initialDate: futureDate,
      );
      expect(managerFuture.isSessionDateLocked, isTrue);

      // Ngày hôm nay -> Không bị khóa
      final managerToday = AttendanceSessionManager(
        apiClient: MockTask3ApiClient(),
        initialDate: now,
      );
      expect(managerToday.isSessionDateLocked, isFalse);

      // Ngày trong quá khứ (hôm qua) -> Không bị khóa
      final pastDate = now.subtract(const Duration(days: 1));
      final managerPast = AttendanceSessionManager(
        apiClient: MockTask3ApiClient(),
        initialDate: pastDate,
      );
      expect(managerPast.isSessionDateLocked, isFalse);
    });

    test('3. Date Lock blocks saveAttendance and startQrAttendanceSession', () async {
      final mockApi = MockTask3ApiClient();
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 2));

      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialDate: futureDate,
      );
      await manager.initialize(loadStorage: false);

      // 3.1 Cố gắng lưu buổi học tương lai -> Bị chặn, không gọi API backend
      final saveRes = await manager.saveAttendance();
      expect(saveRes.success, isFalse);
      expect(saveRes.message.contains('chưa diễn ra'), isTrue);
      expect(mockApi.saveCallCount, 0);

      // 3.2 Cố gắng mở QR buổi học tương lai -> Bị chặn, trả về null
      final qrSession = manager.startQrAttendanceSession();
      expect(qrSession, isNull);
      expect(manager.activeQrSession, isNull);

      // 3.3 Cho phép ghi đè (bypassDateLock: true) cho trường hợp kiểm thử / admin
      final bypassRes = await manager.saveAttendance(bypassDateLock: true);
      expect(bypassRes.success, isTrue);
      expect(mockApi.saveCallCount, 1);
    });

    test('4. loadStudentsAndAttendance initializes empty slot as AttendanceStatus.notYet', () async {
      final mockApi = MockTask3ApiClient();
      final manager = AttendanceSessionManager(
        apiClient: mockApi,
        initialSheetUrl: 'https://script.google.com/test',
        initialClass: 'SE1801',
      );
      await manager.initialize(loadStorage: false);

      expect(manager.students.length, 1);
      expect(manager.records.length, 1);
      // Khi slot chưa điểm danh trên sheet, trạng thái khởi tạo PHẢI là notYet, không tự ý gán present hay absent!
      expect(manager.records.first.status, AttendanceStatus.notYet);
    });

    testWidgets('5. AttendanceView displays Date Lock Banner and Not Yet filter chips', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final student = Student(rollNumber: 'SE180101', fullName: 'Nguyễn Văn An', className: 'SE1801');
      final record = AttendanceRecord(
        rollNumber: 'SE180101',
        className: 'SE1801',
        date: '2026-09-25',
        slot: 1,
        status: AttendanceStatus.notYet,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1600,
              height: 900,
              child: AttendanceView(
                students: [student],
                records: [record],
                currentClass: 'SE1801',
                currentSlot: 1,
                currentDate: DateTime(2026, 9, 25), // Ngày tương lai
                isDateLocked: true,
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
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra Banner Date Lock hiển thị
      expect(find.text('Buổi học bị khóa ngày (Date Lock)'), findsOneWidget);
      expect(find.textContaining('Hệ thống chỉ cho phép điểm danh sau 00:00'), findsOneWidget);

      // Kiểm tra filter badge Not yet hiển thị đúng số lượng
      expect(find.text('1 Not yet'), findsOneWidget);
      expect(find.text('0 Present'), findsOneWidget);
      expect(find.text('0 Absent'), findsOneWidget);

      // Thử nhấn nút "Save to Sheet" khi bị khóa -> Hiển thị cảnh báo SnackBar
      await tester.ensureVisible(find.text('Save to Sheet'));
      await tester.tap(find.text('Save to Sheet'));
      await tester.pump();
      expect(find.textContaining('chưa diễn ra! Chỉ mở sau 00:00 ngày học.'), findsOneWidget);
    });
  });
}
