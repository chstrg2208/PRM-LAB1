enum AttendanceStatus {
  notYet,
  present,
  absent,
  late;

  String get label {
    switch (this) {
      case AttendanceStatus.notYet:
        return 'Chưa điểm danh';
      case AttendanceStatus.present:
        return 'Có mặt';
      case AttendanceStatus.absent:
        return 'Vắng';
      case AttendanceStatus.late:
        return 'Muộn';
    }
  }

  String get fapValue {
    switch (this) {
      case AttendanceStatus.notYet:
        return 'Not yet';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  static AttendanceStatus fromString(String? str) {
    if (str == null) return AttendanceStatus.notYet;
    final trimmed = str.trim();
    if (trimmed.isEmpty || trimmed == '-' || trimmed == '""') {
      return AttendanceStatus.notYet;
    }
    final lower = trimmed.toLowerCase();
    if (lower == 'not yet' || lower == 'notyet' || lower.contains('chưa') || lower == 'ny') {
      return AttendanceStatus.notYet;
    }
    if (lower.contains('absent') || lower == 'vắng' || lower == 'v' || lower == 'a') {
      return AttendanceStatus.absent;
    }
    if (lower.contains('late') || lower == 'muộn' || lower == 'm' || lower == 'l') {
      return AttendanceStatus.late;
    }
    if (lower.contains('present') || lower == 'có mặt' || lower == 'cm' || lower == 'p') {
      return AttendanceStatus.present;
    }
    return AttendanceStatus.notYet;
  }
}

class AttendanceRecord {
  final String rollNumber;
  final String className;
  final String date;
  final int slot;
  AttendanceStatus status;
  String note;

  AttendanceRecord({
    required this.rollNumber,
    required this.className,
    required this.date,
    required this.slot,
    this.status = AttendanceStatus.notYet,
    this.note = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'rollNumber': rollNumber,
      'className': className,
      'date': date,
      'slot': slot,
      'status': status.name,
      'note': note,
    };
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      rollNumber: json['rollNumber'] ?? json['RollNumber'] ?? '',
      className: json['className'] ?? json['ClassName'] ?? '',
      date: json['date'] ?? json['Date'] ?? '',
      slot: int.tryParse(json['slot']?.toString() ?? '1') ?? 1,
      status: AttendanceStatus.fromString(json['status']?.toString()),
      note: json['note'] ?? json['Note'] ?? '',
    );
  }
}
