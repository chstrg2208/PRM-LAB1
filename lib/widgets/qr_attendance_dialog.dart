import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/qr_attendance_session.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

/// Modal trình chiếu mã QR động 30s cho sinh viên quét điểm danh trên máy chiếu
class QrAttendanceDialog extends StatefulWidget {
  final QrAttendanceSession session;
  final List<Student> students;
  final FutureOr<void> Function() onFinishAttendance;
  final VoidCallback? onCancelAttendance;
  final Future<void> Function()? onPollStatus;

  const QrAttendanceDialog({
    super.key,
    required this.session,
    required this.students,
    required this.onFinishAttendance,
    this.onCancelAttendance,
    this.onPollStatus,
  });

  @override
  State<QrAttendanceDialog> createState() => _QrAttendanceDialogState();
}

class _QrAttendanceDialogState extends State<QrAttendanceDialog> {
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Đếm ngược 1 giây một lần để cập nhật đồng hồ 30s
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (widget.session.isTokenExpired()) {
          widget.session.refreshToken(30);
        }
      });
    });

    // Polling lấy sinh viên check-in từ Google Sheets mỗi 3 giây
    if (widget.onPollStatus != null) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;
        widget.onPollStatus!().then((_) {
          if (mounted) setState(() {});
        });
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.session.secondsRemaining();
    final progress = widget.session.progressRemaining();
    final totalStudents = widget.students.length;
    final checkedInCount = widget.session.checkedInEmails.length;

    return Dialog(
      backgroundColor: BirdleColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 640,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BirdleColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: BirdleColors.brand, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điểm danh QR Động · Lớp ${widget.session.className}',
                        style: BirdleTypography.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Slot ${widget.session.slot} · Buổi ${widget.session.sessionNumber}/20 · Quét QR trên máy chiếu để xác nhận có mặt',
                        style: BirdleTypography.metadata,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: BirdleColors.textMuted),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onCancelAttendance?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Khung hiển thị QR code lớn cho máy chiếu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.session.qrScanPayload,
                version: QrVersions.auto,
                size: 220.0,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Đồng hồ đếm ngược 30 giây
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: seconds <= 5 ? BirdleColors.danger : BirdleColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mã QR tự đổi sau: ${seconds}s',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: seconds <= 5 ? BirdleColors.danger : BirdleColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: BirdleColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        seconds <= 5 ? BirdleColors.danger : BirdleColors.brand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Thống kê số lượng sinh viên đã check-in
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BirdleColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đã có mặt: $checkedInCount / $totalStudents sinh viên',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    totalStudents > 0
                        ? '${((checkedInCount / totalStudents) * 100).toStringAsFixed(0)}%'
                        : '0%',
                    style: const TextStyle(
                      color: BirdleColors.brand,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            // Danh sách sinh viên đã điểm danh thời gian thực
            if (checkedInCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 70),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BirdleColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.session.checkedInEmails.map((email) {
                      final s = widget.students.cast<Student?>().firstWhere(
                        (st) => st != null && st.email.trim().toLowerCase() == email,
                        orElse: () => null,
                      );
                      final name = s != null ? s.fullName : email;
                      return Chip(
                        avatar: const Icon(Icons.check_circle, size: 14, color: BirdleColors.success),
                        label: Text(name, style: const TextStyle(fontSize: 11, color: BirdleColors.textPrimary)),
                        backgroundColor: BirdleColors.surface,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Nút hành động
            Row(
              children: [
                Expanded(
                  child: BirdleSecondaryButton(
                    label: 'Đóng QR (Giữ nguyên)',
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onCancelAttendance?.call();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BirdlePrimaryButton(
                    icon: Icons.check_circle_outline,
                    label: 'Kết thúc điểm danh',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onFinishAttendance();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ghi chú: Nhấn "Hủy / Đóng QR" để giữ nguyên trạng thái. Nhấn "Kết thúc điểm danh" sẽ tự động đánh Vắng (Absent) các sinh viên chưa quét mã.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
}
