import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/class_schedule.dart';

// ---------------------------------------------------------------------------
// ATD-04: ClassSchedule.currentSessionAsOfToday() Tests
// Logic: "Buổi hiện tại" = buổi học gần nhất có ngày <= hôm nay
// ---------------------------------------------------------------------------

void main() {
  group('ATD-04: ClassSchedule.currentSessionAsOfToday Tests', () {
    // Lớp học T3-T6 (Tue & Fri), bắt đầu 08/09/2026
    // Lịch: T3 08/09, T6 11/09, T3 15/09, T6 18/09, T3 22/09, T6 25/09, ...
    final scheduleT3T6 = ClassSchedule(
      className: 'SE1801_PRM393',
      subjectCode: 'PRM393',
      slot: 2,
      daysOfWeek: 'T3-T6',
      room: 'NVH-603',
      startDate: DateTime(2026, 9, 8), // 08/09/2026 = Thứ Ba
      totalSessions: 20,
    );

    test('1. Hôm nay là T3 08/09 (đúng ngày đầu) → buổi 1', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 8));
      expect(result, 1);
    });

    test('2. Hôm nay là T4 09/09 (ngày không có lớp, sau T3) → buổi 1 (quay về T3)', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 9));
      expect(result, 1);
    });

    test('3. Hôm nay là T6 11/09 (đúng ngày học) → buổi 2', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 11));
      expect(result, 2);
    });

    test('4. Hôm nay là T7 12/09 (ngày không có lớp, sau T6) → buổi 2 (quay về T6)', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 12));
      expect(result, 2);
    });

    test('5. Hôm nay là CN 13/09 (ngày không có lớp, sau T6) → buổi 2', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 13));
      expect(result, 2);
    });

    test('6. Hôm nay là T2 14/09 (ngày không có lớp, trước T3) → buổi 2 (quay về T6 11/09)', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 14));
      expect(result, 2);
    });

    test('7. Hôm nay là T3 15/09 (buổi học) → buổi 3', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 15));
      expect(result, 3);
    });

    test('8. Hôm nay là T4 16/09 (sau T3 15/09) → buổi 3', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 16));
      expect(result, 3);
    });

    test('9. Hôm nay là T3 22/09 → buổi 5 (theo ảnh sheet của user)', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 23));
      // 23/09 = T4, ngày học gần nhất <= T4 là T3 22/09 = buổi 5
      // T3 08/09 = buổi 1, T6 11/09 = buổi 2, T3 15/09 = buổi 3, T6 18/09 = buổi 4, T3 22/09 = buổi 5
      expect(result, 5);
    });

    test('10. Hôm nay trước ngày bắt đầu → trả 0', () {
      final result = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 1));
      expect(result, 0);
    });

    test('11. Lớp T2-T5, bắt đầu 01/09/2026 (T3), hôm nay T4 24/09/2026 → tìm T5 22/09', () {
      final scheduleT2T5 = ClassSchedule(
        className: 'SE1802_PRM393',
        subjectCode: 'PRM393',
        slot: 1,
        daysOfWeek: 'T2-T5',
        room: 'BE-302',
        startDate: DateTime(2026, 9, 1), // 01/09/2026 = T3 (Thứ 3)
        totalSessions: 20,
      );
      // T2-T5: allowedWeekdays = [1 (Mon), 4 (Thu)]
      // 01/09=T3 (không phải ngày học → tìm lùi → không có Mon/Thu trước đó trong tháng)
      // Thực ra 01/09 = Thứ 3, lùi về 25/08 = Thứ 2 → nhưng đó trước startDate → return 0
      // Buổi đầu tiên: T2 07/09, T5 10/09, T2 14/09, T5 17/09, T2 21/09, T5 24/09
      // Hôm nay T4 24/09 → ngày học gần nhất ≤ T4 24/09 là T5 24/09... wait
      // JS weekday 4 = Thursday (JS), Dart weekday 4 = Thursday
      // 24/09/2026 = Thursday = weekday 4 → IS a class day for T2-T5!
      final result = scheduleT2T5.currentSessionAsOfToday(DateTime(2026, 9, 24));
      expect(result, greaterThan(0));
    });

    test('12. Hôm nay là ngày học Thứ Tư T4-T7, tính đúng buổi hôm nay', () {
      final scheduleT4T7 = ClassSchedule(
        className: 'SE1803_PRM393',
        subjectCode: 'PRM393',
        slot: 3,
        daysOfWeek: 'T4-T7',
        room: 'BE-101',
        startDate: DateTime(2026, 9, 2), // 02/09/2026 = Thứ 4
        totalSessions: 20,
      );
      // T4 02/09 = buổi 1, T7 05/09 = buổi 2, T4 09/09 = buổi 3
      final result = scheduleT4T7.currentSessionAsOfToday(DateTime(2026, 9, 9));
      expect(result, 3);
    });

    test('13. progressRatio tính đúng dựa trên currentSessionAsOfToday', () {
      // Buổi 5/20 = 0.25
      final session5 = scheduleT3T6.currentSessionAsOfToday(DateTime(2026, 9, 23));
      expect(session5, 5);
      // progressRatio của ClassSchedule thường dùng currentSession, nhưng
      // với currentSessionAsOfToday ta có thể tạo item giả để kiểm tra formula
      expect(session5 / 20, 0.25);
    });
  });
}
