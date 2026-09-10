enum AttendanceStatus {
  present,
  absent,
  late;

  String get label {
    switch (this) {
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
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  static AttendanceStatus fromString(String? str) {
    if (str == null) return AttendanceStatus.present;
    final lower = str.toLowerCase();
    if (lower.contains('absent') || lower == 'vắng' || lower == 'v') {
      return AttendanceStatus.absent;
    }
    if (lower.contains('late') || lower == 'muộn' || lower == 'm') {
      return AttendanceStatus.late;
    }
    return AttendanceStatus.present;
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
    this.status = AttendanceStatus.present,
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
