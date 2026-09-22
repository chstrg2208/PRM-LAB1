import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

/// Hộp thoại hiển thị chi tiết ma trận 20 buổi điểm danh của sinh viên
class StudentSlotsDialog extends StatelessWidget {
  final Student student;

  const StudentSlotsDialog({super.key, required this.student});

  static void show(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) => StudentSlotsDialog(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Đếm số buổi có mặt từ slots20
    int presentCount = 0;
    int lateCount = 0;
    for (final s in student.slots20) {
      final code = s.trim().toUpperCase();
      if (code == 'P' || code == 'CÓ MẶT' || code == 'PRESENT') {
        presentCount++;
      } else if (code == 'L' || code == 'MUỘN' || code == 'LATE') {
        lateCount++;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BirdleColors.brandLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: BirdleColors.brand, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết 20 Buổi học - ${student.fullName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: BirdleColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MSSV: ${student.rollNumber} · ${student.email}',
                        style: const TextStyle(fontSize: 12.5, color: BirdleColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: BirdleColors.textMuted),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Summary Metrics Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BirdleColors.border),
              ),
              child: Row(
                children: [
                  _buildMetricItem('Tổng số slot', '${student.totalSlots}', BirdleColors.textPrimary),
                  Container(width: 1, height: 28, color: BirdleColors.border),
                  _buildMetricItem('Đã có mặt', '$presentCount', BirdleColors.success),
                  Container(width: 1, height: 28, color: BirdleColors.border),
                  _buildMetricItem('Đi muộn', '$lateCount', BirdleColors.warning),
                  Container(width: 1, height: 28, color: BirdleColors.border),
                  _buildMetricItem('Số buổi vắng', '${student.absentSlots}', BirdleColors.danger),
                  Container(width: 1, height: 28, color: BirdleColors.border),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quy chế đào tạo', style: TextStyle(fontSize: 11, color: BirdleColors.textMuted)),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AbsentRateBadge(
                              rate: student.absentRate,
                              student: student,
                              showPercent: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 20-Slot Grid (4 rows x 5 columns)
            const Text(
              'Tiến trình điểm danh từng buổi học (B1 -> B20):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BirdleColors.textPrimary),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(20, (index) {
                final slotNum = index + 1;
                final statusRaw = index < student.slots20.length ? student.slots20[index].trim().toUpperCase() : '';
                return _buildSlotChip(slotNum, statusRaw);
              }),
            ),
            const SizedBox(height: 20),

            // Legend Footer
            Row(
              children: [
                _buildLegendItem(BirdleColors.success, 'Có mặt (P)'),
                const SizedBox(width: 14),
                _buildLegendItem(BirdleColors.danger, 'Vắng (A)'),
                const SizedBox(width: 14),
                _buildLegendItem(BirdleColors.warning, 'Muộn (L)'),
                const SizedBox(width: 14),
                _buildLegendItem(BirdleColors.textMuted.withValues(alpha: 0.5), 'Chưa học (-)'),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BirdleColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: BirdleColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildSlotChip(int slotNum, String rawStatus) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFCBD5E1);
    Color text = const Color(0xFF64748B);
    IconData icon = Icons.remove;
    String statusText = '-';

    if (rawStatus == 'P' || rawStatus == 'CÓ MẶT' || rawStatus == 'PRESENT') {
      bg = BirdleColors.successLight;
      border = BirdleColors.success.withValues(alpha: 0.4);
      text = BirdleColors.success;
      icon = Icons.check_circle_rounded;
      statusText = 'Có mặt';
    } else if (rawStatus == 'A' || rawStatus == 'VẮNG' || rawStatus == 'ABSENT') {
      bg = BirdleColors.dangerLight;
      border = BirdleColors.danger.withValues(alpha: 0.4);
      text = BirdleColors.danger;
      icon = Icons.cancel_rounded;
      statusText = 'Vắng';
    } else if (rawStatus == 'L' || rawStatus == 'MUỘN' || rawStatus == 'LATE') {
      bg = BirdleColors.warningLight;
      border = BirdleColors.warning.withValues(alpha: 0.4);
      text = BirdleColors.warning;
      icon = Icons.access_time_filled_rounded;
      statusText = 'Muộn';
    }

    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buổi $slotNum',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                ),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 9.5, color: text.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: BirdleColors.textSecondary)),
      ],
    );
  }
}
