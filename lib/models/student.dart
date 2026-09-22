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
  final List<String> slots20;

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
    List<String>? slots20,
  })  : member = _resolveMember(member, rollNumber, code),
        code = _resolveCode(code, member, rollNumber),
        customFullName = (customFullName != null && customFullName.trim().isNotEmpty)
            ? customFullName.trim()
            : (fullName != null && fullName.trim().isNotEmpty ? fullName.trim() : null),
        slots20 = slots20 != null
            ? List.unmodifiable([...slots20, ...List.filled(20 - slots20.length > 0 ? 20 - slots20.length : 0, '')].sublist(0, 20))
            : List.unmodifiable(List.filled(20, ''));

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

  // Cảnh báo chuyên cần (15% <= rate < 20% và còn lượt vắng)
  bool get isWarning =>
      totalSlots > 0 &&
      !isBanned &&
      (absentSlots * 100 >= totalSlots * 15) &&
      remainingAllowedAbsences > 0;

  // Đúng ngưỡng vắng 20%: absentSlots * 100 == totalSlots * 20
  bool get isExactlyAtAbsenceLimit =>
      totalSlots > 0 && absentSlots * 100 == totalSlots * 20;

  // Đã hết lượt vắng được phép nhưng chưa bị cấm thi
  bool get hasExhaustedAbsenceAllowance =>
      totalSlots > 0 && !isBanned && remainingAllowedAbsences == 0;

  // Giữ isAtThreshold alias tới isExactlyAtAbsenceLimit (đúng 20%)
  bool get isAtThreshold => isExactlyAtAbsenceLimit;

  // Fail Attendance - Bị cấm thi theo quy chế FPT (> 20%)
  // Sinh viên được phép vắng đến và bằng 20% tổng số buổi.
  // Chỉ bị cấm thi khi tỷ lệ vắng LỚN HƠN 20%. Không dùng >= 20%.
  bool get isBanned => totalSlots > 0 && (absentSlots * 100 > totalSlots * 20);

  // Số buổi tối đa được phép vắng (đến và bằng 20%)
  int get maxAllowedAbsences => totalSlots > 0 ? totalSlots ~/ 5 : 0;

  // Số buổi còn lại được phép vắng trước khi vượt ngưỡng 20% cấm thi
  int get remainingAllowedAbsences {
    if (totalSlots <= 0) return 0;
    final remaining = maxAllowedAbsences - absentSlots;
    return remaining < 0 ? 0 : remaining;
  }

  // Nhãn trạng thái ngắn cho đào tạo / học vụ
  String get trainingStatusLabel {
    if (totalSlots <= 0) return 'CHƯA ĐỦ DỮ LIỆU';
    if (isBanned) return 'CẤM THI (>20%)';
    if (isExactlyAtAbsenceLimit) return 'CHẠM NGƯỠNG (20%)';
    if (hasExhaustedAbsenceAllowance) return 'HẾT LƯỢT VẮNG';
    if (isWarning) return 'CẢNH BÁO (15-20%)';
    return 'ĐỦ ĐIỀU KIỆN';
  }

  // Thông điệp trạng thái chuyên cần theo quy chế đào tạo
  String get absenceStatusMessage {
    if (totalSlots <= 0) {
      return 'Chưa có đủ dữ liệu tổng số buổi để xác định ngưỡng vắng.';
    }
    if (isBanned) {
      return 'Đã vượt ngưỡng vắng 20%; sinh viên thuộc diện cấm thi.';
    }
    if (remainingAllowedAbsences == 0) {
      return 'Đã sử dụng hết số buổi vắng được phép; vắng thêm 1 buổi sẽ vượt ngưỡng và bị cấm thi.';
    }
    return 'Còn được phép vắng $remainingAllowedAbsences buổi.';
  }

  /// Trạng thái của một buổi cụ thể (1-indexed: 1..20)
  String getSlot20Status(int slotNumber) {
    if (slotNumber < 1 || slotNumber > slots20.length) return '';
    return slots20[slotNumber - 1].trim();
  }

  /// Số buổi đã có mặt theo ma trận 20 slot
  int get attendedSlots20Count {
    return slots20.where((s) {
      final l = s.trim().toLowerCase();
      return l == 'p' || l == 'present' || l == 'cm' || l == 'có mặt';
    }).length;
  }

  /// Số buổi vắng theo ma trận 20 slot
  int get absentSlots20Count {
    return slots20.where((s) {
      final l = s.trim().toLowerCase();
      return l == 'a' || l == 'absent' || l == 'v' || l == 'vắng';
    }).length;
  }

  /// Số buổi chưa điểm danh theo ma trận 20 slot
  int get notYetSlots20Count {
    return slots20.where((s) {
      final l = s.trim().toLowerCase();
      return l.isEmpty || l == '-' || l == 'not yet' || l == 'ny' || l.contains('chưa');
    }).length;
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
      'slots20': slots20,
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

    List<String>? parsedSlots20;
    if (json['slots20'] is List) {
      parsedSlots20 = (json['slots20'] as List).map((e) => e?.toString().trim() ?? '').toList();
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
      slots20: parsedSlots20,
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
    List<String>? slots20,
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
      slots20: slots20 ?? this.slots20,
    );
  }
}
