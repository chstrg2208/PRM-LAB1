import 'dart:math';

/// Phiên điểm danh thời gian thực bằng mã QR động (refresh mỗi 30s)
class QrAttendanceSession {
  final String sessionId;
  final String className;
  final int slot;
  final int sessionNumber;
  final DateTime date;
  final String webAppUrl;

  String currentToken;
  DateTime tokenExpiresAt;
  final Set<String> checkedInEmails;

  QrAttendanceSession({
    required this.sessionId,
    required this.className,
    required this.slot,
    required this.sessionNumber,
    required this.date,
    required this.webAppUrl,
    String? initialToken,
    DateTime? initialExpiresAt,
    Set<String>? initialCheckedInEmails,
  })  : currentToken = initialToken ?? generateRandomToken(),
        tokenExpiresAt = initialExpiresAt ?? DateTime.now().add(const Duration(seconds: 30)),
        checkedInEmails = initialCheckedInEmails ?? <String>{};

  /// Sinh token ngẫu nhiên an toàn cho mã QR
  static String generateRandomToken() {
    final random = Random.secure();
    final values = List<int>.generate(8, (i) => random.nextInt(256));
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'FAP_$hex';
  }

  /// Làm mới token sau mỗi 30 giây
  void refreshToken([int durationSeconds = 30]) {
    currentToken = generateRandomToken();
    tokenExpiresAt = DateTime.now().add(Duration(seconds: durationSeconds));
  }

  /// Kiểm tra xem token hiện tại đã hết hạn 30s chưa
  bool isTokenExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isAfter(tokenExpiresAt);
  }

  /// Số giây còn lại của mã QR hiện tại (0..30)
  int secondsRemaining([DateTime? now]) {
    final current = now ?? DateTime.now();
    final diff = tokenExpiresAt.difference(current).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Tỷ lệ thời gian còn lại (0.0 .. 1.0)
  double progressRemaining([DateTime? now]) {
    final s = secondsRemaining(now);
    return (s / 30.0).clamp(0.0, 1.0);
  }

  /// Đường dẫn đầy đủ để sinh viên truy cập khi quét mã QR
  String get qrScanPayload {
    final base = webAppUrl.trim();
    if (base.isEmpty) {
      return 'https://fap.fpt.edu.vn/checkin?class=$className&slot=$slot&session=$sessionNumber&token=$currentToken';
    }
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}action=checkinForm&class=$className&slot=$slot&session=$sessionNumber&token=$currentToken';
  }

  /// Đánh dấu một email đã quét điểm danh thành công
  bool markCheckedIn(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isNotEmpty) {
      return checkedInEmails.add(clean);
    }
    return false;
  }

  /// Kiểm tra xem một email đã điểm danh hay chưa
  bool isCheckedIn(String email) {
    return checkedInEmails.contains(email.trim().toLowerCase());
  }
}
