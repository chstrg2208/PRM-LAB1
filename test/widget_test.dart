import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/main.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/services/fap_service.dart';
import 'package:birdle/services/ai_analytics_service.dart';

void main() {
  group('Student Model & Chuyên cần Tests', () {
    test('Calculates absent rate correctly - 20% is allowed (not banned)', () {
      final s = Student(
        rollNumber: 'SE170123',
        fullName: 'Nguyễn Văn An',
        email: 'annvse170123@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 4, // 4/20 = 20%
      );

      expect(s.absentRate, 20.0);
      expect(s.isBanned, false);
      expect(s.isExactlyAtAbsenceLimit, true);
      expect(s.hasExhaustedAbsenceAllowance, true);
      expect(s.remainingAllowedAbsences, 0);
    });

    test('Identifies warning threshold (15% - 20%)', () {
      final s = Student(
        rollNumber: 'SE170456',
        fullName: 'Trần Thị Bình',
        email: 'binhttse170456@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 3, // 3/20 = 15%
      );

      expect(s.absentRate, 15.0);
      expect(s.isWarning, true);
      expect(s.isBanned, false);
    });

    test('Supports FAP schema (CODE, SURNAME, MIDDLE NAME, GIVEN NAME)', () {
      final s = Student(
        member: 'CE190585',
        code: 'CE190585',
        surname: 'Lâm',
        middleName: 'Quốc',
        givenName: 'Minh',
        className: 'SE1801',
        totalSlots: 30,
        absentSlots: 7,
      );

      expect(s.member, 'CE190585');
      expect(s.rollNumber, 'CE190585');
      expect(s.code, 'CE190585');
      expect(s.surname, 'Lâm');
      expect(s.middleName, 'Quốc');
      expect(s.givenName, 'Minh');
      expect(s.fullName, 'Lâm Quốc Minh');
      expect(s.isBanned, true); // 7/30 = 23.33% >= 20%
    });
  });

  group('FapService Parsing Tests', () {
    test('Parses roll numbers and names from messy text', () {
      const input = '''
        1. SE170123 - Nguyễn Văn An (Present)
        2. HE160456  Trần Thị Bình
        3. IA150789 Lê Hoàng Cường
      ''';

      final list = FapService.parseStudentList(input, 'SE1801');
      expect(list.length, 3);
      expect(list[0].rollNumber, 'SE170123');
      expect(list[1].rollNumber, 'HE160456');
      expect(list[2].rollNumber, 'IA150789');
    });

    test('Generates auto-fill javascript script', () {
      final records = [
        AttendanceRecord(
          rollNumber: 'SE170123',
          className: 'SE1801',
          date: '2026-09-10',
          slot: 1,
          status: AttendanceStatus.present,
        ),
      ];

      final script = FapService.generateFapFillScript(records);
      expect(script.contains('SE170123'), true);
      expect(script.contains('Present'), true);
    });
  });

  group('AiAnalyticsService Tests', () {
    test('Analyzes absent stats, worst slot, worst day and failing students', () {
      final students = [
        Student(
          member: 'CE190585',
          code: 'CE190585',
          surname: 'Lâm',
          middleName: 'Quốc',
          givenName: 'Minh',
          className: 'SE1801',
          totalSlots: 30,
          absentSlots: 7, // 23.33% >= 20% -> failed
        ),
        Student(
          member: 'SE170123',
          code: 'SE170123',
          surname: 'Nguyễn',
          middleName: 'Văn',
          givenName: 'An',
          className: 'SE1801',
          totalSlots: 30,
          absentSlots: 1, // 3.33% -> normal
        ),
      ];

      final records = [
        AttendanceRecord(
          rollNumber: 'CE190585',
          className: 'SE1801',
          date: '2026-09-14',
          slot: 1,
          status: AttendanceStatus.absent,
        ),
      ];

      final report = AiAnalyticsService.analyzeAttendance(
        students: students,
        currentRecords: records,
      );

      expect(report.failedStudents.length, 1);
      expect(report.failedStudents.first.member, 'CE190585');
      expect(report.worstSlot, isNotNull);
      expect(report.worstDay, isNotNull);

      // Test Q&A responses
      final qSlot = AiAnalyticsService.answerAiQuestion('Slot mấy sinh viên nghỉ nhiều?', report);
      expect(qSlot.contains('Slot'), true);

      final qDay = AiAnalyticsService.answerAiQuestion('Thứ mấy sinh viên nghỉ nhiều?', report);
      expect(qDay.contains('Thứ') || qDay.contains('ngày'), true);

      final qFail = AiAnalyticsService.answerAiQuestion('Thằng nào fail attendance?', report);
      expect(qFail.contains('CE190585') || qFail.contains('Lâm Quốc Minh'), true);

      // Test natural conversational greetings & identity
      final qHello = AiAnalyticsService.answerAiQuestion('xin chào', report);
      expect(qHello.contains('Xin chào'), true);
      expect(qHello.contains('FAP Attendance Assistant'), true);

      final qWho = AiAnalyticsService.answerAiQuestion('Bạn là ai?', report);
      expect(qWho.contains('FAP AI Assistant'), true);

      // Test specific student lookup
      final qStudent = AiAnalyticsService.answerAiQuestion('tình hình CE190585', report, students: students);
      expect(qStudent.contains('Lâm Quốc Minh') || qStudent.contains('CE190585'), true);
      expect(qStudent.contains('CẤM THI'), true);
    });
  });

  group('App Widget Smoke Test', () {
    testWidgets('Renders Birdle Desktop App title', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FapAttendanceDesktopApp());
      await tester.pump();
      expect(find.text('BIRDLE'), findsOneWidget);
    });
  });
}
