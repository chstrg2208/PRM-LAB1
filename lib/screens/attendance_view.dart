import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../models/qr_attendance_session.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/attendance_student_row.dart';
import '../widgets/attendance_matrix_view.dart';
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
  final ValueChanged<int>? onSessionChanged;
  final bool isDateLocked;
  final QrAttendanceSession? Function()? onStartQrAttendance;
  final FutureOr<void> Function()? onFinishQrAttendance;
  final VoidCallback? onCancelQrAttendance;
  final Future<void> Function()? onPollQrStatus;
  final bool isQrAttendanceLocked;
  final bool isSessionCompleted;
  final QrAttendanceSession? Function()? onReopenQrAttendance;

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
    this.onSessionChanged,
    this.onStartQrAttendance,
    this.onFinishQrAttendance,
    this.onCancelQrAttendance,
    this.onPollQrStatus,
    this.isQrAttendanceLocked = false,
    this.isSessionCompleted = false,
    this.onReopenQrAttendance,
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, PRESENT, ABSENT, LATE, WARNING

  // Task 7: Success banner sau khi lưu thành công
  String? _lastSaveBanner;

  // Task 8: Toggle giữa Table View và Matrix View
  bool _isMatrixView = false;

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
        if (_statusFilter == 'WARNING' && !(s.isWarning || s.isBanned || s.hasExhaustedAbsenceAllowance || s.isExactlyAtAbsenceLimit)) return false;
      }

      return true;
    }).toList();

    final notYetCount = widget.records.where((r) => r.status == AttendanceStatus.notYet).length;
    final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;

    // Task 6: Tính số sinh viên cảnh báo/cấm thi (dựa trên dữ liệu 20 slot)
    final warningStudents = widget.students.where((s) => s.isWarning).length;
    final bannedStudents = widget.students.where((s) => s.isBanned || s.hasExhaustedAbsenceAllowance || s.isExactlyAtAbsenceLimit).length;

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
              if (isLocked)
                BirdlePrimaryButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Điểm danh QR (Chưa tới ngày)',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Buổi học ngày ${DateFormat('dd/MM/yyyy').format(widget.currentDate)} chưa diễn ra! Chỉ mở sau 00:00 ngày học.'),
                        backgroundColor: BirdleColors.warning,
                      ),
                    );
                  },
                )
              else if (widget.isQrAttendanceLocked)
                BirdleSecondaryButton(
                  icon: Icons.lock_outline,
                  label: 'Đã chốt QR (Khóa)',
                  onPressed: _showLockedQrDialog,
                )
              else
                BirdlePrimaryButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Điểm danh QR',
                  onPressed: () {
                    if (widget.onStartQrAttendance != null) {
                      final session = widget.onStartQrAttendance!();
                      if (session != null) {
                        _showQrDialog(session);
                      }
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
                      _showSaveConfirmDialog(context); // Task 7
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
            const SizedBox(width: 16),
            // Task 8: View Toggle — Table / Matrix
            Container(
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewToggle(
                    icon: Icons.table_rows_outlined,
                    label: 'Bảng',
                    isSelected: !_isMatrixView,
                    onTap: () => setState(() => _isMatrixView = false),
                  ),
                  Container(width: 1, height: 24, color: BirdleColors.border),
                  _buildViewToggle(
                    icon: Icons.grid_view_rounded,
                    label: 'Matrix',
                    isSelected: _isMatrixView,
                    onTap: () => setState(() => _isMatrixView = true),
                  ),
                ],
              ),
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

        // Task 8: Swap giữa Matrix View và Table View
        if (_isMatrixView) ...[
          Expanded(
            child: BirdleCard(
              padding: const EdgeInsets.all(16),
              child: widget.students.isEmpty
                  ? const Center(
                      child: Text('Chưa có sinh viên. Hãy tải dữ liệu lớp trước.',
                          style: TextStyle(color: BirdleColors.textMuted)),
                    )
                  : AttendanceMatrixView(
                      students: widget.students,
                      currentSessionNumber: widget.currentSessionNumber,
                      currentClass: widget.currentClass,
                    ),
            ),
          ),
        ] else ...[

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
                // Task 6: Warning filter badge (chỉ hiện khi có sinh viên cảnh báo)
                if (warningStudents + bannedStudents > 0) ...[
                  const SizedBox(width: 8),
                  _buildSummaryBadge(
                    '${warningStudents + bannedStudents} ⚠ Cảnh báo',
                    BirdleColors.warning,
                    () => setState(() => _statusFilter = 'WARNING'),
                  ),
                ],

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
        // Task 6: Warning Summary Banner — chỉ hiện khi có sinh viên nguy cơ
        if ((warningStudents > 0 || bannedStudents > 0) && widget.students.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _statusFilter = 'WARNING'),
            borderRadius: BirdleRadius.smBorder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bannedStudents > 0 ? BirdleColors.dangerLight : BirdleColors.warningLight,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(
                  color: (bannedStudents > 0 ? BirdleColors.danger : BirdleColors.warning).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    bannedStudents > 0 ? Icons.block_rounded : Icons.warning_amber_rounded,
                    size: 16,
                    color: bannedStudents > 0 ? BirdleColors.danger : BirdleColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: bannedStudents > 0 ? BirdleColors.danger : BirdleColors.warning,
                          fontFamily: BirdleTypography.fontFamily,
                        ),
                        children: [
                          if (bannedStudents > 0)
                            TextSpan(
                              text: '$bannedStudents sinh viên nguy hiểm (cấm thi / hết lượt vắng)',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          if (bannedStudents > 0 && warningStudents > 0)
                            const TextSpan(text: ' · '),
                          if (warningStudents > 0)
                            TextSpan(
                              text: '$warningStudents sinh viên cảnh báo (15–20% vắng)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          const TextSpan(
                            text: ' — Nhấn để lọc xem nhóm này',
                            style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: bannedStudents > 0 ? BirdleColors.danger : BirdleColors.warning,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Task 7: Success Banner sau khi lưu thành công (tự ẩn)
        if (_lastSaveBanner != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: BirdleColors.successLight,
              borderRadius: BirdleRadius.smBorder,
              border: Border.all(color: BirdleColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: BirdleColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lastSaveBanner!,
                    style: const TextStyle(fontSize: 12.5, color: BirdleColors.success, fontWeight: FontWeight.w600),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _lastSaveBanner = null),
                  child: const Icon(Icons.close, size: 15, color: BirdleColors.success),
                ),
              ],
            ),
          ),
        ],

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
                                  SizedBox(width: 150, child: Text('ĐIỂM DANH (CÓ MẶT / VẮNG)', style: BirdleTypography.caption)),
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
        ], // end else (Table View)
      ],
      ),
    );
  }

  // Task 8: Toggle button helper
  Widget _buildViewToggle({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BirdleRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? BirdleColors.brand.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BirdleRadius.smBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? BirdleColors.brand : BirdleColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? BirdleColors.brand : BirdleColors.textMuted,
              ),
            ),
          ],
        ),
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

          // Buổi Dropdown (Buổi 1..20)
          DropdownButton<int>(
            value: widget.currentSessionNumber >= 1 && widget.currentSessionNumber <= 20
                ? widget.currentSessionNumber
                : 1,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.brand, fontSize: 13),
            items: List.generate(20, (i) => i + 1)
                .map((s) => DropdownMenuItem(value: s, child: Text('Buổi $s')))
                .toList(),
            onChanged: (val) {
              if (val != null) widget.onSessionChanged?.call(val);
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

  // ─── Task 7: Save Confirmation Flow ───────────────────────────────────────

  /// Tính toán sinh viên nào sẽ thay đổi trạng thái cảnh báo sau buổi này
  List<_WarningImpact> _computeWarningImpacts() {
    final impacts = <_WarningImpact>[];
    for (final student in widget.students) {
      final rec = widget.records.where((r) => r.rollNumber == student.rollNumber).firstOrNull;
      if (rec == null || rec.status != AttendanceStatus.absent) continue;

      // Giả lập: nếu buổi này bị Vắng, absent của sinh viên sẽ tăng lên 1
      final projectedAbsent = student.absentSlots + 1;
      final total = student.totalSlots;
      if (total <= 0) continue;

      final wasOk = !student.isBanned && !student.hasExhaustedAbsenceAllowance && !student.isExactlyAtAbsenceLimit;
      final willBeBanned = projectedAbsent * 100 > total * 20;
      final willBeAtLimit = projectedAbsent * 100 == total * 20;

      if (wasOk && (willBeBanned || willBeAtLimit)) {
        impacts.add(_WarningImpact(
          student: student,
          isBanned: willBeBanned,
        ));
      }
    }
    return impacts;
  }

  Future<void> _showSaveConfirmDialog(BuildContext ctx) async {
    final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;
    final notYetCount = widget.records.where((r) => r.status == AttendanceStatus.notYet).length;
    final impacts = _computeWarningImpacts();
    final sessionLabel = 'Buổi ${widget.currentSessionNumber}/20 · ${widget.currentClass} · ${DateFormat('dd/MM/yyyy').format(widget.currentDate)}';

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: BirdleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BirdleColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: BirdleColors.surfaceSecondary, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.save_outlined, color: BirdleColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Xác nhận lưu điểm danh',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BirdleColors.textPrimary, fontFamily: BirdleTypography.fontFamily)),
                  Text(sessionLabel,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: BirdleColors.textMuted, fontFamily: BirdleTypography.fontFamily)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tóm tắt 3 con số
              Row(
                children: [
                  _buildStatCard('$presentCount', 'Có mặt', BirdleColors.success, BirdleColors.successLight),
                  const SizedBox(width: 8),
                  _buildStatCard('$absentCount', 'Vắng', BirdleColors.danger, BirdleColors.dangerLight),
                  const SizedBox(width: 8),
                  _buildStatCard('$notYetCount', 'Chưa điểm', BirdleColors.textMuted, BirdleColors.surfaceSecondary),
                ],
              ),

              // Cảnh báo Not Yet
              if (notYetCount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: BirdleColors.warningLight,
                    borderRadius: BirdleRadius.smBorder,
                    border: Border.all(color: BirdleColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 15, color: BirdleColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Còn $notYetCount sinh viên chưa được điểm danh. Họ sẽ vẫn là "Chưa" trên Sheet sau khi lưu.',
                          style: const TextStyle(fontSize: 12, color: BirdleColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Tác động cảnh báo vắng
              if (impacts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: BirdleColors.dangerLight,
                    borderRadius: BirdleRadius.smBorder,
                    border: Border.all(color: BirdleColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.block_rounded, size: 14, color: BirdleColors.danger),
                          const SizedBox(width: 6),
                          Text(
                            '${impacts.length} sinh viên sẽ chạm/vượt ngưỡng sau buổi này:',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BirdleColors.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...impacts.map((imp) => Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  imp.isBanned ? Icons.block : Icons.warning_amber_rounded,
                                  size: 11,
                                  color: BirdleColors.danger,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${imp.student.fullName} (${imp.student.rollNumber}) — ${imp.isBanned ? "CẤM THI >20%" : "Chạm ngưỡng 20%"}',
                                  style: const TextStyle(fontSize: 11.5, color: BirdleColors.danger),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Quay lại kiểm tra', style: TextStyle(color: BirdleColors.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_outlined, size: 15),
            label: const Text('Xác nhận & Lưu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BirdleColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onSaveToSheet();
      // Xây dựng success banner
      final banner = '✓ Đã lưu Buổi ${widget.currentSessionNumber}/20 lên Google Sheets — $presentCount Có mặt · $absentCount Vắng · $notYetCount Chưa';
      setState(() => _lastSaveBanner = banner);
      // Tự ẩn sau 5 giây
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _lastSaveBanner == banner) {
          setState(() => _lastSaveBanner = null);
        }
      });
    }
  }

  Widget _buildStatCard(String value, String label, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bgColor, borderRadius: BirdleRadius.smBorder),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: BirdleTypography.fontFamily)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(QrAttendanceSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QrAttendanceDialog(
        session: session,
        students: widget.students,
        onFinishAttendance: () async {
          if (widget.onFinishQrAttendance != null) {
            await widget.onFinishQrAttendance!();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Đã kết thúc điểm danh QR: Sinh viên chưa quét mã được đánh Vắng. Vui lòng kiểm tra lại trước khi bấm "Save to Sheet".'),
                backgroundColor: BirdleColors.success,
              ),
            );
          }
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

  void _showLockedQrDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: BirdleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BirdleColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_outline, color: BirdleColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Điểm danh QR đã chốt',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: BirdleColors.textPrimary,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buổi học này đã hoàn tất điểm danh. Nhằm chống gian lận quét mã, tính năng tạo QR cho buổi học này mặc định đã được khóa.',
              style: TextStyle(fontSize: 13.5, color: BirdleColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BirdleColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ Toàn quyền sửa thủ công:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: BirdleColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Giảng viên có thể tự do bấm đổi trạng thái (Chưa / Có mặt / Vắng) cho từng sinh viên trên danh sách và bấm "Save to Sheet".',
                    style: TextStyle(fontSize: 12, color: BirdleColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BirdleSecondaryButton(
            label: 'Sửa trên bảng',
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          if (widget.onReopenQrAttendance != null)
            BirdlePrimaryButton(
              icon: Icons.refresh,
              label: 'Mở lại QR (30s)',
              onPressed: () {
                Navigator.pop(dialogCtx);
                final session = widget.onReopenQrAttendance!();
                if (session != null) {
                  _showQrDialog(session);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Helper class cho Task 7: lưu thông tin sinh viên sẽ bị ảnh hưởng sau khi lưu
class _WarningImpact {
  final Student student;
  final bool isBanned; // true = vượt >20%, false = chạm đúng 20%
  const _WarningImpact({required this.student, required this.isBanned});
}
