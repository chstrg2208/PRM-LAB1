import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/services/google_sheet_service.dart';
import 'package:birdle/state/attendance_session_manager.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/screens/students_view.dart';

class MockAttendanceApiClient implements AttendanceApiClient {
  List<String> mockClasses;
  List<Student> mockStudents;
  List<AttendanceRecord> mockAttendance;
  bool shouldThrowClasses;
  String? classesErrorMessage;
  int fetchClassesCalls = 0;
  int fetchStudentsCalls = 0;
  List<String> fetchedStudentClasses = [];
  Duration? delay;

  MockAttendanceApiClient({
    this.mockClasses = const ['IA1801', 'SE1801', 'SE1802'],
    this.mockStudents = const [],
    this.mockAttendance = const [],
    this.shouldThrowClasses = false,
    this.classesErrorMessage,
    this.delay,
  });

  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) async => {'success': true};

  @override
  Future<List<String>> fetchClasses(String sheetUrl) async {
    fetchClassesCalls++;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (shouldThrowClasses) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.apiError,
        message: classesErrorMessage ?? 'Lỗi tải danh sách lớp từ Google Sheet',
      );
    }
    return List.from(mockClasses);
  }

  @override
  Future<List<Student>> fetchStudents(String sheetUrl, String className) async {
    fetchStudentsCalls++;
    fetchedStudentClasses.add(className);
    return mockStudents;
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async =>
      mockAttendance;

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
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchTodayClasses(String sheetUrl, {DateTime? date}) async => [];
}

void main() {
  group('BK-12: GoogleSheetService.fetchClasses Tests', () {
    test('1. Parse response thành công và trả về danh sách lớp chuẩn hóa', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], equals('getClasses'));
        return http.Response(
          jsonEncode({
            'success': true,
            'total': 3,
            'data': ['SE1802', 'IA1801', 'SE1801'],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await GoogleSheetService.fetchClasses(
        'https://script.google.com/macros/s/test/exec',
        client: mockClient,
      );

      expect(result, equals(['IA1801', 'SE1801', 'SE1802']));
    });

    test('2. Ném invalidSchema khi data không phải là List', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': 'invalid_string_not_list',
          }),
          200,
        );
      });

      expect(
        () => GoogleSheetService.fetchClasses(
          'https://script.google.com/macros/s/test/exec',
          client: mockClient,
        ),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.invalidSchema,
        )),
      );
    });

    test('3. Ném apiError khi Google Apps Script trả success = false', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Spreadsheet permission denied',
          }),
          200,
        );
      });

      expect(
        () => GoogleSheetService.fetchClasses(
          'https://script.google.com/macros/s/test/exec',
          client: mockClient,
        ),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.message,
          'message',
          contains('Spreadsheet permission denied'),
        )),
      );
    });

    test('4. Ném unconfigured khi URL rỗng', () async {
      expect(
        () => GoogleSheetService.fetchClasses('   '),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.unconfigured,
        )),
      );
    });
  });

  group('BK-12: AttendanceSessionManager Dynamic Classes State Tests', () {
    test('5. Tải danh sách lớp thành công và giữ nguyên lớp hiện tại nếu còn tồn tại', () async {
      final api = MockAttendanceApiClient(mockClasses: ['SE1801', 'SE1802', 'SE1803']);
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialClass: 'SE1802',
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );

      await manager.loadClasses();

      expect(manager.availableClasses, equals(['SE1801', 'SE1802', 'SE1803']));
      expect(manager.currentClass, equals('SE1802'));
      expect(manager.classesError, isNull);
      expect(manager.isLoadingClasses, isFalse);
    });

    test('6. Tự động fallback sang lớp đầu tiên nếu lớp hiện tại không còn tồn tại', () async {
      final api = MockAttendanceApiClient(mockClasses: ['IA1801', 'IA1802']);
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialClass: 'OLD_CLASS_NOT_EXISTS',
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );

      await manager.loadClasses();

      expect(manager.currentClass, equals('IA1801'));
      expect(manager.availableClasses, equals(['IA1801', 'IA1802']));
      expect(api.fetchedStudentClasses, contains('IA1801'));
    });

    test('7. Danh sách lớp rỗng: đặt currentClass rỗng và không gọi API với tên lớp rỗng', () async {
      final api = MockAttendanceApiClient(mockClasses: []);
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialClass: 'SE1801',
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );

      await manager.loadClasses();

      expect(manager.availableClasses, isEmpty);
      expect(manager.currentClass, equals(''));
      expect(manager.students, isEmpty);
      // Không gọi fetchStudents với tên lớp rỗng
      expect(api.fetchedStudentClasses, isEmpty);
    });

    test('8. Xử lý lỗi: classesError nhận thông báo lỗi, cho phép retry tải lại', () async {
      final api = MockAttendanceApiClient(
        shouldThrowClasses: true,
        classesErrorMessage: 'Mạng bị gián đoạn',
      );
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );

      await manager.loadClasses();

      expect(manager.classesError, contains('Mạng bị gián đoạn'));
      expect(manager.isLoadingClasses, isFalse);

      // Thử lại sau khi khôi phục mạng
      api.shouldThrowClasses = false;
      api.mockClasses = ['SE1801'];
      await manager.loadClasses();

      expect(manager.classesError, isNull);
      expect(manager.availableClasses, equals(['SE1801']));
      expect(manager.currentClass, equals('SE1801'));
    });

    test('9. selectClass từ chối lớp không nằm trong availableClasses', () async {
      final api = MockAttendanceApiClient(mockClasses: ['SE1801', 'SE1802']);
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialClass: 'SE1801',
        initialClasses: ['SE1801', 'SE1802'],
        initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
      );

      await manager.selectClass('HACK_INJECTED_CLASS');

      expect(manager.currentClass, equals('SE1801'));
    });

    test('10. Chống race condition: Bỏ qua response lớp cũ khi đổi URL', () async {
      final api = MockAttendanceApiClient(
        mockClasses: ['OLD_CLASS_A', 'OLD_CLASS_B'],
        delay: const Duration(milliseconds: 100),
      );
      final manager = AttendanceSessionManager(
        apiClient: api,
        initialSheetUrl: 'https://script.google.com/macros/s/first/exec',
      );

      // Bắt đầu request 1 (chậm)
      final future1 = manager.loadClasses();

      // Đổi sang URL mới và gọi request 2
      api.mockClasses = ['NEW_CLASS_X'];
      api.delay = Duration.zero;
      await manager.setSheetUrl('https://script.google.com/macros/s/second/exec');

      await future1;

      // Danh sách lớp phải là của URL mới (NEW_CLASS_X), không bị response cũ ghi đè
      expect(manager.availableClasses, equals(['NEW_CLASS_X']));
      expect(manager.currentClass, equals('NEW_CLASS_X'));
    });
  });

  group('BK-12: Widget Dynamic Class Dropdown Tests', () {
    testWidgets('11. AttendanceView: render dropdown động, không còn danh sách hardcode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selectedClass;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: 'SE1802',
              availableClasses: const ['SE1801', 'SE1802', 'SE1803'],
              currentSlot: 1,
              currentDate: DateTime(2026, 9, 22),
              isLoading: false,
              onClassChanged: (val) => selectedClass = val,
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (_, _) {},
              onNoteChanged: (_, _) {},
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

      await tester.pumpAndSettle();

      // Dropdown hiển thị lớp SE1802
      expect(find.text('Lớp SE1802'), findsOneWidget);

      // Không còn lớp PRM392-Lab hard-code cũ
      expect(find.text('Lớp PRM392-Lab'), findsNothing);

      // Mở dropdown và chọn SE1801
      await tester.tap(find.text('Lớp SE1802'));
      await tester.pumpAndSettle();

      expect(find.text('Lớp SE1801'), findsWidgets);
      await tester.tap(find.text('Lớp SE1801').last);
      await tester.pumpAndSettle();

      expect(selectedClass, equals('SE1801'));
    });

    testWidgets('12. AttendanceView: Hiển thị trạng thái đang tải và rỗng an toàn',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Test loading
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: '',
              availableClasses: const [],
              isLoadingClasses: true,
              currentSlot: 1,
              currentDate: DateTime(2026, 9, 22),
              isLoading: false,
              onClassChanged: (_) {},
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (_, _) {},
              onNoteChanged: (_, _) {},
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
      expect(find.text('Đang tải lớp...'), findsOneWidget);

      // Test empty state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: '',
              availableClasses: const [],
              isLoadingClasses: false,
              currentSlot: 1,
              currentDate: DateTime(2026, 9, 22),
              isLoading: false,
              onClassChanged: (_) {},
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (_, _) {},
              onNoteChanged: (_, _) {},
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

      await tester.pumpAndSettle();
      expect(find.text('Chưa có lớp'), findsOneWidget);
      expect(find.text('Không tìm thấy lớp học'), findsOneWidget);
    });

    testWidgets('13. StudentsView: render dropdown động và empty state khi lỗi tải lớp',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentsView(
              students: const [],
              currentClass: '',
              availableClasses: const [],
              classesError: 'Lỗi máy chủ Google',
              onRetryLoadClasses: () => retried = true,
              onUpdateStudents: (_) {},
              onClassChanged: (_) {},
              onSyncToSheet: () {},
              onGoToImport: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lỗi tải lớp (Thử lại)'), findsOneWidget);
      expect(find.text('Không thể tải danh sách lớp học'), findsOneWidget);

      // Bấm nút thử lại
      await tester.tap(find.text('Lỗi tải lớp (Thử lại)'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
