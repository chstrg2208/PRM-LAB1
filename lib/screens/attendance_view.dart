import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../models/qr_attendance_session.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/attendance_student_row.dart';
import '../widgets/fap_sync_dialog.dart';
import '../widgets/import_fap_dialog.dart';
import '../widgets/qr_attendance_dialog.dart';

class AttendanceView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final List<String> availableClasses;
  final bool isLoadingClasses;
  final String? classesError;
  final VoidCallback? onRetryLoadClasses;
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
  final String? errorMessage;
  final bool isSheetConfigured;
  final VoidCallback? onGoToSettings;
  final int currentSessionNumber;
  final bool isDateLocked;
  final QrAttendanceSession? Function()? onStartQrAttendance;
  final VoidCallback? onFinishQrAttendance;
  final VoidCallback? onCancelQrAttendance;
  final Future<void> Function()? onPollQrStatus;

  const AttendanceView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    this.availableClasses = const [],
    this.isLoadingClasses = false,
    this.classesError,
    this.onRetryLoadClasses,
    required this.currentSlot,
    required this.currentDate,
    this.isDateLocked = false,
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
    this.errorMessage,
    this.isSheetConfigured = true,
    this.onGoToSettings,
    this.currentSessionNumber = 1,
    this.onStartQrAttendance,
    this.onFinishQrAttendance,
    this.onCancelQrAttendance,
    this.onPollQrStatus,
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
    final isLocked = widget.isDateLocked ||
        (DateTime(widget.currentDate.year, widget.currentDate.month, widget.currentDate.day)
            .isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)));

    // Filter students
    final filteredStudents = widget.students.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSearch = s.rollNumber.toLowerCase().contains(q) || s.fullName.toLowerCase().contains(q);
        if (!matchSearch) return false;
      }

      if (_statusFilter != 'ALL') {
      final rec = widget.records.where((r) => r.rollNumber == s.rollNumber).firstOrNull;
      if (_statusFilter == 'NOT_YET' && rec?.status != AttendanceStatus.notYet) return false;
      if (_statusFilter == 'PRESENT' && rec?.status != AttendanceStatus.present) return false;
      if (_statusFilter == 'ABSENT' && rec?.status != AttendanceStatus.absent) return false;
    }

    return true;
  }).toList();

  final notYetCount = widget.records.where((r) => r.status == AttendanceStatus.notYet).length;
  final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
  final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;

  final dateStr = DateFormat('MMMM d, y').format(widget.currentDate);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 12 Header
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance', style: BirdleTypography.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currentClass} · Slot ${widget.currentSlot} (${ClassSession.getSlotTime(widget.currentSlot)}) · Buổi ${widget.currentSessionNumber}/20 · $dateStr',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Session Selectors
              _buildSessionPickers(),
              const SizedBox(width: 16),
              // Action Buttons (Section 12 design.md)
              BirdlePrimaryButton(
                icon: Icons.qr_code_scanner,
                label: 'Điểm danh QR',
                onPressed: isLocked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Buổi học ngày ${DateFormat('dd/MM/yyyy').format(widget.currentDate)} chưa diễn ra! Chỉ mở sau 00:00 ngày học.'),
                            backgroundColor: BirdleColors.warning,
                          ),
                        );
                      }
                    : () {
                        if (widget.onStartQrAttendance != null) {
                          final session = widget.onStartQrAttendance!();
                          if (session == null) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => QrAttendanceDialog(
                              session: session,
                              students: widget.students,
                              onFinishAttendance: () {
                                if (widget.onFinishQrAttendance != null) {
                                  widget.onFinishQrAttendance!();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Đã kết thúc điểm danh QR: Sinh viên chưa quét mã được đánh Vắng. Vui lòng kiểm tra lại trước khi bấm "Save to Sheet".'),
                                    backgroundColor: BirdleColors.success,
                                  ),
                                );
                              },
                              onCancelAttendance: () {
                                if (widget.onCancelQrAttendance != null) {
                                  widget.onCancelQrAttendance!();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã đóng phiên QR (giữ nguyên trạng thái sinh viên).'),
                                    backgroundColor: BirdleColors.surfaceSecondary,
                                  ),
                                );
                              },
                              onPollStatus: widget.onPollQrStatus,
                            ),
                          );
                      }
                    },
            ),
            const SizedBox(width: 8),
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
              onPressed: isLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Buổi học ngày ${DateFormat('dd/MM/yyyy').format(widget.currentDate)} chưa diễn ra! Chỉ mở sau 00:00 ngày học.'),
                          backgroundColor: BirdleColors.warning,
                        ),
                      );
                    }
                  : () {
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
      ),
        const SizedBox(height: 18),

        // Date Lock Banner cảnh báo khi buổi học chưa đến lịch
        if (isLocked) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: BirdleColors.surfaceSecondary,
              borderRadius: BirdleRadius.smBorder,
              border: Border.all(color: BirdleColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 20, color: BirdleColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buổi học bị khóa ngày (Date Lock)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BirdleColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Buổi học ngày ${DateFormat('dd/MM/yyyy').format(widget.currentDate)} chưa diễn ra. Hệ thống chỉ cho phép điểm danh sau 00:00 ngày học.',
                        style: const TextStyle(fontSize: 12, color: BirdleColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Summary & Filter Bar
        BirdleCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Quick Summary
                Text('${widget.students.length} Students', style: BirdleTypography.bodyMedium),
                _buildDotSeparator(),
                _buildSummaryBadge('All', BirdleColors.brand, () => setState(() => _statusFilter = 'ALL')),
                const SizedBox(width: 8),
                _buildSummaryBadge('$notYetCount Not yet', BirdleColors.textMuted, () => setState(() => _statusFilter = 'NOT_YET')),
                const SizedBox(width: 8),
                _buildSummaryBadge('$presentCount Present', BirdleColors.success, () => setState(() => _statusFilter = 'PRESENT')),
                const SizedBox(width: 8),
                _buildSummaryBadge('$absentCount Absent', BirdleColors.danger, () => setState(() => _statusFilter = 'ABSENT')),

                const SizedBox(width: 24),

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
        ),
        const SizedBox(height: 14),

          // Main Data Table (Section 12 dominant component)
          Expanded(
            child: BirdleCard(
              padding: EdgeInsets.zero,
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator(color: BirdleColors.brand, strokeWidth: 2))
                  : !widget.isSheetConfigured
                      ? BirdleEmptyState(
                          icon: Icons.link_off,
                          title: 'Chưa cấu hình Google Sheet Database',
                          description: 'Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt để đồng bộ và điểm danh.',
                          action: widget.onGoToSettings != null
                              ? BirdlePrimaryButton(
                                  icon: Icons.settings_outlined,
                                  label: 'Mở Cài đặt',
                                  onPressed: widget.onGoToSettings,
                                )
                              : null,
                        )
                      : (widget.classesError != null && widget.availableClasses.isEmpty && widget.students.isEmpty)
                          ? BirdleEmptyState(
                              icon: Icons.cloud_off,
                              title: 'Không thể tải danh sách lớp học',
                              description: widget.classesError!,
                              action: widget.onRetryLoadClasses != null
                                  ? BirdlePrimaryButton(
                                      icon: Icons.refresh,
                                      label: 'Thử lại',
                                      onPressed: widget.onRetryLoadClasses,
                                    )
                                  : null,
                            )
                      : (!widget.isLoadingClasses && widget.classesError == null && widget.availableClasses.isEmpty && widget.students.isEmpty && widget.currentClass.isEmpty)
                          ? BirdleEmptyState(
                              icon: Icons.class_outlined,
                              title: 'Không tìm thấy lớp học',
                              description: 'Bảng tính Google Sheet hiện chưa có sheet lớp học nào (hoặc các sheet đều bị ẩn). Hãy tạo sheet lớp trên Google Sheet.',
                              action: widget.onRetryLoadClasses != null
                                  ? BirdlePrimaryButton(
                                      icon: Icons.refresh,
                                      label: 'Tải lại danh sách lớp',
                                      onPressed: widget.onRetryLoadClasses,
                                    )
                                  : null,
                            )
                      : (widget.errorMessage != null && widget.students.isEmpty)
                          ? BirdleEmptyState(
                              icon: Icons.cloud_off,
                              title: 'Không thể tải dữ liệu lớp ${widget.currentClass}',
                              description: widget.errorMessage!,
                              action: BirdlePrimaryButton(
                                icon: Icons.refresh,
                                label: 'Thử lại',
                                onPressed: widget.onReloadFromSheet,
                              ),
                            )
                          : widget.students.isEmpty
                              ? BirdleEmptyState(
                                  icon: Icons.people_outline,
                                  title: 'Lớp chưa có sinh viên',
                                  description: 'Lớp ${widget.currentClass} hiện chưa có sinh viên trên Google Sheet. Bạn có thể nhập danh sách từ FAP hoặc thêm sinh viên.',
                                  action: BirdleSecondaryButton(
                                    icon: Icons.file_upload_outlined,
                                    label: 'Import từ FAP',
                                    onPressed: widget.onGoToFapSync,
                                  ),
                                )
                              : filteredStudents.isEmpty
                                  ? const BirdleEmptyState(
                                      icon: Icons.search_off,
                                      title: 'Không tìm thấy sinh viên',
                                      description: 'Không có sinh viên nào khớp với điều kiện tìm kiếm hoặc bộ lọc hiện tại.',
                                    )
                                  : Column(
                                      children: [
                                        if (widget.errorMessage != null)
                                          Container(
                                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: BirdleColors.dangerLight,
                                              borderRadius: BirdleRadius.smBorder,
                                              border: Border.all(color: BirdleColors.danger.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, size: 16, color: BirdleColors.danger),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Lỗi khi tải lại dữ liệu: ${widget.errorMessage}. Đang hiển thị dữ liệu đã lưu trước đó.',
                                                    style: const TextStyle(fontSize: 12.5, color: BirdleColors.danger, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                                BirdleGhostButton(
                                                  icon: Icons.refresh,
                                                  label: 'Thử lại',
                                                  color: BirdleColors.danger,
                                                  onPressed: widget.onReloadFromSheet,
                                                ),
                                              ],
                                            ),
                                          ),
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
                                  SizedBox(width: 205, child: Text('STATUS (PRESENT / ABSENT / NOT YET)', style: BirdleTypography.caption)),
                                  Expanded(flex: 2, child: Text('NOTE', style: BirdleTypography.caption)),
                                  SizedBox(width: 140, child: Text('ATTENDANCE RATE', style: BirdleTypography.caption)),
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
          // Class Dropdown or Loading/Error State
          if (widget.isLoadingClasses)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: BirdleColors.textSecondary),
                ),
                SizedBox(width: 6),
                Text('Đang tải lớp...', style: TextStyle(fontSize: 12.5, color: BirdleColors.textMuted)),
              ],
            )
          else if (widget.classesError != null)
            InkWell(
              onTap: widget.onRetryLoadClasses,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 14, color: BirdleColors.danger),
                  SizedBox(width: 4),
                  Text('Lỗi tải lớp (Thử lại)', style: TextStyle(fontSize: 12, color: BirdleColors.danger, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (widget.availableClasses.isEmpty && widget.currentClass.isEmpty)
            const Text('Chưa có lớp', style: TextStyle(fontSize: 12.5, color: BirdleColors.textMuted, fontStyle: FontStyle.italic))
          else
            DropdownButton<String>(
              value: (widget.availableClasses.contains(widget.currentClass) || widget.availableClasses.isEmpty) && widget.currentClass.isNotEmpty
                  ? widget.currentClass
                  : null,
              hint: const Text('Chọn lớp', style: TextStyle(fontSize: 13, color: BirdleColors.textMuted)),
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.textPrimary, fontSize: 13),
              items: (widget.availableClasses.isNotEmpty ? widget.availableClasses : [widget.currentClass])
                  .map((c) => DropdownMenuItem(value: c, child: Text('Lớp $c')))
                  .toList(),
              onChanged: widget.availableClasses.isNotEmpty
                  ? (val) {
                      if (val != null) widget.onClassChanged(val);
                    }
                  : null,
            ),
          Container(width: 1, height: 16, color: BirdleColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),

          // Slot Dropdown (Chuẩn 4 slot FPT)
          DropdownButton<int>(
            value: widget.currentSlot,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.textPrimary, fontSize: 13),
            items: List.generate(widget.currentSlot > 4 ? widget.currentSlot : 4, (i) => i + 1)
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
