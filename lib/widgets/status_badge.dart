import 'package:flutter/material.dart';
import '../models/attendance_record.dart';

class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceStatus status;

  const AttendanceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case AttendanceStatus.present:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        icon = Icons.check_circle;
        break;
      case AttendanceStatus.absent:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = Icons.cancel;
        break;
      case AttendanceStatus.late:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.access_time_filled;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class AbsentRateBadge extends StatelessWidget {
  final double rate;

  const AbsentRateBadge({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    if (rate >= 20.0) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      text = 'CẤM THI (${rate.toStringAsFixed(0)}%)';
    } else if (rate >= 15.0) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      text = 'CẢNH BÁO (${rate.toStringAsFixed(0)}%)';
    } else {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      text = 'An toàn (${rate.toStringAsFixed(0)}%)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withAlpha(80), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
