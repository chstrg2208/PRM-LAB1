import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

/// Task 8: Matrix View — Bảng tổng quan 20 buổi của cả lớp
/// Hàng = sinh viên, Cột = buổi B1..B20, Ô màu = trạng thái
class AttendanceMatrixView extends StatefulWidget {
  final List<Student> students;
  final int currentSessionNumber; // buổi đang điểm danh (highlight cột)
  final String currentClass;

  const AttendanceMatrixView({
    super.key,
    required this.students,
    required this.currentSessionNumber,
    required this.currentClass,
  });

  @override
  State<AttendanceMatrixView> createState() => _AttendanceMatrixViewState();
}

class _AttendanceMatrixViewState extends State<AttendanceMatrixView> {
  String _matrixFilter = 'ALL'; // ALL, WARNING, BANNED

  static const double _cellSize = 22.0;
  static const double _cellGap = 2.0;
  static const double _rowHeight = 44.0;
  static const double _nameColWidth = 220.0;
  static const double _rateColWidth = 140.0;

  List<Student> get _filtered {
    switch (_matrixFilter) {
      case 'WARNING':
        return widget.students.where((s) => s.isWarning && !s.isBanned).toList();
      case 'BANNED':
        return widget.students
            .where((s) => s.isBanned || s.hasExhaustedAbsenceAllowance || s.isExactlyAtAbsenceLimit)
            .toList();
      default:
        return widget.students;
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _filtered;
    final bannedCount = widget.students
        .where((s) => s.isBanned || s.hasExhaustedAbsenceAllowance || s.isExactlyAtAbsenceLimit)
        .length;
    final warningCount = widget.students.where((s) => s.isWarning && !s.isBanned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter bar ─────────────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.grid_view_rounded, size: 15, color: BirdleColors.textSecondary),
            const SizedBox(width: 6),
            const Text('Matrix View — 20 buổi × cả lớp',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BirdleColors.textPrimary)),
            const SizedBox(width: 16),
            _filterChip('Tất cả (${widget.students.length})', 'ALL'),
            const SizedBox(width: 6),
            if (warningCount > 0) ...[
              _filterChip('⚠ Cảnh báo ($warningCount)', 'WARNING', color: BirdleColors.warning),
              const SizedBox(width: 6),
            ],
            if (bannedCount > 0)
              _filterChip('🚫 Nguy hiểm ($bannedCount)', 'BANNED', color: BirdleColors.danger),
            const Spacer(),
            // Legend
            _legendDot(BirdleColors.success, 'Có mặt'),
            const SizedBox(width: 10),
            _legendDot(BirdleColors.danger, 'Vắng'),
            const SizedBox(width: 10),
            _legendDot(BirdleColors.border, 'Chưa điểm'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Matrix table ────────────────────────────────────────────────────
        Expanded(
          child: students.isEmpty
              ? const Center(
                  child: Text('Không có sinh viên nào khớp bộ lọc.',
                      style: TextStyle(color: BirdleColors.textMuted, fontSize: 13)),
                )
              : _buildMatrix(students),
        ),
      ],
    );
  }

  Widget _buildMatrix(List<Student> students) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Column header B1..B20 ──
          _buildColumnHeader(),
          const SizedBox(height: 2),

          // ── Student rows ──
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (ctx, i) => _buildStudentRow(students[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader() {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: BirdleColors.surfaceSecondary,
        border: Border(bottom: BorderSide(color: BirdleColors.border)),
      ),
      child: Row(
        children: [
          // Name col header
          SizedBox(
            width: _nameColWidth,
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text('SINH VIÊN', style: BirdleTypography.caption),
            ),
          ),
          // B1..B20
          ...List.generate(20, (i) {
            final slotNo = i + 1;
            final isCurrent = slotNo == widget.currentSessionNumber;
            return SizedBox(
              width: _cellSize + _cellGap,
              child: Center(
                child: Container(
                  width: _cellSize,
                  alignment: Alignment.center,
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: BirdleColors.brandLight,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: BirdleColors.brand.withValues(alpha: 0.5)),
                        )
                      : null,
                  child: Text(
                    '$slotNo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent ? BirdleColors.brand : BirdleColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Rate header
          SizedBox(
            width: _rateColWidth,
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text('CHUYÊN CẦN', style: BirdleTypography.caption),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Student student, int index) {
    final isBanned = student.isBanned || student.hasExhaustedAbsenceAllowance || student.isExactlyAtAbsenceLimit;
    final isWarn = student.isWarning;

    Color rowBg;
    if (isBanned) {
      rowBg = BirdleColors.dangerLight;
    } else if (isWarn) {
      rowBg = BirdleColors.warningLight;
    } else if (student.absentSlots == 0) {
      rowBg = BirdleColors.successLight;
    } else {
      rowBg = index.isEven ? Colors.white : BirdleColors.surfaceSecondary.withValues(alpha: 0.4);
    }

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: BirdleColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Student name
          SizedBox(
            width: _nameColWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: BirdleColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    student.rollNumber,
                    style: const TextStyle(fontSize: 10.5, color: BirdleColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // 20 slot cells
          ...List.generate(20, (i) {
            final slotNo = i + 1;
            final rawVal = student.getSlot20Status(slotNo).toLowerCase();
            final isCurrent = slotNo == widget.currentSessionNumber;

            Color cellColor;
            String tooltip;
            if (rawVal == 'p' || rawVal == 'present' || rawVal == 'cm' || rawVal == 'có mặt') {
              cellColor = BirdleColors.success;
              tooltip = 'Buổi $slotNo — Có mặt';
            } else if (rawVal == 'a' || rawVal == 'absent' || rawVal == 'v' || rawVal == 'vắng') {
              cellColor = BirdleColors.danger;
              tooltip = 'Buổi $slotNo — Vắng';
            } else {
              cellColor = BirdleColors.border;
              tooltip = 'Buổi $slotNo — Chưa điểm danh';
            }

            return SizedBox(
              width: _cellSize + _cellGap,
              child: Center(
                child: Tooltip(
                  message: tooltip,
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: _cellSize - 2,
                    height: _cellSize - 2,
                    decoration: BoxDecoration(
                      color: cellColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: isCurrent
                          ? Border.all(color: BirdleColors.brand, width: 1.5)
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }),

          // Rate badge
          SizedBox(
            width: _rateColWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    AbsentRateBadge(rate: student.absentRate, student: student, showPercent: true),
                    const SizedBox(width: 6),
                    Text(
                      '${student.absentSlots}/${student.totalSlots}',
                      style: const TextStyle(fontSize: 11, color: BirdleColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, {Color? color}) {
    final isSelected = _matrixFilter == value;
    final c = color ?? BirdleColors.brand;
    return InkWell(
      onTap: () => setState(() => _matrixFilter = value),
      borderRadius: BirdleRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BirdleRadius.pillBorder,
          border: Border.all(
            color: isSelected ? c : BirdleColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? c : BirdleColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: BirdleColors.textMuted)),
      ],
    );
  }
}
