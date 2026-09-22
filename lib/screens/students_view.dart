import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';
import '../widgets/student_slots_dialog.dart';

class StudentsView extends StatefulWidget {
  final List<Student> students;
  final String currentClass;
  final List<String> availableClasses;
  final bool isLoadingClasses;
  final String? classesError;
  final VoidCallback? onRetryLoadClasses;
  final Function(List<Student>) onUpdateStudents;
  final Function(String) onClassChanged;
  final VoidCallback onSyncToSheet;
  final VoidCallback onGoToImport;
  final bool isLoading;
  final String? errorMessage;
  final bool isSheetConfigured;
  final VoidCallback? onReload;
  final VoidCallback? onGoToSettings;

  const StudentsView({
    super.key,
    required this.students,
    required this.currentClass,
    this.availableClasses = const [],
    this.isLoadingClasses = false,
    this.classesError,
    this.onRetryLoadClasses,
    required this.onUpdateStudents,
    required this.onClassChanged,
    required this.onSyncToSheet,
    required this.onGoToImport,
    this.isLoading = false,
    this.errorMessage,
    this.isSheetConfigured = true,
    this.onReload,
    this.onGoToSettings,
  });

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStudentDetailDialog(Student s) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BirdleRadius.mdBorder),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: BirdleColors.surfaceSecondary,
                      borderRadius: BirdleRadius.smBorder,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.member.length >= 2 ? s.member.substring(0, 2) : 'SV',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: BirdleColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: BirdleTypography.cardTitle),
                        const SizedBox(height: 2),
                        Text('${s.member} · Lớp ${widget.currentClass}', style: BirdleTypography.metadata),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),

              // Attendance Statistics (Section 13 design.md)
              Row(
                children: [
                  _buildMetricBox('Tổng buổi học', '${s.totalSlots}'),
                  const SizedBox(width: 12),
                  _buildMetricBox('Số buổi vắng', '${s.absentSlots}', color: s.absentSlots > 0 ? BirdleColors.danger : BirdleColors.success),
                  const SizedBox(width: 12),
                  _buildMetricBox(
                    'Tỷ lệ vắng',
                    '${s.absentRate.toStringAsFixed(1)}%',
                    color: s.isBanned
                        ? BirdleColors.danger
                        : ((s.isWarning || s.hasExhaustedAbsenceAllowance) ? BirdleColors.warning : BirdleColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Student details grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BirdleColors.surfaceSecondary,
                  borderRadius: BirdleRadius.smBorder,
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Mã SV (CODE)', s.rollNumber.isNotEmpty ? s.rollNumber : '-'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Họ (SURNAME)', s.surname.isNotEmpty ? s.surname : '-'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Tên đệm (MIDDLE NAME)', s.middleName.isNotEmpty ? s.middleName : '-'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Tên gọi (GIVEN NAME)', s.givenName.isNotEmpty ? s.givenName : '-'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Họ và tên đầy đủ', s.fullName),
                    const SizedBox(height: 8),
                    _buildDetailRow('Email FPT', s.email.isNotEmpty ? s.email : '${s.member.toLowerCase()}@fpt.edu.vn'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Trạng thái đào tạo', s.trainingStatusLabel),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Compact Contextual AI Insight (Section 13 design.md)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BirdleColors.brandLight,
                  borderRadius: BirdleRadius.smBorder,
                  border: Border.all(color: BirdleColors.brand.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: BirdleColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.absenceStatusMessage,
                        style: const TextStyle(fontSize: 12.5, color: BirdleColors.textPrimary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nút xem chi tiết 20 slot điểm danh
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: const Text('Xem ma trận 20 buổi học của sinh viên'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BirdleColors.brand,
                    side: const BorderSide(color: BirdleColors.brand),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    StudentSlotsDialog.show(this.context, s);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: BirdleColors.surface,
          borderRadius: BirdleRadius.smBorder,
          border: Border.all(color: BirdleColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: BirdleTypography.caption),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? BirdleColors.textPrimary,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 140, child: Text(label, style: BirdleTypography.metadata)),
        Expanded(child: Text(value, style: BirdleTypography.bodyMedium)),
      ],
    );
  }

  void _showAddStudentDialog() {
    final rollNumberCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final middleNameCtrl = TextEditingController();
    final givenNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BirdleRadius.mdBorder),
        title: const Text('Thêm sinh viên mới', style: BirdleTypography.cardTitle),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rollNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã SV / CODE',
                  hintText: 'Ví dụ: SE180001, CE190585',
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && emailCtrl.text.isEmpty) {
                    emailCtrl.text = '${val.toLowerCase()}@fpt.edu.vn';
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: surnameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ (SURNAME)', hintText: 'Lâm'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: middleNameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên đệm (MIDDLE NAME)', hintText: 'Quốc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: givenNameCtrl,
                decoration: const InputDecoration(labelText: 'Tên gọi (GIVEN NAME)', hintText: 'Minh'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email FPT', hintText: 'minhlqce190585@fpt.edu.vn'),
              ),
            ],
          ),
        ),
        actions: [
          BirdleSecondaryButton(label: 'Hủy', onPressed: () => Navigator.pop(context)),
          BirdlePrimaryButton(
            label: 'Lưu sinh viên',
            onPressed: () {
              final member = rollNumberCtrl.text.trim().toUpperCase();
              if (member.isEmpty) return;

              final newStudent = Student(
                member: member,
                code: member,
                surname: surnameCtrl.text.trim(),
                middleName: middleNameCtrl.text.trim(),
                givenName: givenNameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                className: widget.currentClass,
                totalSlots: 20,
                absentSlots: 0,
              );

              final updated = List<Student>.from(widget.students)..add(newStudent);
              widget.onUpdateStudents(updated);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Đã thêm sinh viên $member thành công!'),
                  backgroundColor: BirdleColors.brand,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students.where((s) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.rollNumber.toLowerCase().contains(q) || s.fullName.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Section 13 design.md)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Students', style: BirdleTypography.pageTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.students.length} students · Lớp ${widget.currentClass}',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const Spacer(),
              // Class dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BirdleColors.surface,
                  borderRadius: BirdleRadius.smBorder,
                  border: Border.all(color: BirdleColors.border),
                ),
                child: widget.isLoadingClasses
                    ? const Row(
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
                    : widget.classesError != null
                        ? InkWell(
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
                        : widget.availableClasses.isEmpty && widget.currentClass.isEmpty
                            ? const Text('Chưa có lớp', style: TextStyle(fontSize: 12.5, color: BirdleColors.textMuted, fontStyle: FontStyle.italic))
                            : DropdownButton<String>(
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
              ),
              const SizedBox(width: 10),
              BirdleSecondaryButton(
                icon: Icons.file_upload_outlined,
                label: 'Import',
                onPressed: widget.onGoToImport,
              ),
              const SizedBox(width: 8),
              BirdleSecondaryButton(
                icon: Icons.sync,
                label: 'Sync to Sheet',
                onPressed: widget.onSyncToSheet,
              ),
              const SizedBox(width: 8),
              BirdlePrimaryButton(
                icon: Icons.add,
                label: 'Add Student',
                onPressed: _showAddStudentDialog,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search Bar
          Row(
            children: [
              BirdleSearchField(
                controller: _searchController,
                hintText: 'Search student by ID or name...',
                width: 320,
                onChanged: (val) => setState(() => _search = val.trim()),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Data Table (Section 13 design.md)
          Expanded(
            child: BirdleCard(
              padding: EdgeInsets.zero,
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator(color: BirdleColors.brand, strokeWidth: 2))
                  : !widget.isSheetConfigured
                      ? BirdleEmptyState(
                          icon: Icons.link_off,
                          title: 'Chưa cấu hình Google Sheet Database',
                          description: 'Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt để đồng bộ danh sách sinh viên.',
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
                              title: 'Không thể tải danh sách sinh viên lớp ${widget.currentClass}',
                              description: widget.errorMessage!,
                              action: widget.onReload != null
                                  ? BirdlePrimaryButton(
                                      icon: Icons.refresh,
                                      label: 'Thử lại',
                                      onPressed: widget.onReload,
                                    )
                                  : null,
                            )
                          : widget.students.isEmpty
                              ? BirdleEmptyState(
                                  icon: Icons.people_outline,
                                  title: 'Chưa có sinh viên nào',
                                  description: 'Thêm sinh viên mới hoặc nhập danh sách từ FAP để bắt đầu quản lý.',
                                  action: BirdleSecondaryButton(
                                    icon: Icons.file_upload_outlined,
                                    label: 'Import từ FAP',
                                    onPressed: widget.onGoToImport,
                                  ),
                                )
                              : filtered.isEmpty
                                  ? const BirdleEmptyState(
                                      icon: Icons.search_off,
                                      title: 'Không tìm thấy sinh viên',
                                      description: 'Không có sinh viên nào khớp với điều kiện tìm kiếm hiện tại.',
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
                                                if (widget.onReload != null)
                                                  BirdleGhostButton(
                                                    icon: Icons.refresh,
                                                    label: 'Thử lại',
                                                    color: BirdleColors.danger,
                                                    onPressed: widget.onReload,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        // Table Header
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
                              Expanded(flex: 3, child: Text('EMAIL FPT', style: BirdleTypography.caption)),
                              SizedBox(width: 100, child: Text('SLOTS (VẮNG)', style: BirdleTypography.caption)),
                              SizedBox(width: 140, child: Text('ATTENDANCE RATE', style: BirdleTypography.caption)),
                              SizedBox(width: 124, child: Text('ACTIONS', style: BirdleTypography.caption)),
                            ],
                          ),
                        ),

                        // Rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              return Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.white,
                                child: Row(
                                  children: [
                                    SizedBox(width: 44, child: Text('${index + 1}', style: BirdleTypography.metadata)),
                                    SizedBox(
                                      width: 120,
                                      child: Text(s.member, style: BirdleTypography.bodyMedium),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(s.fullName, style: BirdleTypography.body),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(s.email, style: BirdleTypography.metadata),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text('${s.absentSlots}/${s.totalSlots}', style: BirdleTypography.body),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: AbsentRateBadge(rate: s.absentRate, student: s, showPercent: true),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 124,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.grid_view_rounded, size: 16, color: BirdleColors.brand),
                                              tooltip: 'Xem ma trận 20 slot',
                                              onPressed: () => StudentSlotsDialog.show(context, s),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, size: 16, color: BirdleColors.textSecondary),
                                              tooltip: 'Xem hồ sơ chi tiết',
                                              onPressed: () => _showStudentDetailDialog(s),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16, color: BirdleColors.danger),
                                              tooltip: 'Xóa khỏi lớp',
                                              onPressed: () {
                                                final updated = List<Student>.from(widget.students)..removeWhere((item) => item.member == s.member);
                                                widget.onUpdateStudents(updated);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
}
