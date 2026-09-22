import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';

/// Pill status badge for student attendance status (Present, Absent, Late, Pending)
class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool compact;

  const AttendanceStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (status) {
      case AttendanceStatus.notYet:
        bg = BirdleColors.surfaceSecondary;
        fg = BirdleColors.textMuted;
        border = BirdleColors.border;
        label = 'Chưa điểm danh';
        break;
      case AttendanceStatus.present:
        bg = BirdleColors.successLight;
        fg = BirdleColors.success;
        border = BirdleColors.success.withValues(alpha: 0.2);
        label = 'Có mặt';
        break;
      case AttendanceStatus.absent:
        bg = BirdleColors.dangerLight;
        fg = BirdleColors.danger;
        border = BirdleColors.danger.withValues(alpha: 0.2);
        label = 'Vắng';
        break;
      case AttendanceStatus.late:
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.25);
        label = 'Muộn';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BirdleRadius.pillBorder,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11.5 : 12,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill status badge for absence rates and FPT regulation thresholds
class AbsentRateBadge extends StatelessWidget {
  final double rate;
  final bool showPercent;
  final Student? student;

  const AbsentRateBadge({
    super.key,
    required this.rate,
    this.showPercent = true,
    this.student,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    String text;

    if (student != null) {
      final s = student!;
      if (s.isBanned) {
        bg = BirdleColors.dangerLight;
        fg = BirdleColors.danger;
        border = BirdleColors.danger.withValues(alpha: 0.25);
        text = 'CẤM THI';
      } else if (s.isExactlyAtAbsenceLimit) {
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.3);
        text = 'CHẠM NGƯỠNG';
      } else if (s.hasExhaustedAbsenceAllowance) {
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.3);
        text = 'HẾT LƯỢT VẮNG';
      } else if (s.isWarning) {
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.3);
        text = 'CẢNH BÁO';
      } else {
        bg = BirdleColors.successLight;
        fg = BirdleColors.success;
        border = BirdleColors.success.withValues(alpha: 0.2);
        text = 'ĐỦ ĐIỀU KIỆN';
      }
    } else {
      if (rate > 20.0) {
        bg = BirdleColors.dangerLight;
        fg = BirdleColors.danger;
        border = BirdleColors.danger.withValues(alpha: 0.25);
        text = 'CẤM THI';
      } else if (rate == 20.0) {
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.3);
        text = 'CHẠM NGƯỠNG';
      } else if (rate >= 15.0) {
        bg = BirdleColors.warningLight;
        fg = BirdleColors.warning;
        border = BirdleColors.warning.withValues(alpha: 0.3);
        text = 'CẢNH BÁO';
      } else {
        bg = BirdleColors.successLight;
        fg = BirdleColors.success;
        border = BirdleColors.success.withValues(alpha: 0.2);
        text = 'ĐỦ ĐIỀU KIỆN';
      }
    }

    final displayText = showPercent ? '$text (${rate.toStringAsFixed(0)}%)' : text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BirdleRadius.pillBorder,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            displayText,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection status pill for header or sidebar
class ConnectionStatusChip extends StatelessWidget {
  final String label;
  final bool isConnected;

  const ConnectionStatusChip({
    super.key,
    required this.label,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isConnected ? BirdleColors.brand : BirdleColors.textMuted;
    final bg = isConnected ? BirdleColors.brandLight : BirdleColors.surfaceSecondary;
    final border = isConnected ? BirdleColors.brand.withValues(alpha: 0.2) : BirdleColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BirdleRadius.pillBorder,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
