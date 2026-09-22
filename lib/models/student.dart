class Student {
  final String member; // MEMBER: Mã sinh viên (e.g. SE180001, CE190585)
  final String code; // CODE: Mã sinh viên theo FAP (alias của rollNumber / member)
  final String surname; // SURNAME: Họ (e.g. Lâm, Nguyễn, Trần)
  final String middleName; // MIDDLE NAME: Tên đệm (e.g. Quốc, Văn, Thị)
  final String givenName; // GIVEN NAME: Tên gọi (e.g. Minh, An, Bình)
  final String? customFullName;
  final String email;
  final String className;
  final String avatarUrl;
  int totalSlots;
  int absentSlots;

  Student({
    String? member,
    String? code,
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
  })  : member = _resolveMember(member, rollNumber, code),
        code = _resolveCode(code, member, rollNumber),
        customFullName = (customFullName != null && customFullName.trim().isNotEmpty)
            ? customFullName.trim()
            : (fullName != null && fullName.trim().isNotEmpty ? fullName.trim() : null);

  static String _resolveMember(String? member, String? rollNumber, String? code) {
    if (member != null && member.trim().isNotEmpty) return member.trim();
    if (rollNumber != null && rollNumber.trim().isNotEmpty) return rollNumber.trim();
    if (code != null && code.trim().isNotEmpty) return code.trim();
    return '';
  }

  static String _resolveCode(String? code, String? member, String? rollNumber) {
    if (code != null && code.trim().isNotEmpty) return code.trim();
    if (member != null && member.trim().isNotEmpty) return member.trim();
    if (rollNumber != null && rollNumber.trim().isNotEmpty) return rollNumber.trim();
    return '';
  }

  // Alias rollNumber tương đương member và code theo FAP
  String get rollNumber => member.isNotEmpty ? member : code;

  // Họ và tên hoàn chỉnh được ghép đúng thứ tự: surname (Họ) + middleName (Tên đệm) + givenName (Tên gọi)
  // Loại bỏ khoảng trắng thừa và không bao giờ chứa CODE trong họ tên
  String get fullName {
    if (customFullName != null && customFullName!.trim().isNotEmpty) {
      return customFullName!.trim();
    }
    final parts = [surname, middleName, givenName]
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return 'Sinh viên $rollNumber';
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
      'rollNumber': rollNumber,
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
    final rawCode = (json['CODE'] ?? json['code'] ?? '').toString().trim();
    final rawMember = (json['MEMBER'] ?? json['member'] ?? json['rollNumber'] ?? json['RollNumber'] ?? json['id'] ?? '').toString().trim();
    final rollNumber = rawCode.isNotEmpty ? rawCode : rawMember;

    String surname = (json['SURNAME'] ?? json['surname'] ?? json['SUR_NAME'] ?? json['Họ'] ?? json['Ho'] ?? '').toString().trim();
    String middleName = (json['MIDDLE NAME'] ?? json['MIDDLE_NAME'] ?? json['middleName'] ?? json['MIDDLENAME'] ?? json['Tên đệm'] ?? json['Dem'] ?? '').toString().trim();
    String givenName = (json['GIVEN NAME'] ?? json['GIVEN_NAME'] ?? json['givenName'] ?? json['GIVENNAME'] ?? json['FIRST NAME'] ?? json['FIRST_NAME'] ?? json['firstName'] ?? json['Tên'] ?? json['Ten'] ?? '').toString().trim();
    final rawFullName = (json['FULL NAME'] ?? json['FULL_NAME'] ?? json['fullName'] ?? json['FullName'] ?? json['name'] ?? json['Họ và tên'] ?? '').toString().trim();

    // Nếu không có các trường thành phần nhưng có họ tên đầy đủ, phân rã tự nhiên
    if (surname.isEmpty && middleName.isEmpty && givenName.isEmpty && rawFullName.isNotEmpty) {
      final words = rawFullName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 3) {
        surname = words.first;
        givenName = words.last;
        middleName = words.sublist(1, words.length - 1).join(' ');
      } else if (words.length == 2) {
        surname = words[0];
        givenName = words[1];
      } else if (words.length == 1) {
        givenName = words[0];
      }
    }

    return Student(
      member: rollNumber,
      code: rollNumber,
      surname: surname,
      middleName: middleName,
      givenName: givenName,
      customFullName: (surname.isEmpty && middleName.isEmpty && givenName.isEmpty && rawFullName.isNotEmpty) ? rawFullName : null,
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
    String? rollNumber,
  }) {
    return Student(
      member: member ?? rollNumber ?? this.member,
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
