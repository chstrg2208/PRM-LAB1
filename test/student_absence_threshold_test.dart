import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/widgets/status_badge.dart';

void main() {
  group('BK-07: Student Absence Threshold Business Rules', () {
    test('Rule 1: totalSlots = 20 (3 absences = warning, 4 absences = 20% allowed/threshold, 5 absences = 25% banned)', () {
      final sWarn = Student(
        rollNumber: 'SE170001',
        fullName: 'Nguyễn Văn Cảnh Báo',
        email: 'warn@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 3, // 15%
      );
      expect(sWarn.absentRate, 15.0);
      expect(sWarn.isBanned, false);
      expect(sWarn.isWarning, true);
      expect(sWarn.isAtThreshold, false);
      expect(sWarn.maxAllowedAbsences, 4);
      expect(sWarn.remainingAllowedAbsences, 1);
      expect(sWarn.absenceStatusMessage, 'Còn được phép vắng 1 buổi.');

      final sThreshold = Student(
        rollNumber: 'SE170002',
        fullName: 'Trần Văn Chạm Ngưỡng',
        email: 'thresh@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 4, // 20%
      );
      expect(sThreshold.absentRate, 20.0);
      expect(sThreshold.isBanned, false, reason: '20% vắng vẫn hợp lệ, chưa cấm thi!');
      expect(sThreshold.isWarning, false);
      expect(sThreshold.isAtThreshold, true);
      expect(sThreshold.maxAllowedAbsences, 4);
      expect(sThreshold.remainingAllowedAbsences, 0);
      expect(
        sThreshold.absenceStatusMessage,
        'Đã sử dụng hết số buổi vắng được phép; vắng thêm 1 buổi sẽ vượt ngưỡng và bị cấm thi.',
      );

      final sBanned = Student(
        rollNumber: 'SE170003',
        fullName: 'Lê Văn Cấm Thi',
        email: 'ban@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 5, // 25%
      );
      expect(sBanned.absentRate, 25.0);
      expect(sBanned.isBanned, true);
      expect(sBanned.remainingAllowedAbsences, 0);
      expect(sBanned.absenceStatusMessage, 'Đã vượt ngưỡng vắng 20%; sinh viên thuộc diện cấm thi.');
    });

    test('Rule 2: totalSlots = 25 (4 absences = 16% warning, 5 absences = 20% allowed/threshold, 6 absences = 24% banned)', () {
      final s16 = Student(
        rollNumber: 'SE170010',
        fullName: 'Sinh Viên 16%',
        email: 's16@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 25,
        absentSlots: 4, // 16%
      );
      expect(s16.absentRate, 16.0);
      expect(s16.isBanned, false);
      expect(s16.isWarning, true);
      expect(s16.isAtThreshold, false);
      expect(s16.maxAllowedAbsences, 5);
      expect(s16.remainingAllowedAbsences, 1);
      expect(s16.absenceStatusMessage, 'Còn được phép vắng 1 buổi.');

      final s20 = Student(
        rollNumber: 'SE170011',
        fullName: 'Sinh Viên 20%',
        email: 's20@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 25,
        absentSlots: 5, // 20%
      );
      expect(s20.absentRate, 20.0);
      expect(s20.isBanned, false, reason: '5/25 = 20% chưa bị cấm thi!');
      expect(s20.isAtThreshold, true);
      expect(s20.maxAllowedAbsences, 5);
      expect(s20.remainingAllowedAbsences, 0);
      expect(
        s20.absenceStatusMessage,
        'Đã sử dụng hết số buổi vắng được phép; vắng thêm 1 buổi sẽ vượt ngưỡng và bị cấm thi.',
      );

      final s24 = Student(
        rollNumber: 'SE170012',
        fullName: 'Sinh Viên 24%',
        email: 's24@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 25,
        absentSlots: 6, // 24%
      );
      expect(s24.absentRate, 24.0);
      expect(s24.isBanned, true);
      expect(s24.absenceStatusMessage, 'Đã vượt ngưỡng vắng 20%; sinh viên thuộc diện cấm thi.');
    });

    test('Rule 3: totalSlots = 21 (4 absences = 19.05% threshold, 5 absences = 23.81% banned)', () {
      final s21_4 = Student(
        rollNumber: 'SE170020',
        fullName: 'Sinh Viên 21 Buổi - 4 Vắng',
        email: 's21_4@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 21,
        absentSlots: 4,
      );
      expect(s21_4.isBanned, false);
      expect(s21_4.maxAllowedAbsences, 4);
      expect(s21_4.remainingAllowedAbsences, 0);
      expect(s21_4.isAtThreshold, true);
      expect(
        s21_4.absenceStatusMessage,
        'Đã sử dụng hết số buổi vắng được phép; vắng thêm 1 buổi sẽ vượt ngưỡng và bị cấm thi.',
      );

      final s21_5 = Student(
        rollNumber: 'SE170021',
        fullName: 'Sinh Viên 21 Buổi - 5 Vắng',
        email: 's21_5@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 21,
        absentSlots: 5,
      );
      expect(s21_5.isBanned, true);
      expect(s21_5.absenceStatusMessage, 'Đã vượt ngưỡng vắng 20%; sinh viên thuộc diện cấm thi.');
    });

    test('Rule 4: totalSlots <= 0 (no division by zero, safe defaults, clear message)', () {
      final sZero = Student(
        rollNumber: 'SE170030',
        fullName: 'Sinh Viên Chưa Có Lịch',
        email: 'zero@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 0,
        absentSlots: 0,
      );
      expect(sZero.absentRate, 0.0);
      expect(sZero.isBanned, false);
      expect(sZero.isWarning, false);
      expect(sZero.isAtThreshold, false);
      expect(sZero.maxAllowedAbsences, 0);
      expect(sZero.remainingAllowedAbsences, 0);
      expect(
        sZero.absenceStatusMessage,
        'Chưa có đủ dữ liệu tổng số buổi để xác định ngưỡng vắng.',
      );

      final sNeg = Student(
        rollNumber: 'SE170031',
        fullName: 'Sinh Viên Dữ Liệu Lỗi',
        email: 'neg@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: -5,
        absentSlots: 2,
      );
      expect(sNeg.absentRate, 0.0);
      expect(sNeg.isBanned, false);
      expect(sNeg.isWarning, false);
      expect(sNeg.absenceStatusMessage, 'Chưa có đủ dữ liệu tổng số buổi để xác định ngưỡng vắng.');
    });

    test('Rule 5: Normal attendance (< 15%) has correct message and status', () {
      final sSafe = Student(
        rollNumber: 'SE170040',
        fullName: 'Sinh Viên Chăm Học',
        email: 'safe@fpt.edu.vn',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 1, // 5%
      );
      expect(sSafe.absentRate, 5.0);
      expect(sSafe.isBanned, false);
      expect(sSafe.isWarning, false);
      expect(sSafe.isAtThreshold, false);
      expect(sSafe.remainingAllowedAbsences, 3);
      expect(sSafe.absenceStatusMessage, 'Còn được phép vắng 3 buổi.');
    });
  });

  group('BK-07: AbsentRateBadge UI Tests', () {
    testWidgets('AbsentRateBadge shows CHẠM NGƯỠNG and not CẤM THI for 20.0%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AbsentRateBadge(rate: 20.0, showPercent: true),
          ),
        ),
      );

      expect(find.text('CHẠM NGƯỠNG (20%)'), findsOneWidget);
      expect(find.textContaining('CẤM THI'), findsNothing);
    });

    testWidgets('AbsentRateBadge shows CẤM THI only when rate > 20%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AbsentRateBadge(rate: 20.1, showPercent: true),
          ),
        ),
      );

      expect(find.text('CẤM THI (20%)'), findsOneWidget);
    });

    testWidgets('AbsentRateBadge shows CẢNH BÁO for 15.0%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AbsentRateBadge(rate: 15.0, showPercent: true),
          ),
        ),
      );

      expect(find.text('CẢNH BÁO (15%)'), findsOneWidget);
    });

    testWidgets('AbsentRateBadge shows ĐỦ ĐIỀU KIỆN for < 15.0%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AbsentRateBadge(rate: 10.0, showPercent: true),
          ),
        ),
      );

      expect(find.text('ĐỦ ĐIỀU KIỆN (10%)'), findsOneWidget);
    });
  });
}
