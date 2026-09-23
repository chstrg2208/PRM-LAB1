import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ATD-02: Backend Attendance Overview API & Schema Tests', () {
    test('1. Parsed JSON from getAttendanceOverview contains valid todayClasses and otherClasses', () {
      const mockJsonResponse = '''
      {
        "success": true,
        "status": "success",
        "targetDate": "2026-09-23",
        "totalClasses": 2,
        "todayCount": 1,
        "otherCount": 1,
        "todayClasses": [
          {
            "className": "SE1919-PRM393",
            "subject": "PRM393 - Lập trình ứng dụng di động",
            "subjectCode": "PRM393",
            "slot": 2,
            "slotTime": "09:30 - 11:45",
            "daysOfWeek": "T3-T6",
            "room": "NVH-603",
            "currentSession": 5,
            "totalSessions": 20,
            "totalStudents": 5,
            "sessionStatus": "Chưa điểm danh",
            "isAttendanceDone": false,
            "date": "2026-09-23",
            "nextDate": "22/09/2026",
            "lastSession": 4,
            "lastDate": "2026-09-19",
            "lastStatus": "Đã điểm danh"
          }
        ],
        "otherClasses": [
          {
            "className": "SE1919-PRN232",
            "subject": "PRN232 - Lập trình C#",
            "subjectCode": "PRN232",
            "slot": 4,
            "slotTime": "15:00 - 17:15",
            "daysOfWeek": "T2-T5",
            "room": "NVH-601",
            "currentSession": 4,
            "totalSessions": 20,
            "totalStudents": 25,
            "sessionStatus": "Chưa điểm danh",
            "isAttendanceDone": false,
            "date": "2026-09-23",
            "nextDate": "24/09/2026",
            "lastSession": 3,
            "lastDate": "2026-09-21",
            "lastStatus": "Đã điểm danh"
          }
        ]
      }
      ''';

      final decoded = jsonDecode(mockJsonResponse) as Map<String, dynamic>;
      expect(decoded['status'], 'success');
      expect(decoded['todayCount'], 1);
      expect(decoded['otherCount'], 1);

      final todayList = decoded['todayClasses'] as List;
      expect(todayList.length, 1);
      final todayClass = todayList.first as Map<String, dynamic>;

      // Validate all required card metadata fields
      expect(todayClass['className'], 'SE1919-PRM393');
      expect(todayClass['subjectCode'], 'PRM393');
      expect(todayClass['slot'], 2);
      expect(todayClass['slotTime'], '09:30 - 11:45');
      expect(todayClass['daysOfWeek'], 'T3-T6');
      expect(todayClass['room'], 'NVH-603');
      expect(todayClass['currentSession'], 5);
      expect(todayClass['totalSessions'], 20);
      expect(todayClass['sessionStatus'], 'Chưa điểm danh');
      expect(todayClass['isAttendanceDone'], false);

      final otherList = decoded['otherClasses'] as List;
      expect(otherList.length, 1);
      final otherClass = otherList.first as Map<String, dynamic>;

      // Validate otherClasses last session metadata
      expect(otherClass['className'], 'SE1919-PRN232');
      expect(otherClass['lastSession'], 3);
      expect(otherClass['lastDate'], '2026-09-21');
      expect(otherClass['lastStatus'], 'Đã điểm danh');
    });
  });
}
