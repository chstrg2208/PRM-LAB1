import 'dart:async';
import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'student_slots_dialog.dart';

/// Single student row in AttendanceView table with stabilized controller lifecycle
/// and 300ms note debounce (Task BK-02).
class AttendanceStudentRow extends StatefulWidget {
  final int index;
  final Student student;
  final AttendanceRecord record;
  final Function(String rollNumber, AttendanceStatus status) onStatusChanged;
  final Function(String rollNumber, String note) onNoteChanged;

  const AttendanceStudentRow({
    super.key,
    required this.index,
    required this.student,
    required this.record,
    required this.onStatusChanged,
    required this.onNoteChanged,
  });

  @override
  State<AttendanceStudentRow> createState() => _AttendanceStudentRowState();
}

class _AttendanceStudentRowState extends State<AttendanceStudentRow> {
  late final TextEditingController _noteController;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastSubmittedNote = '';

  @override
  void initState() {
    super.initState();
    _lastSubmittedNote = widget.record.note;
    _noteController = TextEditingController(text: widget.record.note);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _flushNote();
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceStudentRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sessionChanged = oldWidget.record.slot != widget.record.slot ||
        oldWidget.record.date != widget.record.date ||
        oldWidget.record.className != widget.record.className ||
        oldWidget.student.rollNumber != widget.student.rollNumber;

    if (sessionChanged) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _lastSubmittedNote = widget.record.note;
      _noteController.text = widget.record.note;
      _noteController.selection = TextSelection.collapsed(offset: _noteController.text.length);
    } else if (oldWidget.record.note != widget.record.note) {
      // Synchronize only when not actively typing and external value differs
      if (_debounceTimer == null &&
          _noteController.text != widget.record.note &&
          _lastSubmittedNote != widget.record.note) {
        _lastSubmittedNote = widget.record.note;
        _noteController.text = widget.record.note;
        _noteController.selection = TextSelection.collapsed(offset: _noteController.text.length);
      }
    }
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _flushNote();
      }
    });
  }

  void _flushNote() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final currentText = _noteController.text;
    if (_lastSubmittedNote != currentText) {
      _lastSubmittedNote = currentText;
      widget.onNoteChanged(widget.student.rollNumber, currentText);
    }
  }

  void _handleStatusChanged(AttendanceStatus status) {
    _flushNote();
    widget.onStatusChanged(widget.student.rollNumber, status);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Màu nền row dựa trên tỉ lệ vắng
  Color _rowBgColor() {
    final s = widget.student;
    if (s.totalSlots <= 0) return Colors.white;
    if (s.isBanned) return BirdleColors.dangerLight;         // >20% → đỏ
    if (s.absentSlots > 0) return BirdleColors.warningLight; // >0% đến ≤20% → vàng
    return BirdleColors.successLight;                         // 0 buổi vắng → xanh
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final isBanned = student.isBanned;
    final isAtLimit = student.hasExhaustedAbsenceAllowance || student.isExactlyAtAbsenceLimit;
    final isWarning = student.isWarning;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: _rowBgColor(),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 44,
            child: Text('${widget.index}', style: BirdleTypography.metadata),
          ),

          // Student ID (Roll Number)
          SizedBox(
            width: 120,
            child: Text(
              student.rollNumber,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BirdleColors.textPrimary,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
          ),

          // Student Name & Code + Warning Badge
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName, style: BirdleTypography.bodyMedium),
                      if (student.email.isNotEmpty)
                        Text(student.email, style: const TextStyle(fontSize: 11, color: BirdleColors.textMuted)),
                    ],
                  ),
                ),
                if (isBanned || isAtLimit || isWarning) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: student.absenceStatusMessage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBanned || isAtLimit ? BirdleColors.dangerLight : BirdleColors.warningLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isBanned || isAtLimit ? BirdleColors.danger : BirdleColors.warning).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBanned ? Icons.block_rounded : (isAtLimit ? Icons.warning_rounded : Icons.warning_amber_rounded),
                            size: 10,
                            color: isBanned || isAtLimit ? BirdleColors.danger : BirdleColors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isBanned ? 'Cấm thi' : (isAtLimit ? 'Hết lượt' : '−${student.remainingAllowedAbsences}'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isBanned || isAtLimit ? BirdleColors.danger : BirdleColors.warning,
                              fontFamily: BirdleTypography.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status Controls (Segmented / Inline Pills per Section 12)
          SizedBox(
            width: 205,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _buildStatusPill(
                    label: 'Chưa',
                    isSelected: widget.record.status == AttendanceStatus.notYet,
                    selectedBg: BirdleColors.surfaceSecondary,
                    selectedFg: BirdleColors.textMuted,
                    onTap: () => _handleStatusChanged(AttendanceStatus.notYet),
                  ),
                  const SizedBox(width: 4),
                  _buildStatusPill(
                    label: 'Có mặt',
                    isSelected: widget.record.status == AttendanceStatus.present,
                    selectedBg: BirdleColors.successLight,
                    selectedFg: BirdleColors.success,
                    onTap: () => _handleStatusChanged(AttendanceStatus.present),
                  ),
                  const SizedBox(width: 4),
                  _buildStatusPill(
                    label: 'Vắng',
                    isSelected: widget.record.status == AttendanceStatus.absent,
                    selectedBg: BirdleColors.dangerLight,
                    selectedFg: BirdleColors.danger,
                    onTap: () => _handleStatusChanged(AttendanceStatus.absent),
                  ),
                ],
              ),
            ),
          ),

          // Note Field
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                height: 30,
                child: TextField(
                  controller: _noteController,
                  focusNode: _focusNode,
                  style: const TextStyle(fontSize: 12, color: BirdleColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add note...',
                    hintStyle: const TextStyle(fontSize: 11.5, color: BirdleColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BirdleRadius.smBorder, borderSide: BorderSide.none),
                    filled: true,
                    fillColor: BirdleColors.surfaceSecondary,
                  ),
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _flushNote(),
                ),
              ),
            ),
          ),

          // Attendance Rate & Badge (kèm nút xem ma trận 20 slot)
          SizedBox(
            width: 140,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => StudentSlotsDialog.show(context, widget.student),
                    borderRadius: BorderRadius.circular(6),
                    child: Tooltip(
                      message: 'Nhấn để xem chi tiết 20 slot của sinh viên',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AbsentRateBadge(rate: widget.student.absentRate, student: widget.student, showPercent: true),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded, size: 16, color: BirdleColors.textMuted),
                  tooltip: 'Xem chi tiết 20 slot',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => StudentSlotsDialog.show(context, widget.student),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isSelected,
    required Color selectedBg,
    required Color selectedFg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BirdleRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BirdleRadius.smBorder,
          border: Border.all(
            color: isSelected ? selectedFg.withValues(alpha: 0.3) : BirdleColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? selectedFg : BirdleColors.textSecondary,
            fontFamily: BirdleTypography.fontFamily,
          ),
        ),
      ),
    );
  }
}
