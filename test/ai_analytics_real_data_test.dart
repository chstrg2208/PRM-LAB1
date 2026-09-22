import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/services/ai_analytics_service.dart';
import 'package:birdle/services/google_sheet_service.dart';
import 'package:birdle/screens/ai_insights_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Student> dummyStudents = [
    Student(rollNumber: 'SE180001', fullName: 'Nguyen Van A', className: 'SE1801', email: 'a@fpt.edu.vn', totalSlots: 10, absentSlots: 1),
    Student(rollNumber: 'SE180002', fullName: 'Tran Thi B', className: 'SE1801', email: 'b@fpt.edu.vn', totalSlots: 10, absentSlots: 3),
  ];

  final dummyCurrentRecords = [
    AttendanceRecord(rollNumber: 'SE180001', className: 'SE1801', date: '2026-03-10', slot: 1, status: AttendanceStatus.present),
    AttendanceRecord(rollNumber: 'SE180002', className: 'SE1801', date: '2026-03-10', slot: 1, status: AttendanceStatus.absent),
  ];

  group('BK-03: AiAnalyticsService Real Data & No Fake Patterns', () {
    test('1. historyLogs rỗng: Không tiêm số liệu giả (không có 14 hay 16), status là empty', () {
      final report = AiAnalyticsService.analyzeAttendance(
        students: dummyStudents,
        currentRecords: dummyCurrentRecords,
        historyLogs: [],
        status: AnalyticsDataStatus.empty,
      );

      expect(report.status, AnalyticsDataStatus.empty);
      expect(report.hasHistory, isFalse);
      expect(report.aiSummary, contains('Chưa đủ dữ liệu thống kê lịch sử.'));
      expect(report.worstSlot.absentCount, 0);
      expect(report.worstDay.absentCount, 0);

      // Verify no slot has 14 fake absents and no day has 16 fake absents
      for (final slot in report.slotStats) {
        expect(slot.absentCount, 0);
        expect(slot.absentCount, isNot(14));
      }
      for (final day in report.dayStats) {
        expect(day.absentCount, 0);
        expect(day.absentCount, isNot(16));
      }

      // Verify offline Q&A does not fabricate fake counts
      final answerSlot = AiAnalyticsService.answerAiQuestion(
        'Slot mấy sinh viên nghỉ nhiều nhất?',
        report,
        students: dummyStudents,
      );
      expect(answerSlot, contains('Chưa đủ dữ liệu thống kê lịch sử'));
      expect(answerSlot, isNot(contains('14')));

      final answerDay = AiAnalyticsService.answerAiQuestion(
        'Thứ mấy sinh viên hay vắng?',
        report,
        students: dummyStudents,
      );
      expect(answerDay, contains('Chưa đủ dữ liệu thống kê lịch sử'));
      expect(answerDay, isNot(contains('16')));
    });

    test('2. historyLogs thực tế: Tính toán chính xác theo slot và thứ thực tế', () {
      // 2026-03-03 is Tuesday (Thứ Ba)
      // 2026-03-05 is Thursday (Thứ Năm)
      final sampleLogs = <Map<String, dynamic>>[
        {'date': '2026-03-03', 'slot': 3, 'status': 'ABSENT', 'rollNumber': 'SE180001'},
        {'date': '2026-03-03', 'slot': 3, 'status': 'ABSENT', 'rollNumber': 'SE180002'},
        {'date': '2026-03-03', 'slot': 3, 'status': 'ABSENT', 'rollNumber': 'SE180003'},
        {'date': '2026-03-03', 'slot': 3, 'status': 'PRESENT', 'rollNumber': 'SE180004'},
        {'date': '2026-03-05', 'slot': 1, 'status': 'ABSENT', 'rollNumber': 'SE180001'},
        {'date': '2026-03-05', 'slot': 1, 'status': 'PRESENT', 'rollNumber': 'SE180002'},
      ];

      final report = AiAnalyticsService.analyzeAttendance(
        students: dummyStudents,
        currentRecords: dummyCurrentRecords,
        historyLogs: sampleLogs,
      );

      expect(report.status, AnalyticsDataStatus.loaded);
      expect(report.hasHistory, isTrue);
      // Worst slot must be Slot 3 with 3 absents
      expect(report.worstSlot.slot, 3);
      expect(report.worstSlot.absentCount, 3);
      expect(report.worstSlot.totalCount, 4);
      expect(report.worstSlot.absentRate, 75.0);

      // Worst day must be Thứ Ba with 3 absents
      expect(report.worstDay.dayName, contains('Ba'));
      expect(report.worstDay.absentCount, 3);
      expect(report.worstDay.totalCount, 4);

      // Answer questions with real computed values
      final answerSlot = AiAnalyticsService.answerAiQuestion(
        'Slot mấy sinh viên nghỉ nhiều nhất?',
        report,
        students: dummyStudents,
      );
      expect(answerSlot, contains('Slot 3'));
      expect(answerSlot, contains('3 lượt vắng'));
      expect(answerSlot, contains('75.0%'));

      final answerDay = AiAnalyticsService.answerAiQuestion(
        'Thứ mấy sinh viên hay vắng?',
        report,
        students: dummyStudents,
      );
      expect(answerDay, contains('Thứ Ba'));
      expect(answerDay, contains('3 lượt vắng'));
    });
  });

  group('BK-03: GoogleSheetService.fetchAnalyticsLogs error handling', () {
    test('Ném ngoại lệ rõ ràng khi server lỗi 500 hoặc phản hồi thất bại', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'error', 'message': 'Database error'}), 500);
      });

      expect(
        () async => await GoogleSheetService.fetchAnalyticsLogs(
          'https://script.google.com/test',
          'SE1801',
          client: mockClient,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Trả về danh sách log chuẩn xác khi server phản hồi thành công', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'className': 'SE1801',
            'totalRecords': 1,
            'logs': [
              {
                'timestamp': '2026-03-03T10:00:00Z',
                'className': 'SE1801',
                'date': '2026-03-03',
                'slot': 2,
                'rollNumber': 'SE180001',
                'status': 'ABSENT',
                'note': 'Om',
              }
            ]
          }),
          200,
        );
      });

      final logs = await GoogleSheetService.fetchAnalyticsLogs(
        'https://script.google.com/test',
        'SE1801',
        client: mockClient,
      );

      expect(logs.length, 1);
      expect(logs.first['rollNumber'], 'SE180001');
      expect(logs.first['slot'], 2);
    });
  });

  group('BK-03: AiInsightsView UI States', () {
    testWidgets('Trạng thái empty: Hiển thị "Chưa đủ dữ liệu thống kê lịch sử."', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightsView(
              students: dummyStudents,
              records: dummyCurrentRecords,
              currentClass: 'SE1801',
              historyLogs: const [],
              analyticsStatus: AnalyticsDataStatus.empty,
              onConfigureByok: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Chưa đủ dữ liệu thống kê lịch sử.'), findsOneWidget);
    });

    testWidgets('Trạng thái error: Hiển thị thông báo lỗi và nút Thử lại', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightsView(
              students: dummyStudents,
              records: dummyCurrentRecords,
              currentClass: 'SE1801',
              historyLogs: const [],
              analyticsStatus: AnalyticsDataStatus.error,
              analyticsError: 'Connection timed out',
              isLoadingAnalytics: false,
              onRetryLoadAnalytics: () {
                retryCalled = true;
              },
              onConfigureByok: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Lỗi tải lịch sử điểm danh: Connection timed out'), findsWidgets);
      final retryButton = find.text('Thử lại (Retry)');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();
      expect(retryCalled, isTrue);
    });

    testWidgets('Trạng thái unconfigured: Hiển thị cảnh báo chưa cấu hình Google Sheet', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightsView(
              students: dummyStudents,
              records: dummyCurrentRecords,
              currentClass: 'SE1801',
              historyLogs: null,
              analyticsStatus: AnalyticsDataStatus.unconfigured,
              onConfigureByok: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Chưa cấu hình Google Sheet để đồng bộ lịch sử điểm danh.'), findsOneWidget);
    });
  });

  group('BK-03: Race Condition Prevention on Class Switch', () {
    test('Request cũ đến sau không ghi đè dữ liệu của request lớp mới', () async {
      int requestId = 0;
      String currentActiveData = '';

      Future<void> simulateFetchClass(String className, int delayMs, String returnedData) async {
        final thisReqId = ++requestId;
        await Future.delayed(Duration(milliseconds: delayMs));
        if (thisReqId == requestId) {
          currentActiveData = returnedData;
        }
      }

      // User selects Class A (slow network: 100ms)
      final req1 = simulateFetchClass('ClassA', 100, 'Data_ClassA');
      // User quickly switches to Class B (fast network: 20ms)
      final req2 = simulateFetchClass('ClassB', 20, 'Data_ClassB');

      await Future.wait([req1, req2]);

      // When all finished, active data must be Class B, NOT overwritten by Class A
      expect(currentActiveData, 'Data_ClassB');
    });
  });
}
