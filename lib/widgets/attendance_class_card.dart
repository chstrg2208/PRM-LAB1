import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_overview_item.dart';
import '../theme/app_theme.dart';

/// ATD-05: Card thông tin tổng quan của một lớp học trên Attendance Hub.
///
/// Hiển thị đầy đủ 7 thông số nghiệp vụ chuẩn FPT:
/// 1. Tên lớp (`className`) & Môn học (`subject` / `subjectCode`)
/// 2. Slot & Khung giờ học (`slot`, `slotTime`)
/// 3. Lịch học định kỳ (`daysOfWeek`)
/// 4. Phòng học (`room`)
/// 5. Tiến độ buổi học (`currentSession` / `totalSessions`, progress bar)
/// 6. Trạng thái buổi học (`sessionStatus`, badge Hôm nay / Đã điểm danh / Buổi X)
/// 7. Thông tin lần học tiếp theo hoặc lần điểm danh gần nhất (`lastSession`, `lastDate`, `nextDate`)
///
/// Hỗ trợ 2 chế độ:
/// - `isToday = true`: Nút "Điểm danh ngay" hoặc "Xem điểm danh"
/// - `isToday = false`: Nút "Xem / Sửa lịch sử" và metadata lần điểm danh gần nhất
class AttendanceClassCard extends StatefulWidget {
  final ClassOverviewItem item;
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback? onActionPressed;

  const AttendanceClassCard({
    super.key,
    required this.item,
    required this.isToday,
    required this.onTap,
    this.onActionPressed,
  });

  @override
  State<AttendanceClassCard> createState() => _AttendanceClassCardState();
}

class _AttendanceClassCardState extends State<AttendanceClassCard> {
  bool _hovered = false;

  void _handleAction() {
    if (widget.onActionPressed != null) {
      widget.onActionPressed!();
    } else {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final Color accentColor = widget.isToday
        ? (item.isAttendanceDone ? BirdleColors.success : BirdleColors.brand)
        : BirdleColors.textSecondary;

    final Color accentLight = widget.isToday
        ? (item.isAttendanceDone ? BirdleColors.successLight : BirdleColors.brandLight)
        : BirdleColors.surfaceSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: BirdleColors.surface,
            borderRadius: BirdleRadius.mdBorder,
            border: Border.all(
              color: _hovered
                  ? accentColor.withValues(alpha: 0.6)
                  : (widget.isToday ? BirdleColors.strongBorder : BirdleColors.border),
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 1. Top row: Tên lớp + Badge trạng thái ──────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.className,
                      style: BirdleTypography.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceClassStatusBadge(
                    item: item,
                    isToday: widget.isToday,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── 2. Môn học ────────────────────────────────────────────────
              Text(
                item.subject.isNotEmpty ? item.subject : item.subjectCode,
                style: BirdleTypography.metadata.copyWith(
                  color: BirdleColors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // ── 3. Slot & Khung giờ ──────────────────────────────────────
              _CardInfoChip(
                icon: Icons.schedule_outlined,
                label: 'Slot ${item.slot} (${item.slotTime})',
              ),
              const SizedBox(height: 8),

              // ── 4. Lịch học & Phòng học ───────────────────────────────────
              Row(
                children: [
                  _CardInfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: item.daysOfWeek,
                  ),
                  const SizedBox(width: 12),
                  _CardInfoChip(
                    icon: Icons.room_outlined,
                    label: item.room,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 5. Tiến độ buổi học ───────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Buổi ${item.currentSession}/${item.totalSessions}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(item.progressRatio * 100).toStringAsFixed(0)}%',
                    style: BirdleTypography.metadata.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BirdleColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.progressRatio,
                  minHeight: 6,
                  backgroundColor: accentLight,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // ── 6 & 7. Metadata phụ + Nút thao tác nghiệp vụ ───────────────
              if (widget.isToday)
                _buildTodayFooter(context, item, accentColor)
              else
                _buildOtherClassFooter(context, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayFooter(BuildContext context, ClassOverviewItem item, Color accentColor) {
    final bool isDone = item.isAttendanceDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 38,
          child: isDone
              ? OutlinedButton.icon(
                  onPressed: _handleAction,
                  icon: const Icon(Icons.visibility_outlined, size: 16, color: BirdleColors.success),
                  label: const Text(
                    'Xem điểm danh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BirdleColors.success,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: BirdleColors.success.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _handleAction,
                  icon: const Icon(Icons.fact_check_outlined, size: 16, color: Colors.white),
                  label: const Text(
                    'Điểm danh ngay',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BirdleColors.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOtherClassFooter(BuildContext context, ClassOverviewItem item) {
    final lastDateStr = item.lastDate != null
        ? DateFormat('dd/MM/yyyy').format(item.lastDate!)
        : '—';
    final nextDateStr = item.nextDate != null
        ? DateFormat('dd/MM/yyyy').format(item.nextDate!)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 13, color: BirdleColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Gần nhất: ${item.lastSession != null && item.lastSession! > 0 ? "Buổi ${item.lastSession}" : "—"} · $lastDateStr',
                style: BirdleTypography.metadata.copyWith(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.arrow_forward_outlined, size: 13, color: BirdleColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Học tiếp: $nextDateStr',
                style: BirdleTypography.metadata.copyWith(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton.icon(
            onPressed: _handleAction,
            icon: const Icon(Icons.history_edu_outlined, size: 15, color: BirdleColors.textSecondary),
            label: const Text(
              'Xem / Sửa lịch sử',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: BirdleColors.textSecondary,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: BirdleColors.border),
              shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
            ),
          ),
        ),
      ],
    );
  }
}

/// Status Badge hiển thị trạng thái của lớp học
class AttendanceClassStatusBadge extends StatelessWidget {
  final ClassOverviewItem item;
  final bool isToday;

  const AttendanceClassStatusBadge({
    super.key,
    required this.item,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;

    if (!isToday) {
      if (item.lastSession != null && item.lastSession! > 0) {
        label = 'Buổi ${item.lastSession}';
        bg = BirdleColors.pendingLight;
        fg = BirdleColors.pending;
      } else {
        label = 'Lớp khác';
        bg = BirdleColors.pendingLight;
        fg = BirdleColors.pending;
      }
    } else if (item.isAttendanceDone) {
      label = '✓ Đã điểm danh';
      bg = BirdleColors.successLight;
      fg = BirdleColors.success;
    } else {
      label = 'Hôm nay';
      bg = BirdleColors.brandLight;
      fg = BirdleColors.brand;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFamily: BirdleTypography.fontFamily,
        ),
      ),
    );
  }
}

/// Chip thông tin icon + label nhỏ gọn trong Card
class _CardInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CardInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.5, color: BirdleColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: BirdleTypography.metadata.copyWith(
              color: BirdleColors.textSecondary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Skeleton Card dùng cho trạng thái Loading Shimmer
class AttendanceClassCardSkeleton extends StatelessWidget {
  const AttendanceClassCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BirdleRadius.mdBorder,
        border: Border.all(color: BirdleColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _placeholderBox(width: 140, height: 18),
              const Spacer(),
              _placeholderBox(width: 70, height: 20, isPill: true),
            ],
          ),
          const SizedBox(height: 10),
          _placeholderBox(width: 200, height: 13),
          const SizedBox(height: 16),
          _placeholderBox(width: 180, height: 14),
          const SizedBox(height: 8),
          Row(
            children: [
              _placeholderBox(width: 70, height: 14),
              const SizedBox(width: 12),
              _placeholderBox(width: 70, height: 14),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _placeholderBox(width: 80, height: 13),
              const Spacer(),
              _placeholderBox(width: 35, height: 13),
            ],
          ),
          const SizedBox(height: 8),
          _placeholderBox(width: double.infinity, height: 6, isPill: true),
          const SizedBox(height: 18),
          _placeholderBox(width: double.infinity, height: 36, isButton: true),
        ],
      ),
    );
  }

  Widget _placeholderBox({
    required double width,
    required double height,
    bool isPill = false,
    bool isButton = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: BirdleColors.surfaceSecondary,
        borderRadius: isPill
            ? BorderRadius.circular(999)
            : (isButton ? BirdleRadius.smBorder : BorderRadius.circular(4)),
      ),
    );
  }
}
