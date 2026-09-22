import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/attendance_student_row.dart';
import '../widgets/fap_sync_dialog.dart';
import '../widgets/import_fap_dialog.dart';

class AttendanceView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final int currentSlot;
  final DateTime currentDate;
  final bool isLoading;
  final Function(String) onClassChanged;
  final Function(int) onSlotChanged;
  final Function(DateTime) onDateChanged;
  final Function(String rollNumber, AttendanceStatus status) onStatusChanged;
  final Function(String rollNumber, String note) onNoteChanged;
  final VoidCallback onMarkAllPresent;
  final VoidCallback onMarkAllAbsent;
  final VoidCallback onSaveToSheet;
  final VoidCallback onReloadFromSheet;
  final VoidCallback onGoToFapSync;
  final Function(List<Student>) onImportStudents;

  const AttendanceView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.currentSlot,
    required this.currentDate,
    required this.isLoading,
    required this.onClassChanged,
    required this.onSlotChanged,
    required this.onDateChanged,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onMarkAllPresent,
    required this.onMarkAllAbsent,
    required this.onSaveToSheet,
    required this.onReloadFromSheet,
    required this.onGoToFapSync,
    required this.onImportStudents,
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, PRESENT, ABSENT, LATE

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter students
    final filteredStudents = widget.students.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSearch = s.rollNumber.toLowerCase().contains(q) || s.fullName.toLowerCase().contains(q);
        if (!matchSearch) return false;
      }

      if (_statusFilter != 'ALL') {
        final rec = widget.records.where((r) => r.rollNumber == s.rollNumber).firstOrNull;
        if (_statusFilter == 'PRESENT' && rec?.status != AttendanceStatus.present) return false;
        if (_statusFilter == 'ABSENT' && rec?.status != AttendanceStatus.absent) return false;
        if (_statusFilter == 'LATE' && rec?.status != AttendanceStatus.late) return false;
      }

      return true;
    }).toList();

    final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount = widget.records.where((r) => r.status == AttendanceStatus.late).length;
    final pendingCount = widget.students.length - (presentCount + absentCount + lateCount);

    final dateStr = DateFormat('MMMM d, y').format(widget.currentDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 12 Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance', style: BirdleTypography.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currentClass} · Slot ${widget.currentSlot} (${ClassSession.getSlotTime(widget.currentSlot)}) · $dateStr',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),
              // Session Selectors
              _buildSessionPickers(),
              const SizedBox(width: 16),
              // Action Buttons (Section 12 design.md)
              BirdleSecondaryButton(
                icon: Icons.file_upload_outlined,
                label: 'Import from FAP',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ImportFapDialog(
                      currentClass: widget.currentClass,
                      onImport: widget.onImportStudents,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              BirdleSecondaryButton(
                icon: Icons.save_outlined,
                label: 'Save to Sheet',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.onSaveToSheet();
                },
              ),
              const SizedBox(width: 8),
              BirdlePrimaryButton(
                icon: Icons.bolt,
                label: 'Sync to FAP',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  showDialog(
                    context: context,
                    builder: (_) => FapSyncDialog(
                      records: widget.records,
                      className: widget.currentClass,
                      slot: widget.currentSlot,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Summary & Filter Bar
          BirdleCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Quick Summary
                Text('${widget.students.length} Students', style: BirdleTypography.bodyMedium),
                _buildDotSeparator(),
                _buildSummaryBadge('$presentCount Present', BirdleColors.success, () => setState(() => _statusFilter = 'PRESENT')),
                const SizedBox(width: 8),
                _buildSummaryBadge('$absentCount Absent', BirdleColors.danger, () => setState(() => _statusFilter = 'ABSENT')),
                const SizedBox(width: 8),
                _buildSummaryBadge('$lateCount Late', BirdleColors.warning, () => setState(() => _statusFilter = 'LATE')),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildSummaryBadge('$pendingCount Pending', BirdleColors.pending, () => setState(() => _statusFilter = 'ALL')),
                ],

                const Spacer(),

                // Batch Actions (Section 12 design.md)
                BirdleGhostButton(
                  icon: Icons.done_all,
                  label: 'Mark All Present',
                  color: BirdleColors.brand,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    widget.onMarkAllPresent();
                  },
                ),
                const SizedBox(width: 4),
                BirdleGhostButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Mark All Absent',
                  color: BirdleColors.danger,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    widget.onMarkAllAbsent();
                  },
                ),
                const SizedBox(width: 12),

                // Search field
                BirdleSearchField(
                  controller: _searchController,
                  hintText: 'Search students...',
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                if (_statusFilter != 'ALL') ...[
                  const SizedBox(width: 8),
                  BirdleGhostButton(
                    icon: Icons.filter_alt_off,
                    label: 'Clear filter',
                    onPressed: () => setState(() => _statusFilter = 'ALL'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main Data Table (Section 12 dominant component)
          Expanded(
            child: BirdleCard(
              padding: EdgeInsets.zero,
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator(color: BirdleColors.brand, strokeWidth: 2))
                  : filteredStudents.isEmpty
                      ? const BirdleEmptyState(
                          icon: Icons.search_off,
                          title: 'Không tìm thấy sinh viên',
                          description: 'Không có sinh viên nào khớp với điều kiện tìm kiếm hoặc bộ lọc hiện tại.',
                        )
                      : Column(
                          children: [
                            // Table Header Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                              decoration: const BoxDecoration(
                                color: BirdleColors.surfaceSecondary,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                border: Border(bottom: BorderSide(color: BirdleColors.border)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 44, child: Text('#', style: BirdleTypography.caption)),
                                  SizedBox(width: 120, child: Text('STUDENT ID', style: BirdleTypography.caption)),
                                  Expanded(flex: 3, child: Text('STUDENT NAME', style: BirdleTypography.caption)),
                                  SizedBox(width: 220, child: Text('STATUS (PRESENT / ABSENT / LATE)', style: BirdleTypography.caption)),
                                  Expanded(flex: 2, child: Text('NOTE', style: BirdleTypography.caption)),
                                  SizedBox(width: 130, child: Text('ATTENDANCE RATE', style: BirdleTypography.caption)),
                                ],
                              ),
                            ),

                            // Table Rows
                            Expanded(
                              child: ListView.separated(
                                itemCount: filteredStudents.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  final record = widget.records.firstWhere(
                                    (r) => r.rollNumber == student.rollNumber,
                                    orElse: () => AttendanceRecord(
                                      rollNumber: student.rollNumber,
                                      className: widget.currentClass,
                                      date: widget.currentDate.toIso8601String(),
                                      slot: widget.currentSlot,
                                      status: AttendanceStatus.present,
                                    ),
                                  );

                                  return AttendanceStudentRow(
                                    key: ValueKey('attendance_row_${student.rollNumber}'),
                                    index: index + 1,
                                    student: student,
                                    record: record,
                                    onStatusChanged: widget.onStatusChanged,
                                    onNoteChanged: widget.onNoteChanged,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPickers() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BirdleRadius.smBorder,
        border: Border.all(color: BirdleColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Class Dropdown
          DropdownButton<String>(
            value: widget.currentClass,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.textPrimary, fontSize: 13),
            items: ['SE1801', 'SE1802', 'SE1803', 'IA1801', 'PRM392-Lab']
                .map((c) => DropdownMenuItem(value: c, child: Text('Lớp $c')))
                .toList(),
            onChanged: (val) {
              if (val != null) widget.onClassChanged(val);
            },
          ),
          Container(width: 1, height: 16, color: BirdleColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),

          // Slot Dropdown
          DropdownButton<int>(
            value: widget.currentSlot,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.textPrimary, fontSize: 13),
            items: List.generate(6, (i) => i + 1)
                .map((s) => DropdownMenuItem(value: s, child: Text('Slot $s')))
                .toList(),
            onChanged: (val) {
              if (val != null) widget.onSlotChanged(val);
            },
          ),
          Container(width: 1, height: 16, color: BirdleColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),

          // Date Picker Clickable
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.currentDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2028),
              );
              if (picked != null) widget.onDateChanged(picked);
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: BirdleColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yyyy').format(widget.currentDate),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: BirdleColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BirdleRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BirdleRadius.pillBorder,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            fontFamily: BirdleTypography.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildDotSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: BirdleColors.border,
        shape: BoxShape.circle,
      ),
    );
  }
}
