class Student {
  final String member; // MEMBER (Mã sinh viên, e.g. CE190585, SE170123)
  final String code; // CODE (e.g. Lâm)
  final String surname; // SURNAME (e.g. Quốc)
  final String middleName; // MIDDLE NAME (e.g. Minh)
  final String givenName; // GIVEN NAME
  final String? customFullName;
  final String email;
  final String className;
  final String avatarUrl;
  int totalSlots;
  int absentSlots;

  Student({
    String? member,
    this.code = '',
    this.surname = '',
    this.middleName = '',
    this.givenName = '',
    String? customFullName,
    String? fullName,
    this.email = '',
    this.className = '',
    this.avatarUrl = '',
    this.totalSlots = 20,
    this.absentSlots = 0,
    String? rollNumber,
  })  : member = (member != null && member.isNotEmpty) ? member : (rollNumber ?? ''),
        customFullName = (customFullName != null && customFullName.isNotEmpty) ? customFullName : fullName;

  // Alias rollNumber sang member để tương thích mã nguồn cũ
  String get rollNumber => member;

  // Họ và tên hoàn chỉnh được ghép từ các trường hoặc chuỗi tên tùy chỉnh
  String get fullName {
    if (customFullName != null && customFullName!.trim().isNotEmpty) {
      return customFullName!;
    }
    final parts = [code, surname, middleName, givenName].where((p) => p.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return 'Sinh viên $member';
  }

  double get absentRate => totalSlots > 0 ? (absentSlots / totalSlots) * 100 : 0.0;

  // Cảnh báo chuyên cần (15% - 20%)
  bool get isWarning => absentRate >= 15.0 && absentRate < 20.0;

  // Fail Attendance - Bị cấm thi theo quy chế FPT (>= 20%)
  bool get isBanned => absentRate >= 20.0;

  // Số buổi còn lại được phép vắng trước khi chạm mốc 20% cấm thi
  int get remainingAllowedAbsences {
    final maxAllowed = (totalSlots * 0.2).floor();
    final remaining = maxAllowed - absentSlots;
    return remaining < 0 ? 0 : remaining;
  }

  Map<String, dynamic> toJson() {
    return {
      'member': member,
      'rollNumber': member,
      'code': code,
      'surname': surname,
      'middleName': middleName,
      'givenName': givenName,
      'fullName': fullName,
      'email': email,
      'className': className,
      'avatarUrl': avatarUrl,
      'totalSlots': totalSlots,
      'absentSlots': absentSlots,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    final member = (json['member'] ?? json['MEMBER'] ?? json['rollNumber'] ?? json['RollNumber'] ?? json['id'] ?? '').toString().trim();
    final code = (json['code'] ?? json['CODE'] ?? '').toString().trim();
    final surname = (json['surname'] ?? json['SURNAME'] ?? '').toString().trim();
    final middleName = (json['middleName'] ?? json['MIDDLE NAME'] ?? json['MIDDLE_NAME'] ?? '').toString().trim();
    final givenName = (json['givenName'] ?? json['GIVEN NAME'] ?? json['GIVEN_NAME'] ?? '').toString().trim();
    final name = (json['fullName'] ?? json['FullName'] ?? json['name'] ?? '').toString().trim();

    return Student(
      member: member,
      code: code,
      surname: surname,
      middleName: middleName,
      givenName: givenName,
      customFullName: name.isNotEmpty ? name : null,
      email: (json['email'] ?? json['EMAIL'] ?? json['Email'] ?? '').toString().trim(),
      className: (json['className'] ?? json['ClassName'] ?? json['class'] ?? 'SE1801').toString().trim(),
      avatarUrl: (json['avatarUrl'] ?? json['AvatarUrl'] ?? '').toString().trim(),
      totalSlots: int.tryParse((json['totalSlots'] ?? json['TOTAL SLOTS'] ?? '20').toString()) ?? 20,
      absentSlots: int.tryParse((json['absentSlots'] ?? json['ABSENT'] ?? '0').toString()) ?? 0,
    );
  }

  Student copyWith({
    String? member,
    String? code,
    String? surname,
    String? middleName,
    String? givenName,
    String? customFullName,
    String? email,
    String? className,
    String? avatarUrl,
    int? totalSlots,
    int? absentSlots,
  }) {
    return Student(
      member: member ?? this.member,
      code: code ?? this.code,
      surname: surname ?? this.surname,
      middleName: middleName ?? this.middleName,
      givenName: givenName ?? this.givenName,
      customFullName: customFullName ?? this.customFullName,
      email: email ?? this.email,
      className: className ?? this.className,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalSlots: totalSlots ?? this.totalSlots,
      absentSlots: absentSlots ?? this.absentSlots,
    );
  }
}
