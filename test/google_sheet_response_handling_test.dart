import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:birdle/services/google_sheet_service.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/screens/students_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUrl = 'https://script.google.com/macros/s/AKfycbz_test/exec';
  const testClass = 'SE1801';

  group('BK-06: GoogleSheetService Contract & Response Parsing', () {
    test('1. URL chưa cấu hình: Không gửi HTTP request, ném unconfigured exception', () async {
      var requestSent = false;
      final client = MockClient((request) async {
        requestSent = true;
        return http.Response('{}', 200);
      });

      expect(
        () => GoogleSheetService.fetchStudents('', testClass, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.unconfigured,
        )),
      );

      expect(requestSent, isFalse, reason: 'Không được gửi HTTP request khi URL rỗng');

      // fetchAttendance cũng phải ném unconfigured
      expect(
        () => GoogleSheetService.fetchAttendance('', testClass, '2026-03-20', 1, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.unconfigured,
        )),
      );
      expect(requestSent, isFalse);

      // testConnection trả về success: false
      final testRes = await GoogleSheetService.testConnection('', client: client);
      expect(testRes['success'], isFalse);
      expect(requestSent, isFalse);
    });

    test('2. HTTP 500: Ném lỗi có ngữ cảnh máy chủ, không fallback sang mock data', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      expect(
        () => GoogleSheetService.fetchStudents(testUrl, testClass, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.httpError,
        ).having(
          (e) => e.statusCode,
          'statusCode',
          500,
        ).having(
          (e) => e.message,
          'message',
          contains('500'),
        )),
      );

      // saveAttendance cũng phải trả về false khi HTTP 500
      final saveRes = await GoogleSheetService.saveAttendance(
        webAppUrl: testUrl,
        className: testClass,
        date: '2026-03-20',
        slot: 1,
        records: [],
        client: client,
      );
      expect(saveRes['success'], isFalse);
      expect(saveRes['message'], contains('500'));
    });

    test('3. HTTP 200 nhưng body không phải JSON: Xử lý invalidJson, không trả danh sách rỗng giả', () async {
      final client = MockClient((request) async {
        return http.Response('<html><body>Unexpected HTML Gateway Response</body></html>', 200);
      });

      expect(
        () => GoogleSheetService.fetchStudents(testUrl, testClass, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.invalidJson,
        ).having(
          (e) => e.message,
          'message',
          contains('JSON'),
        )),
      );

      expect(
        () => GoogleSheetService.fetchAttendance(testUrl, testClass, '2026-03-20', 1, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.invalidJson,
        )),
      );
    });

    test('4. HTTP 200, JSON có {"success": false, "error": "Invalid class name"}: Trả lỗi API chính xác', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Invalid class name'}),
          200,
        );
      });

      expect(
        () => GoogleSheetService.fetchStudents(testUrl, testClass, client: client),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.apiError,
        ).having(
          (e) => e.message,
          'message',
          'Invalid class name',
        )),
      );

      // Kiểm tra dạng status: error
      final clientErrorStatus = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'status': 'error', 'message': 'Lớp học không tồn tại'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () => GoogleSheetService.fetchStudents(testUrl, testClass, client: clientErrorStatus),
        throwsA(isA<GoogleSheetException>().having(
          (e) => e.type,
          'type',
          GoogleSheetErrorType.apiError,
        ).having(
          (e) => e.message,
          'message',
          'Lớp học không tồn tại',
        )),
      );

      // saveAttendance không được báo thành công giả khi server trả lỗi
      final saveRes = await GoogleSheetService.saveAttendance(
        webAppUrl: testUrl,
        className: testClass,
        date: '2026-03-20',
        slot: 1,
        records: [],
        client: clientErrorStatus,
      );
      expect(saveRes['success'], isFalse);
      expect(saveRes['message'], contains('Lớp học không tồn tại'));
    });

    test('5. HTTP 200, JSON thành công nhưng data: []: Trả về empty state hợp lệ', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'success', 'data': []}),
          200,
        );
      });

      final students = await GoogleSheetService.fetchStudents(testUrl, testClass, client: client);
      expect(students, isEmpty, reason: 'data: [] hợp lệ phải trả về mảng rỗng, không được tiêm mock students');

      final attendance = await GoogleSheetService.fetchAttendance(testUrl, testClass, '2026-03-20', 1, client: client);
      expect(attendance, isEmpty);
    });

    test('6. HTTP 200, JSON hợp lệ có dữ liệu: Parse chính xác sinh viên theo FAP schema', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'status': 'success',
            'className': testClass,
            'total': 2,
            'data': [
              {
                'member': 'CE190585',
                'code': 'CE190585',
                'surname': 'Lâm',
                'middleName': 'Quốc',
                'givenName': 'Minh',
                'email': 'minhlqce190585@fpt.edu.vn',
                'className': testClass,
                'totalSlots': 30,
                'absentSlots': 3,
              },
              {
                'member': 'SE180001',
                'code': 'SE180001',
                'surname': 'Nguyễn',
                'middleName': 'Văn',
                'givenName': 'Bình',
                'email': 'binhnvse180001@fpt.edu.vn',
                'className': testClass,
                'totalSlots': 30,
                'absentSlots': 0,
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final students = await GoogleSheetService.fetchStudents(testUrl, testClass, client: client);
      expect(students.length, 2);
      expect(students[0].member, 'CE190585');
      expect(students[0].fullName, 'Lâm Quốc Minh');
      expect(students[0].absentSlots, 3);
      expect(students[1].member, 'SE180001');
      expect(students[1].fullName, 'Nguyễn Văn Bình');
    });
  });

  group('BK-06: UI Honest States & Retry Regression', () {
    testWidgets('URL chưa cấu hình: AttendanceView hiển thị thông báo cấu hình, không hiện mock data', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: testClass,
              currentSlot: 1,
              currentDate: DateTime(2026, 3, 20),
              isLoading: false,
              isSheetConfigured: false,
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
      expect(find.text('Chưa cấu hình Google Sheet Database'), findsOneWidget);
      expect(find.text('Lâm Quốc Minh'), findsNothing);
    });

    testWidgets('Lỗi HTTP 500: AttendanceView hiển thị error state, không báo tải thành công', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: testClass,
              currentSlot: 1,
              currentDate: DateTime(2026, 3, 20),
              isLoading: false,
              isSheetConfigured: true,
              errorMessage: 'Lỗi máy chủ Google Apps Script: HTTP 500',
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
      expect(find.text('Không thể tải dữ liệu lớp $testClass'), findsOneWidget);
      expect(find.textContaining('HTTP 500'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Lâm Quốc Minh'), findsNothing);
    });

    testWidgets('7. Regression: Thao tác retry gọi callback đúng một lần, không tạo vòng lặp', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var retryCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: testClass,
              currentSlot: 1,
              currentDate: DateTime(2026, 3, 20),
              isLoading: false,
              isSheetConfigured: true,
              errorMessage: 'Không thể kết nối đến Google Sheet. Vui lòng kiểm tra lại mạng internet.',
              onClassChanged: (_) {},
              onSlotChanged: (_) {},
              onDateChanged: (_) {},
              onStatusChanged: (_, _) {},
              onNoteChanged: (_, _) {},
              onMarkAllPresent: () {},
              onMarkAllAbsent: () {},
              onSaveToSheet: () {},
              onReloadFromSheet: () {
                retryCount++;
              },
              onGoToFapSync: () {},
              onImportStudents: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      final retryButton = find.widgetWithText(ElevatedButton, 'Thử lại');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(retryCount, 1, reason: 'Retry chỉ được gọi đúng 1 lần khi người dùng bấm nút');
    });

    testWidgets('Tải thành công data: []: AttendanceView hiển thị empty state phân biệt với lỗi', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceView(
              students: const [],
              records: const [],
              currentClass: testClass,
              currentSlot: 1,
              currentDate: DateTime(2026, 3, 20),
              isLoading: false,
              isSheetConfigured: true,
              errorMessage: null,
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
      expect(find.text('Lớp chưa có sinh viên'), findsOneWidget);
      expect(find.text('Import từ FAP'), findsOneWidget);
      expect(find.text('Import from FAP'), findsOneWidget);
    });

    testWidgets('StudentsView hiển thị unconfigured và error state đúng chuẩn', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Unconfigured state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentsView(
              students: const [],
              currentClass: testClass,
              isSheetConfigured: false,
              onClassChanged: (_) {},
              onUpdateStudents: (_) {},
              onSyncToSheet: () {},
              onGoToImport: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Chưa cấu hình Google Sheet Database'), findsOneWidget);

      // Error state
      var reloadCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentsView(
              students: const [],
              currentClass: testClass,
              isSheetConfigured: true,
              errorMessage: 'Lỗi phản hồi HTTP: 500',
              onReload: () => reloadCalled = true,
              onClassChanged: (_) {},
              onUpdateStudents: (_) {},
              onSyncToSheet: () {},
              onGoToImport: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Không thể tải danh sách sinh viên lớp $testClass'), findsOneWidget);
      expect(find.text('Lỗi phản hồi HTTP: 500'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Thử lại'));
      await tester.pump();
      expect(reloadCalled, isTrue);
    });
  });
}
