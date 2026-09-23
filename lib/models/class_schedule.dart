import 'class_session.dart';

/// Mô hình lịch học của một lớp học tại Đại học FPT
class ClassSchedule {
  final String className;
  final String subjectCode;
  final int slot;
  final String daysOfWeek; // 'T2-T5', 'T3-T6', 'T4-T7'
  final String room;
  final DateTime startDate;
  final int currentSession; // Buổi học hiện tại (mặc định 1)
  final int totalSessions; // Mặc định 20 buổi

  const ClassSchedule({
    required this.className,
    required this.subjectCode,
    required this.slot,
    required this.daysOfWeek,
    required this.room,
    required this.startDate,
    this.currentSession = 1,
    this.totalSessions = 20,
  });

  /// Khung giờ học tương ứng của slot
  String get slotTime => ClassSession.getSlotTime(slot);

  /// Chuyển đổi chuỗi cặp ngày học sang danh sách thứ trong tuần (1 = Thứ Hai ... 7 = Chủ Nhật)
  static List<int> parseWeekdays(String daysOfWeek) {
    final clean = daysOfWeek.trim().toUpperCase();
    if (clean.contains('T2') && clean.contains('T5')) {
      return [DateTime.monday, DateTime.thursday]; // 1, 4
    }
    if (clean.contains('T3') && clean.contains('T6')) {
      return [DateTime.tuesday, DateTime.friday]; // 2, 5
    }
    if (clean.contains('T4') && clean.contains('T7')) {
      return [DateTime.wednesday, DateTime.saturday]; // 3, 6
    }
    return [DateTime.monday, DateTime.thursday];
  }

  /// Kiểm tra xem một ngày cụ thể có tiết học của lớp này hay không
  bool hasClassOnDate(DateTime date) {
    final allowedWeekdays = parseWeekdays(daysOfWeek);
    return allowedWeekdays.contains(date.weekday);
  }

  /// Tính số thứ tự buổi học (từ 1 đến 20) tính đến một ngày cụ thể
  int calculateSessionNumber(DateTime targetDate) {
    final cleanTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);

    if (cleanTarget.isBefore(cleanStart)) {
      return 1;
    }

    final weekdays = parseWeekdays(daysOfWeek);
    int count = 0;
    DateTime cursor = cleanStart;

    while (!cursor.isAfter(cleanTarget)) {
      if (weekdays.contains(cursor.weekday)) {
        count++;
        if (count >= totalSessions) {
          return totalSessions;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return count > 0 ? count : 1;
  }

  /// Kiểm tra xem có được phép mở điểm danh vào ngày này hay không
  /// Quy tắc FPT: Chỉ cho phép điểm danh các buổi từ quá khứ đến hôm nay,
  /// không cho phép điểm danh trước cho các ngày học trong tương lai.
  bool canTakeAttendanceOnDate(DateTime attendanceDate, [DateTime? today]) {
    final now = today ?? DateTime.now();
    final cleanToday = DateTime(now.year, now.month, now.day);
    final cleanAttDate = DateTime(attendanceDate.year, attendanceDate.month, attendanceDate.day);

    // Ngày điểm danh không được lớn hơn ngày hiện tại
    if (cleanAttDate.isAfter(cleanToday)) {
      return false;
    }

    // Ngày điểm danh phải đúng thứ trong lịch học
    return hasClassOnDate(cleanAttDate);
  }

  /// ATD-04: Tính "buổi hiện tại" = buổi học gần nhất có ngày <= [today].
  ///
  /// Ví dụ: lớp học T3-T6, hôm nay là T4 (Thứ Tư)
  ///   → Ngày học gần nhất ≤ hôm nay là T3 (Thứ Ba)
  ///   → Đếm số buổi từ [startDate] đến T3 = buổi hiện tại.
  ///
  /// Nếu hôm nay đúng là ngày học thì tính ngay buổi hôm nay.
  /// Trả về 0 nếu lớp chưa bắt đầu.
  int currentSessionAsOfToday([DateTime? today]) {
    final now = today ?? DateTime.now();
    final cleanToday = DateTime(now.year, now.month, now.day);
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);

    if (cleanToday.isBefore(cleanStart)) return 0;

    final weekdays = parseWeekdays(daysOfWeek);

    // Duyệt lùi từ hôm nay về startDate tìm ngày học gần nhất
    DateTime? lastClassDay;
    DateTime cursor = cleanToday;
    while (!cursor.isBefore(cleanStart)) {
      if (weekdays.contains(cursor.weekday)) {
        lastClassDay = cursor;
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (lastClassDay == null) return 0;

    // Đếm số buổi từ startDate đến lastClassDay (inclusive)
    return calculateSessionNumber(lastClassDay);
  }

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'subjectCode': subjectCode,
      'slot': slot,
      'daysOfWeek': daysOfWeek,
      'room': room,
      'startDate': startDate.toIso8601String(),
      'totalSessions': totalSessions,
    };
  }

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    return ClassSchedule(
      className: json['className']?.toString() ?? '',
      subjectCode: json['subjectCode']?.toString() ?? 'PRM393',
      slot: int.tryParse(json['slot']?.toString() ?? '1') ?? 1,
      daysOfWeek: json['daysOfWeek']?.toString() ?? 'T2-T5',
      room: json['room']?.toString() ?? 'BE-302',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime(2026, 9, 1),
      totalSessions: int.tryParse(json['totalSessions']?.toString() ?? '20') ?? 20,
    );
  }
}
