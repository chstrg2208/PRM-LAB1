import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/main.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/services/fap_service.dart';

void main() {
  group('Student Model & Chuyên cần Tests', () {
    test('Calculates absent rate correctly', () {
      final s = Student(
        rollNumber: 'SE170123',
        fullName: 'Nguyễn Văn An',
        email: 'annvse170123@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 4, // 4/20 = 20%
      );

      expect(s.absentRate, 20.0);
      expect(s.isBanned, true);
      expect(s.isWarning, false);
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

  group('App Widget Smoke Test', () {
    testWidgets('Renders FAP Desktop App title', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FapAttendanceDesktopApp());
      await tester.pump();
      expect(find.text('FAP Assistant'), findsOneWidget);
    });
  });
}
