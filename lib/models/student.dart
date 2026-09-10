class Student {
  final String rollNumber;
  final String fullName;
  final String email;
  final String className;
  final String avatarUrl;
  int totalSlots;
  int absentSlots;

  Student({
    required this.rollNumber,
    required this.fullName,
    required this.email,
    required this.className,
    this.avatarUrl = '',
    this.totalSlots = 0,
    this.absentSlots = 0,
  });

  double get absentRate => totalSlots > 0 ? (absentSlots / totalSlots) * 100 : 0.0;

  bool get isWarning => absentRate >= 15.0 && absentRate < 20.0;
  bool get isBanned => absentRate >= 20.0;

  Map<String, dynamic> toJson() {
    return {
      'rollNumber': rollNumber,
      'fullName': fullName,
      'email': email,
      'className': className,
      'avatarUrl': avatarUrl,
      'totalSlots': totalSlots,
      'absentSlots': absentSlots,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      rollNumber: json['rollNumber'] ?? json['RollNumber'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? json['FullName'] ?? json['name'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      className: json['className'] ?? json['ClassName'] ?? json['class'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['AvatarUrl'] ?? '',
      totalSlots: int.tryParse(json['totalSlots']?.toString() ?? '0') ?? 0,
      absentSlots: int.tryParse(json['absentSlots']?.toString() ?? '0') ?? 0,
    );
  }

  Student copyWith({
    String? rollNumber,
    String? fullName,
    String? email,
    String? className,
    String? avatarUrl,
    int? totalSlots,
    int? absentSlots,
  }) {
    return Student(
      rollNumber: rollNumber ?? this.rollNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      className: className ?? this.className,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalSlots: totalSlots ?? this.totalSlots,
      absentSlots: absentSlots ?? this.absentSlots,
    );
  }
}
