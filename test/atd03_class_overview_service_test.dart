import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdle/models/class_overview_item.dart';
import 'package:birdle/services/google_sheet_service.dart';

// ---------------------------------------------------------------------------
// ATD-03: ClassOverviewItem Model & GoogleSheetService.fetchAttendanceOverview
// ---------------------------------------------------------------------------

void main() {
  group('ATD-03: ClassOverviewItem Model Tests', () {
    test('1. fromJson ánh xạ đầy đủ các trường từ GAS response', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'Lập trình Mobile',
        'subjectCode': 'PRM393',
        'slot': 2,
        'slotTime': '09:30 - 11:45',
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 4,
        'totalSessions': 20,
        'sessionStatus': 'notyet',
        'nextDate': '2026-09-25',
        'lastSession': 3,
        'lastDate': '2026-09-22',
        'lastStatus': 'done',
      };

      final item = ClassOverviewItem.fromJson(json);

      expect(item.className, 'SE1801_PRM393');
      expect(item.subject, 'Lập trình Mobile');
      expect(item.subjectCode, 'PRM393');
      expect(item.slot, 2);
      expect(item.slotTime, '09:30 - 11:45');
      expect(item.daysOfWeek, 'T2-T5');
      expect(item.room, 'BE-302');
      expect(item.currentSession, 4);
      expect(item.totalSessions, 20);
      expect(item.sessionStatus, SessionStatus.notYet);
      expect(item.nextDate, DateTime(2026, 9, 25));
      expect(item.lastSession, 3);
      expect(item.lastDate, DateTime(2026, 9, 22));
      expect(item.lastStatus, 'done');
    });

    test('2. sessionStatus: "done" khi isAttendanceDone == true', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': 1,
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 5,
        'totalSessions': 20,
        'isAttendanceDone': true,
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.sessionStatus, SessionStatus.done);
      expect(item.isAttendanceDone, true);
    });

    test('3. sessionStatus: "done" khi sessionStatus field là "done"', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': 3,
        'daysOfWeek': 'T3-T6',
        'room': 'BE-101',
        'currentSession': 2,
        'totalSessions': 20,
        'sessionStatus': 'done',
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.sessionStatus, SessionStatus.done);
    });

    test('4. sessionStatus: "notyet" khi không có trường status', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': 1,
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 1,
        'totalSessions': 20,
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.sessionStatus, SessionStatus.notYet);
      expect(item.isAttendanceDone, false);
    });

    test('5. progressRatio tính đúng phần trăm tiến độ', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': 2,
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 10,
        'totalSessions': 20,
        'sessionStatus': 'notyet',
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.progressRatio, 0.5);
    });

    test('6. slotTime mặc định từ ClassSession.getSlotTime khi không có field', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': 1,
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 1,
        'totalSessions': 20,
        // slotTime bị thiếu → phải fallback sang ClassSession.getSlotTime(1)
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.slotTime, '07:00 - 09:15');
    });

    test('7. slot có thể parse từ String', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'PRM',
        'subjectCode': 'PRM393',
        'slot': '3', // String thay vì int
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 1,
        'totalSessions': 20,
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.slot, 3);
      expect(item.slotTime, '12:30 - 14:45');
    });

    test('8. subject fallback sang subjectCode nếu thiếu', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subjectCode': 'PRM393', // không có 'subject'
        'slot': 2,
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 1,
        'totalSessions': 20,
      };
      final item = ClassOverviewItem.fromJson(json);
      expect(item.subject, 'PRM393');
    });

    test('9. toJson trả về đầy đủ các trường', () {
      final json = {
        'className': 'SE1801_PRM393',
        'subject': 'Lập trình Mobile',
        'subjectCode': 'PRM393',
        'slot': 2,
        'slotTime': '09:30 - 11:45',
        'daysOfWeek': 'T2-T5',
        'room': 'BE-302',
        'currentSession': 4,
        'totalSessions': 20,
        'sessionStatus': 'done',
        'nextDate': '2026-09-25',
        'lastSession': 3,
        'lastDate': '2026-09-22',
        'lastStatus': 'done',
      };
      final item = ClassOverviewItem.fromJson(json);
      final out = item.toJson();

      expect(out['className'], 'SE1801_PRM393');
      expect(out['slot'], 2);
      expect(out['sessionStatus'], 'done');
      expect(out['isAttendanceDone'], true);
      expect(out['currentSession'], 4);
      expect(out['totalSessions'], 20);
    });
  });

  // ---------------------------------------------------------------------------
  group('ATD-03: AttendanceOverview Model Tests', () {
    test('10. fromJson parse todayClasses và otherClasses', () {
      final json = {
        'status': 'success',
        'todayClasses': [
          {
            'className': 'SE1801_PRM393',
            'subject': 'PRM',
            'subjectCode': 'PRM393',
            'slot': 2,
            'daysOfWeek': 'T2-T5',
            'room': 'BE-302',
            'currentSession': 4,
            'totalSessions': 20,
            'sessionStatus': 'notyet',
          }
        ],
        'otherClasses': [
          {
            'className': 'SE1802_PRJ301',
            'subject': 'Project',
            'subjectCode': 'PRJ301',
            'slot': 1,
            'daysOfWeek': 'T3-T6',
            'room': 'BE-101',
            'currentSession': 6,
            'totalSessions': 20,
            'sessionStatus': 'done',
            'lastSession': 5,
            'lastDate': '2026-09-21',
            'lastStatus': 'done',
          }
        ],
      };

      final overview = AttendanceOverview.fromJson(json);

      expect(overview.todayClasses.length, 1);
      expect(overview.otherClasses.length, 1);
      expect(overview.allClasses.length, 2);
      expect(overview.isEmpty, false);
      expect(overview.todayClasses.first.className, 'SE1801_PRM393');
      expect(overview.otherClasses.first.sessionStatus, SessionStatus.done);
      expect(overview.otherClasses.first.lastSession, 5);
    });

    test('11. isEmpty trả về true khi không có lớp nào', () {
      final overview = AttendanceOverview.fromJson({
        'status': 'success',
        'todayClasses': [],
        'otherClasses': [],
      });
      expect(overview.isEmpty, true);
      expect(overview.allClasses, isEmpty);
    });

    test('12. fromJson không crash khi thiếu key todayClasses/otherClasses', () {
      final overview = AttendanceOverview.fromJson({'status': 'success'});
      expect(overview.todayClasses, isEmpty);
      expect(overview.otherClasses, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('ATD-03: GoogleSheetService.fetchAttendanceOverview Tests', () {
    const validUrl = 'https://script.google.com/macros/s/FAKE/exec';

    test('13. Ném unconfigured exception khi URL rỗng', () async {
      await expectLater(
        GoogleSheetService.fetchAttendanceOverview(''),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.type,
            'type',
            GoogleSheetErrorType.unconfigured,
          ),
        ),
      );
    });

    test('14. Ném invalidSchema exception khi URL không phải http/https', () async {
      await expectLater(
        GoogleSheetService.fetchAttendanceOverview('ftp://invalid.url'),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.type,
            'type',
            GoogleSheetErrorType.invalidSchema,
          ),
        ),
      );
    });

    test('15. Trả AttendanceOverview hợp lệ khi GAS trả về JSON đúng', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'getAttendanceOverview');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'todayClasses': [
              {
                'className': 'SE1801_PRM393',
                'subject': 'PRM',
                'subjectCode': 'PRM393',
                'slot': 2,
                'slotTime': '09:30 - 11:45',
                'daysOfWeek': 'T2-T5',
                'room': 'BE-302',
                'currentSession': 4,
                'totalSessions': 20,
                'sessionStatus': 'notyet',
              }
            ],
            'otherClasses': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final overview = await GoogleSheetService.fetchAttendanceOverview(
        validUrl,
        client: mockClient,
      );

      expect(overview.todayClasses.length, 1);
      expect(overview.otherClasses, isEmpty);
      expect(overview.todayClasses.first.className, 'SE1801_PRM393');
      expect(overview.todayClasses.first.slot, 2);
      expect(overview.todayClasses.first.currentSession, 4);
    });

    test('16. Ném apiError khi GAS trả status == "error"', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'error',
            'message': 'Sheet không tồn tại',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        GoogleSheetService.fetchAttendanceOverview(validUrl, client: mockClient),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.type,
            'type',
            GoogleSheetErrorType.apiError,
          ),
        ),
      );
    });

    test('17. Ném httpError khi server trả về HTTP 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      await expectLater(
        GoogleSheetService.fetchAttendanceOverview(validUrl, client: mockClient),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.type,
            'type',
            GoogleSheetErrorType.httpError,
          ),
        ),
      );
    });

    test('18. Ném invalidJson khi body không phải JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html>Error</html>', 200);
      });

      await expectLater(
        GoogleSheetService.fetchAttendanceOverview(validUrl, client: mockClient),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.type,
            'type',
            GoogleSheetErrorType.invalidJson,
          ),
        ),
      );
    });

    test('19. URL đã có query params được giữ nguyên và action được append đúng', () async {
      const urlWithParams = '$validUrl?foo=bar';
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['foo'], 'bar');
        expect(request.url.queryParameters['action'], 'getAttendanceOverview');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'todayClasses': [],
            'otherClasses': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final overview = await GoogleSheetService.fetchAttendanceOverview(
        urlWithParams,
        client: mockClient,
      );
      expect(overview.isEmpty, true);
    });
  });
}
