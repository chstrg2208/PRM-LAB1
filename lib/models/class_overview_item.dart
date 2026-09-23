import 'class_session.dart';

/// Trạng thái điểm danh của một buổi học
enum SessionStatus {
  /// Chưa điểm danh (buổi chưa diễn ra hoặc chưa mở)
  notYet,

  /// Đã điểm danh xong
  done,

  /// Đang điểm danh
  inProgress,
}

/// Dữ liệu tổng quan một lớp học — dùng cho màn hình Attendance Overview.
///
/// Được map trực tiếp từ phản hồi `action=getAttendanceOverview` của Google Apps Script.
class ClassOverviewItem {
  /// Tên lớp (ví dụ: SE1801_PRM393)
  final String className;

  /// Tên môn học (ví dụ: Lập trình Mobile)
  final String subject;

  /// Mã môn học (ví dụ: PRM393)
  final String subjectCode;

  /// Số thứ tự slot (1–6)
  final int slot;

  /// Khung giờ học (ví dụ: "07:00 - 09:15")
  final String slotTime;

  /// Lịch học trong tuần (ví dụ: "T2-T5")
  final String daysOfWeek;

  /// Phòng học (ví dụ: "BE-302")
  final String room;

  /// Số buổi hiện tại (1-based, tính từ sheet metadata)
  final int currentSession;

  /// Tổng số buổi học của lớp (mặc định 20)
  final int totalSessions;

  /// Trạng thái điểm danh buổi hiện tại
  final SessionStatus sessionStatus;

  /// Ngày học tiếp theo (nullable nếu lớp đã kết thúc)
  final DateTime? nextDate;

  /// Buổi học gần nhất đã điểm danh (null nếu chưa có)
  final int? lastSession;

  /// Ngày điểm danh gần nhất (null nếu chưa có)
  final DateTime? lastDate;

  /// Trạng thái điểm danh gần nhất ("Present"/"Absent"/"—")
  final String? lastStatus;

  const ClassOverviewItem({
    required this.className,
    required this.subject,
    required this.subjectCode,
    required this.slot,
    required this.slotTime,
    required this.daysOfWeek,
    required this.room,
    required this.currentSession,
    required this.totalSessions,
    required this.sessionStatus,
    this.nextDate,
    this.lastSession,
    this.lastDate,
    this.lastStatus,
  });

  /// Phần trăm tiến độ học (0.0 – 1.0)
  double get progressRatio =>
      totalSessions > 0 ? (currentSession / totalSessions).clamp(0.0, 1.0) : 0.0;

  /// Kiểm tra buổi hiện tại đã điểm danh xong chưa
  bool get isAttendanceDone => sessionStatus == SessionStatus.done;

  /// Parse từ JSON trả về bởi GAS `getAttendanceOverview`
  factory ClassOverviewItem.fromJson(Map<String, dynamic> json) {
    // Parse sessionStatus
    final rawStatus = json['sessionStatus']?.toString().toLowerCase() ?? 'notyet';
    final SessionStatus status;
    if (rawStatus == 'done' || json['isAttendanceDone'] == true) {
      status = SessionStatus.done;
    } else if (rawStatus == 'inprogress') {
      status = SessionStatus.inProgress;
    } else {
      status = SessionStatus.notYet;
    }

    // Parse slot — có thể là int hoặc String
    final slotRaw = json['slot'];
    final slotInt = slotRaw is int ? slotRaw : int.tryParse(slotRaw?.toString() ?? '1') ?? 1;

    // Parse subject / subjectCode (GAS có thể trả về 1 trong 2 key)
    final subject = json['subject']?.toString() ?? json['subjectCode']?.toString() ?? '';
    final subjectCode = json['subjectCode']?.toString() ?? subject;

    return ClassOverviewItem(
      className: json['className']?.toString() ?? '',
      subject: subject,
      subjectCode: subjectCode,
      slot: slotInt,
      slotTime: json['slotTime']?.toString() ?? ClassSession.getSlotTime(slotInt),
      daysOfWeek: json['daysOfWeek']?.toString() ?? json['days']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      currentSession: int.tryParse(json['currentSession']?.toString() ?? '1') ?? 1,
      totalSessions: int.tryParse(json['totalSessions']?.toString() ?? '20') ?? 20,
      sessionStatus: status,
      nextDate: json['nextDate'] != null
          ? DateTime.tryParse(json['nextDate'].toString())
          : null,
      lastSession: json['lastSession'] != null
          ? int.tryParse(json['lastSession'].toString())
          : null,
      lastDate: json['lastDate'] != null
          ? DateTime.tryParse(json['lastDate'].toString())
          : null,
      lastStatus: json['lastStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'subject': subject,
      'subjectCode': subjectCode,
      'slot': slot,
      'slotTime': slotTime,
      'daysOfWeek': daysOfWeek,
      'room': room,
      'currentSession': currentSession,
      'totalSessions': totalSessions,
      'sessionStatus': sessionStatus.name,
      'isAttendanceDone': isAttendanceDone,
      'nextDate': nextDate?.toIso8601String(),
      'lastSession': lastSession,
      'lastDate': lastDate?.toIso8601String(),
      'lastStatus': lastStatus,
    };
  }
}

/// Kết quả tổng quan điểm danh — gồm lớp hôm nay và các lớp khác
class AttendanceOverview {
  final List<ClassOverviewItem> todayClasses;
  final List<ClassOverviewItem> otherClasses;

  const AttendanceOverview({
    this.todayClasses = const [],
    this.otherClasses = const [],
  });

  /// Tất cả lớp học
  List<ClassOverviewItem> get allClasses => [...todayClasses, ...otherClasses];

  /// Không có lớp nào
  bool get isEmpty => todayClasses.isEmpty && otherClasses.isEmpty;

  factory AttendanceOverview.fromJson(Map<String, dynamic> json) {
    List<ClassOverviewItem> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ClassOverviewItem.fromJson)
          .toList();
    }

    return AttendanceOverview(
      todayClasses: parseList(json['todayClasses']),
      otherClasses: parseList(json['otherClasses']),
    );
  }
}
