class ClassSession {
  final String courseCode;
  final String courseName;
  final String className;
  final String room;
  final int slot;
  final DateTime date;
  final String lecturer;

  ClassSession({
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.room,
    required this.slot,
    required this.date,
    required this.lecturer,
  });

  static String getSlotTime(int slot) {
    switch (slot) {
      case 1:
        return '07:00 - 09:15';
      case 2:
        return '09:30 - 11:45';
      case 3:
        return '12:30 - 14:45';
      case 4:
        return '15:00 - 17:15';
      case 5:
        return '17:30 - 19:45';
      case 6:
        return '20:00 - 22:15';
      default:
        return 'Slot $slot';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'className': className,
      'room': room,
      'slot': slot,
      'date': date.toIso8601String(),
      'lecturer': lecturer,
    };
  }

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      courseCode: json['courseCode'] ?? '',
      courseName: json['courseName'] ?? '',
      className: json['className'] ?? '',
      room: json['room'] ?? '',
      slot: int.tryParse(json['slot']?.toString() ?? '1') ?? 1,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      lecturer: json['lecturer'] ?? '',
    );
  }
}
