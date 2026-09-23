import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/class_schedule.dart';
import 'package:birdle/models/class_session.dart';
import 'package:birdle/models/qr_attendance_session.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/state/attendance_session_manager.dart';

void main() {
  group('FPT 4-Slot & Weekday Pairing (ClassSchedule)', () {
    test('1. parseWeekdays correctly maps FPT weekday pairs', () {
      final monThu = ClassSchedule.parseWeekdays('T2-T5');
      expect(monThu, equals([DateTime.monday, DateTime.thursday]));

      final tueFri = ClassSchedule.parseWeekdays('T3-T6');
      expect(tueFri, equals([DateTime.tuesday, DateTime.friday]));

      final wedSat = ClassSchedule.parseWeekdays('T4-T7');
      expect(wedSat, equals([DateTime.wednesday, DateTime.saturday]));
    });

    test('2. hasClassOnDate checks matching days', () {
      final schedule = ClassSchedule(
        className: 'SE1801',
        subjectCode: 'PRM393',
        slot: 1,
        daysOfWeek: 'T2-T5',
        room: 'BE-302',
        startDate: DateTime(2026, 9, 1),
      );

      // 2026-09-21 is Monday (T2) -> true
      expect(schedule.hasClassOnDate(DateTime(2026, 9, 21)), isTrue);
      // 2026-09-24 is Thursday (T5) -> true
      expect(schedule.hasClassOnDate(DateTime(2026, 9, 24)), isTrue);
      // 2026-09-22 is Tuesday (T3) -> false
      expect(schedule.hasClassOnDate(DateTime(2026, 9, 22)), isFalse);
      // 2026-09-27 is Sunday (CN) -> false
      expect(schedule.hasClassOnDate(DateTime(2026, 9, 27)), isFalse);
    });

    test('3. calculateSessionNumber increments count properly up to 20', () {
      // Start date: Monday 2026-09-07
      final schedule = ClassSchedule(
        className: 'SE1801',
        subjectCode: 'PRM393',
        slot: 1,
        daysOfWeek: 'T2-T5',
        room: 'BE-302',
        startDate: DateTime(2026, 9, 7), // Session 1 (Mon)
        totalSessions: 20,
      );

      // Session 1: 2026-09-07 (Mon)
      expect(schedule.calculateSessionNumber(DateTime(2026, 9, 7)), equals(1));
      // Session 2: 2026-09-10 (Thu)
      expect(schedule.calculateSessionNumber(DateTime(2026, 9, 10)), equals(2));
      // Session 3: 2026-09-14 (Mon)
      expect(schedule.calculateSessionNumber(DateTime(2026, 9, 14)), equals(3));
      // Session 4: 2026-09-17 (Thu)
      expect(schedule.calculateSessionNumber(DateTime(2026, 9, 17)), equals(4));
    });

    test('4. canTakeAttendanceOnDate disallows future sessions and mismatched days', () {
      final schedule = ClassSchedule(
        className: 'SE1801',
        subjectCode: 'PRM393',
        slot: 1,
        daysOfWeek: 'T2-T5',
        room: 'BE-302',
        startDate: DateTime(2026, 9, 1),
      );

      final today = DateTime(2026, 9, 21); // Monday

      // Today (Monday) -> can take attendance
      expect(schedule.canTakeAttendanceOnDate(DateTime(2026, 9, 21), today), isTrue);

      // Future date 2026-09-24 (Thursday) -> cannot take attendance ahead of time
      expect(schedule.canTakeAttendanceOnDate(DateTime(2026, 9, 24), today), isFalse);

      // Tuesday (wrong weekday) -> cannot take attendance
      expect(schedule.canTakeAttendanceOnDate(DateTime(2026, 9, 15), today), isFalse);
    });
  });

  group('FPT 4-Slot Time Standards (ClassSession)', () {
    test('5. Slot times are 135 minutes with FPT breaks', () {
      expect(ClassSession.getSlotTime(1), equals('07:00 - 09:15'));
      expect(ClassSession.getSlotTime(2), equals('09:30 - 11:45'));
      expect(ClassSession.getSlotTime(3), equals('12:30 - 14:45'));
      expect(ClassSession.getSlotTime(4), equals('15:00 - 17:15'));
    });
  });

  group('Dynamic QR Attendance (QrAttendanceSession)', () {
    test('6. Dynamic token and 30s countdown flow', () {
      final session = QrAttendanceSession(
        sessionId: 'SE1801_s1_b1',
        className: 'SE1801',
        slot: 1,
        sessionNumber: 1,
        date: DateTime(2026, 9, 21),
        webAppUrl: 'https://script.google.com/macros/s/TEST/exec',
      );

      final initialToken = session.currentToken;
      expect(initialToken.startsWith('FAP_'), isTrue);
      expect(session.isTokenExpired(), isFalse);
      expect(session.secondsRemaining(), inInclusiveRange(28, 30));
      expect(session.progressRemaining(), inInclusiveRange(0.8, 1.0));

      // Refresh token
      session.refreshToken(30);
      final newToken = session.currentToken;
      expect(newToken.isNotEmpty, isTrue);

      // Check-in tracking
      expect(session.isCheckedIn('annvse170123@fpt.edu.vn'), isFalse);
      session.markCheckedIn('annvse170123@fpt.edu.vn');
      expect(session.isCheckedIn('annvse170123@fpt.edu.vn'), isTrue);
      expect(session.isCheckedIn('ANNVSE170123@FPT.EDU.VN'), isTrue); // Case-insensitive
    });
  });

  group('AttendanceSessionManager QR Flow & Auto-Absent', () {
    test('7. finishQrAttendance marks checked-in students present and others absent', () {
      final student1 = Student(
        member: 'SE170123',
        code: 'SE170123',
        surname: 'Nguyễn',
        middleName: 'Văn',
        givenName: 'An',
        email: 'annvse170123@fpt.edu.vn',
        className: 'SE1801',
      );

      final student2 = Student(
        member: 'SE170456',
        code: 'SE170456',
        surname: 'Trần',
        middleName: 'Thị',
        givenName: 'Bình',
        email: 'binhttse170456@fpt.edu.vn',
        className: 'SE1801',
      );

      final manager = AttendanceSessionManager(
        initialClass: 'SE1801',
        initialSlot: 1,
        initialDate: DateTime.now(),
      );

      // Set students and records
      manager.importStudents([student1, student2]);

      // Start QR session
      final qrSession = manager.startQrAttendanceSession(sessionNumber: 3, forceReopen: true);
      expect(manager.activeQrSession, isNotNull);

      // Student 1 checks in
      qrSession!.markCheckedIn('annvse170123@fpt.edu.vn');

      // Teacher clicks "Kết thúc điểm danh"
      manager.finishQrAttendance();

      // Verify activeQrSession is closed
      expect(manager.activeQrSession, isNull);

      // Student 1 must be present
      final record1 = manager.records.firstWhere((r) => r.rollNumber == 'SE170123');
      expect(record1.status, equals(AttendanceStatus.present));

      // Student 2 (did not check in) must be automatically marked ABSENT!
      final record2 = manager.records.firstWhere((r) => r.rollNumber == 'SE170456');
      expect(record2.status, equals(AttendanceStatus.absent));
    });
  });
}
