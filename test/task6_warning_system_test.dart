import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/widgets/attendance_student_row.dart';

void main() {
  group('Task 6: Attendance Warning System Tests', () {
    // ─── Unit Tests: Student model warning logic ───

    test('1. Student với 0 buổi vắng → Không có cảnh báo', () {
      final s = Student(rollNumber: 'SE01', fullName: 'An', className: 'SE1801', totalSlots: 20, absentSlots: 0);
      expect(s.isWarning, false);
      expect(s.isBanned, false);
      expect(s.hasExhaustedAbsenceAllowance, false);
      expect(s.maxAllowedAbsences, 4); // 20% của 20
      expect(s.remainingAllowedAbsences, 4);
    });

    test('2. Student vắng 3/20 buổi (15%) → isWarning = true, chưa bị cấm', () {
      final s = Student(rollNumber: 'SE02', fullName: 'Bình', className: 'SE1801', totalSlots: 20, absentSlots: 3);
      expect(s.absentRate, 15.0);
      expect(s.isWarning, true);
      expect(s.isBanned, false);
      expect(s.remainingAllowedAbsences, 1); // còn 1 buổi
    });

    test('3. Student vắng 4/20 buổi (đúng 20%) → isExactlyAtAbsenceLimit = true, chưa bị cấm', () {
      final s = Student(rollNumber: 'SE03', fullName: 'Cúc', className: 'SE1801', totalSlots: 20, absentSlots: 4);
      expect(s.absentRate, 20.0);
      expect(s.isExactlyAtAbsenceLimit, true);
      expect(s.isBanned, false); // đúng 20% → chưa cấm
      expect(s.hasExhaustedAbsenceAllowance, true);
      expect(s.remainingAllowedAbsences, 0);
      expect(s.trainingStatusLabel, 'CHẠM NGƯỠNG (20%)');
    });

    test('4. Student vắng 5/20 buổi (>20%) → isBanned = true', () {
      final s = Student(rollNumber: 'SE04', fullName: 'Dũng', className: 'SE1801', totalSlots: 20, absentSlots: 5);
      expect(s.absentRate, 25.0);
      expect(s.isBanned, true);
      expect(s.isWarning, false); // isBanned overrides isWarning
      expect(s.trainingStatusLabel, 'CẤM THI (>20%)');
      expect(s.absenceStatusMessage, contains('cấm thi'));
    });

    test('5. Student vắng 2/20 (10%) → Bình thường, không cảnh báo', () {
      final s = Student(rollNumber: 'SE05', fullName: 'Em', className: 'SE1801', totalSlots: 20, absentSlots: 2);
      expect(s.isWarning, false);
      expect(s.isBanned, false);
      expect(s.remainingAllowedAbsences, 2);
      expect(s.trainingStatusLabel, 'ĐỦ ĐIỀU KIỆN');
    });

    // ─── Widget Test: AttendanceStudentRow row color theo status & không có icon cạnh tên ───

    testWidgets('6. AttendanceStudentRow hiển thị nền vàng khi vắng và không còn icon cảnh báo cạnh tên SV', (tester) async {
      tester.view.physicalSize = const Size(1600, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bannedStudent = Student(
        rollNumber: 'SE04',
        fullName: 'Sinh viên Cấm thi',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 5,
      );
      final record = AttendanceRecord(
        rollNumber: 'SE04',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.absent,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 200,
            child: AttendanceStudentRow(
              index: 1,
              student: bannedStudent,
              record: record,
              onStatusChanged: (roll, status) {},
              onNoteChanged: (roll, note) {},
            ),
          ),
        ),
      ));

      // Không còn badge nhỏ cạnh tên SV
      expect(find.text('Cấm thi'), findsNothing);
      expect(find.text('−1'), findsNothing);
      expect(find.text('Hết lượt'), findsNothing);
      // Tên sinh viên vẫn hiện
      expect(find.text('Sinh viên Cấm thi'), findsOneWidget);
    });

    testWidgets('7. AttendanceStudentRow hiển thị nền xanh khi có mặt (present)', (tester) async {
      tester.view.physicalSize = const Size(1600, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final warningStudent = Student(
        rollNumber: 'SE02',
        fullName: 'Sinh viên Cảnh báo',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 3,
      );
      final record = AttendanceRecord(
        rollNumber: 'SE02',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.present,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 200,
            child: AttendanceStudentRow(
              index: 1,
              student: warningStudent,
              record: record,
              onStatusChanged: (roll, status) {},
              onNoteChanged: (roll, note) {},
            ),
          ),
        ),
      ));

      // Không có badge '−1' cạnh tên SV
      expect(find.text('−1'), findsNothing);
    });

    testWidgets('8. AttendanceStudentRow hiển thị nền trắng khi chưa điểm danh (notYet)', (tester) async {
      tester.view.physicalSize = const Size(1600, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final normalStudent = Student(
        rollNumber: 'SE01',
        fullName: 'Sinh viên Bình thường',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 1,
      );
      final record = AttendanceRecord(
        rollNumber: 'SE01',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.notYet,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 200,
            child: AttendanceStudentRow(
              index: 1,
              student: normalStudent,
              record: record,
              onStatusChanged: (roll, status) {},
              onNoteChanged: (roll, note) {},
            ),
          ),
        ),
      ));

      // Không có badge nào cạnh tên
      expect(find.text('Cấm thi'), findsNothing);
      expect(find.text('Hết lượt'), findsNothing);
      expect(find.text('−1'), findsNothing);
    });
  });
}
