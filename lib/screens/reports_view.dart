import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_schedule.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';
import '../widgets/student_slots_dialog.dart';
import '../widgets/report_preview_dialog.dart';
import '../services/storage_service.dart';
import '../services/csv_export_service.dart';

class ReportsView extends StatefulWidget {
  final List<Student> students;
  final String currentClass;
  final String googleSheetUrl;
  final VoidCallback? onExportCsv;
  final bool isExporting;
  final ClassSchedule? schedule;
  final List<String> availableClasses;
  final List<AttendanceRecord> records;
  final List<Map<String, dynamic>>? historyLogs;
  final ValueChanged<String>? onClassChanged;
  final int currentSlot;
  final DateTime? currentDate;

  const ReportsView({
    super.key,
    required this.students,
    required this.currentClass,
    required this.googleSheetUrl,
    this.onExportCsv,
    this.isExporting = false,
    this.schedule,
    this.availableClasses = const [],
    this.records = const [],
    this.historyLogs,
    this.onClassChanged,
    this.currentSlot = 1,
    this.currentDate,
  });

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  // Bộ lọc sinh viên thông minh: 'all', 'banned', 'warning', 'perfect'
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final total = widget.students.length;
    final banned = widget.students.where((s) => s.isBanned).toList();
    final warning = widget.students.where((s) => !s.isBanned && (s.isWarning || s.hasExhaustedAbsenceAllowance)).toList();
    final safe = widget.students.where((s) => !s.isBanned && !s.isWarning && !s.hasExhaustedAbsenceAllowance).toList();
    final perfect = widget.students.where((s) => s.absentSlots == 0).toList();

    final totalSlots = widget.students.fold<int>(0, (sum, s) => sum + s.totalSlots);
    final absentSlots = widget.students.fold<int>(0, (sum, s) => sum + s.absentSlots);
    final overallRate = totalSlots > 0 ? ((totalSlots - absentSlots) / totalSlots) * 100 : (total > 0 ? 100.0 : 0.0);

    // Danh sách sau khi áp dụng Filter Chip
    List<Student> filteredStudents;
    switch (_selectedFilter) {
      case 'banned':
        filteredStudents = banned;
        break;
      case 'warning':
        filteredStudents = warning;
        break;
      case 'perfect':
        filteredStudents = perfect;
        break;
      case 'all':
      default:
        filteredStudents = widget.students;
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với Dropdown chọn lớp học & nút Export CSV
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance Reports', style: BirdleTypography.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Báo cáo chuyên cần học kỳ · Lớp ${widget.currentClass} · Quy chế FPT vắng > 20% cấm thi',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),

              // Class Dropdown Selector
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: BirdleColors.surface,
                  borderRadius: BirdleRadius.smBorder,
                  border: Border.all(color: BirdleColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 17, color: BirdleColors.brand),
                    const SizedBox(width: 8),
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
                      onChanged: widget.availableClasses.isNotEmpty && widget.onClassChanged != null
                          ? (val) {
                              if (val != null) widget.onClassChanged!(val);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              BirdleSecondaryButton(
                icon: Icons.download_outlined,
                label: widget.isExporting ? 'Đang xuất CSV...' : 'Export CSV',
                isLoading: widget.isExporting,
                onPressed: widget.onExportCsv ??
                    () async {
                      if (widget.students.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chưa có dữ liệu sinh viên để xuất báo cáo.'),
                            backgroundColor: BirdleColors.warning,
                          ),
                        );
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final res = await ReportSummaryPreviewDialog.show(
                        context: context,
                        className: widget.currentClass,
                        students: widget.students,
                        onConfirmExport: (delimiter) => CsvExportService.exportToFile(
                          students: widget.students,
                          className: widget.currentClass,
                          delimiter: delimiter,
                        ),
                      );

                      if (!mounted || res == null) return;

                      final msg = res.success && res.filePath != null
                          ? '${res.message} (${res.filePath})'
                          : res.message;

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: res.success ? BirdleColors.brand : BirdleColors.danger,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
              ),


              if (widget.googleSheetUrl.isNotEmpty) ...[
                const SizedBox(width: 10),
                BirdlePrimaryButton(
                  icon: Icons.table_chart_outlined,
                  label: 'Mở Google Sheet DB',
                  onPressed: () => StorageService.openBrowser(widget.googleSheetUrl),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Overview Stats (4 Cards)
          Row(
            children: [
              _buildReportMetricCard(
                'Tỷ lệ chuyên cần chung',
                '${overallRate.toStringAsFixed(1)}%',
                'Toàn bộ buổi học',
                overallRate >= 85 ? BirdleColors.success : (overallRate >= 80 ? BirdleColors.warning : BirdleColors.danger),
              ),
              const SizedBox(width: 14),
              _buildReportMetricCard(
                'Đủ điều kiện thi',
                '${safe.length}',
                '$total sinh viên (${total > 0 ? ((safe.length / total) * 100).toStringAsFixed(0) : 0}%)',
                BirdleColors.success,
              ),
              const SizedBox(width: 14),
              _buildReportMetricCard(
                'Cảnh báo nguy cơ (15-20%)',
                '${warning.length}',
                'Cần nhắc nhở gấp',
                BirdleColors.warning,
              ),
              const SizedBox(width: 14),
              _buildReportMetricCard(
                'CẤM THI (> 20%)',
                '${banned.length}',
                'Không đủ điều kiện thi',
                BirdleColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Absence Distribution & Progress Bar
          BirdleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phân bố tình trạng chuyên cần lớp học', style: BirdleTypography.cardTitle),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 10,
                    child: total == 0
                        ? Container(color: BirdleColors.surfaceSecondary)
                        : Row(
                            children: [
                              if (safe.isNotEmpty)
                                Expanded(
                                  flex: safe.length,
                                  child: Container(color: BirdleColors.success),
                                ),
                              if (warning.isNotEmpty)
                                Expanded(
                                  flex: warning.length,
                                  child: Container(color: BirdleColors.warning),
                                ),
                              if (banned.isNotEmpty)
                                Expanded(
                                  flex: banned.length,
                                  child: Container(color: BirdleColors.danger),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _buildLegendDot(BirdleColors.success, 'Đủ điều kiện (<15% vắng): ${safe.length} SV'),
                    _buildLegendDot(BirdleColors.warning, 'Cảnh báo nguy cơ (15-20% vắng): ${warning.length} SV'),
                    _buildLegendDot(BirdleColors.danger, 'Cấm thi (>20% vắng): ${banned.length} SV'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Section: Báo cáo chi tiết & Ma trận 20 buổi học FPT
          BirdleCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar & Bộ lọc nhanh 1 chạm (Filter Chips)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_on_rounded, size: 20, color: BirdleColors.brand),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ma trận Điểm danh 20 Buổi học (B1 ➔ B20)',
                              style: BirdleTypography.cardTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Legend cho 20 Slot
                          Wrap(
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildSlotLegendItem(BirdleColors.successLight, BirdleColors.success, 'Có mặt (P)'),
                              _buildSlotLegendItem(BirdleColors.dangerLight, BirdleColors.danger, 'Vắng (A)'),
                              _buildSlotLegendItem(BirdleColors.warningLight, BirdleColors.warning, 'Muộn (L)'),
                              _buildSlotLegendItem(const Color(0xFFF1F5F9), const Color(0xFF94A3B8), 'Chưa học (-)'),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Hàng Filter Chips 1 chạm
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            id: 'all',
                            label: 'Tất cả sinh viên',
                            count: total,
                            icon: Icons.people_outline,
                            activeColor: BirdleColors.brand,
                          ),
                          _buildFilterChip(
                            id: 'banned',
                            label: 'Cấm thi (>20%)',
                            count: banned.length,
                            icon: Icons.cancel_outlined,
                            activeColor: BirdleColors.danger,
                          ),
                          _buildFilterChip(
                            id: 'warning',
                            label: 'Cảnh báo nguy cơ',
                            count: warning.length,
                            icon: Icons.warning_amber_outlined,
                            activeColor: BirdleColors.warning,
                          ),
                          _buildFilterChip(
                            id: 'perfect',
                            label: 'Chuyên cần 100%',
                            count: perfect.length,
                            icon: Icons.star_outline_rounded,
                            activeColor: BirdleColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Nội dung Bảng: Ma trận 20 buổi hoặc Empty State
                if (filteredStudents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: _selectedFilter == 'banned' || _selectedFilter == 'warning'
                                  ? BirdleColors.successLight
                                  : BirdleColors.surfaceSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedFilter == 'banned' || _selectedFilter == 'warning'
                                  ? Icons.verified_outlined
                                  : Icons.inbox_outlined,
                              size: 28,
                              color: _selectedFilter == 'banned' || _selectedFilter == 'warning'
                                  ? BirdleColors.success
                                  : BirdleColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _getEmptyFilterTitle(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: BirdleColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getEmptyFilterSubtitle(),
                            style: const TextStyle(fontSize: 12.5, color: BirdleColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Bọc ngang SingleChildScrollView để chống tràn 100% trên mọi kích thước màn hình
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1220),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(BirdleColors.surfaceSecondary),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 16,
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('MSSV', style: BirdleTypography.caption)),
                          DataColumn(label: Text('HỌ VÀ TÊN', style: BirdleTypography.caption)),
                          DataColumn(
                            label: Text(
                              'LỘ TRÌNH 20 BUỔI HỌC (B1 ➔ B20)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BirdleColors.brand,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          DataColumn(label: Text('VẮNG / TỔNG', style: BirdleTypography.caption)),
                          DataColumn(label: Text('TỶ LỆ VẮNG', style: BirdleTypography.caption)),
                          DataColumn(label: Text('QUY CHẾ FPT', style: BirdleTypography.caption)),
                          DataColumn(label: Text('CHI TIẾT', style: BirdleTypography.caption)),
                        ],
                        rows: filteredStudents.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(s.member, style: BirdleTypography.bodyMedium),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    s.fullName,
                                    style: BirdleTypography.body,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Cột Ma trận 20 Buổi Học: 20 ô nhỏ mini-grid kích thước cố định 24x24px
                              DataCell(
                                SizedBox(
                                  width: 560,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(20, (slotIdx) {
                                      final slotNum = slotIdx + 1;
                                      final rawStatus = s.getSlot20Status(slotNum).trim().toUpperCase();
                                      return _buildMiniSlotCell(slotNum, rawStatus);
                                    }),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text('${s.absentSlots}/${s.totalSlots} buổi', style: BirdleTypography.body),
                              ),
                              DataCell(
                                Text(
                                  '${s.absentRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: s.isBanned
                                        ? BirdleColors.danger
                                        : (s.isWarning || s.hasExhaustedAbsenceAllowance ? BirdleColors.warning : BirdleColors.success),
                                  ),
                                ),
                              ),
                              DataCell(
                                AbsentRateBadge(rate: s.absentRate, student: s, showPercent: false),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: BirdleColors.brand),
                                  tooltip: 'Mở chi tiết 20 slot của ${s.fullName}',
                                  splashRadius: 18,
                                  onPressed: () => StudentSlotsDialog.show(context, s),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedFilter == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = id),
        borderRadius: BirdleRadius.pillBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : BirdleColors.surfaceSecondary,
            borderRadius: BirdleRadius.pillBorder,
            border: Border.all(
              color: isSelected ? activeColor : BirdleColors.border,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: isSelected ? activeColor : BirdleColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : BirdleColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : BirdleColors.border,
                  borderRadius: BirdleRadius.pillBorder,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : BirdleColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSlotCell(int slotNum, String rawStatus) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFE2E8F0);
    Color text = const Color(0xFF94A3B8);
    String symbol = '-';
    String tooltipMsg = 'Buổi $slotNum: Chưa học (-)';

    if (rawStatus == 'P' || rawStatus == 'CÓ MẶT' || rawStatus == 'PRESENT') {
      bg = BirdleColors.successLight;
      border = BirdleColors.success.withValues(alpha: 0.4);
      text = BirdleColors.success;
      symbol = 'P';
      tooltipMsg = 'Buổi $slotNum: Có mặt (P)';
    } else if (rawStatus == 'A' || rawStatus == 'VẮNG' || rawStatus == 'ABSENT') {
      bg = BirdleColors.dangerLight;
      border = BirdleColors.danger.withValues(alpha: 0.6);
      text = BirdleColors.danger;
      symbol = 'A';
      tooltipMsg = 'Buổi $slotNum: VẮNG (A)';
    } else if (rawStatus == 'L' || rawStatus == 'MUỘN' || rawStatus == 'LATE') {
      bg = BirdleColors.warningLight;
      border = BirdleColors.warning.withValues(alpha: 0.5);
      text = BirdleColors.warning;
      symbol = 'L';
      tooltipMsg = 'Buổi $slotNum: Đi muộn (L)';
    }

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotLegendItem(Color bg, Color text, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: text.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            label.contains('(P)') ? 'P' : (label.contains('(A)') ? 'A' : (label.contains('(L)') ? 'L' : '-')),
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: text),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: BirdleColors.textSecondary)),
      ],
    );
  }

  String _getEmptyFilterTitle() {
    switch (_selectedFilter) {
      case 'banned':
        return 'Tuyệt vời! Không có sinh viên nào bị Cấm thi.';
      case 'warning':
        return 'Không có sinh viên nào trong diện Cảnh báo nguy cơ.';
      case 'perfect':
        return 'Chưa có sinh viên nào đi học đủ 100% các buổi.';
      default:
        return 'Không có sinh viên nào trong danh sách.';
    }
  }

  String _getEmptyFilterSubtitle() {
    switch (_selectedFilter) {
      case 'banned':
        return 'Toàn bộ sinh viên đều duy trì tỷ lệ vắng trong ngưỡng cho phép (≤ 20%).';
      case 'warning':
        return 'Tất cả sinh viên đều an toàn và chưa chạm mốc nguy cơ 15% - 20%.';
      case 'perfect':
        return 'Các bạn sinh viên đều có ít nhất 1 buổi vắng trong kỳ học.';
      default:
        return 'Vui lòng kiểm tra lại cấu hình lớp hoặc chuyển bộ lọc khác.';
    }
  }

  Widget _buildReportMetricCard(String label, String value, String subtitle, Color accentColor) {
    return Expanded(
      child: BirdleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: BirdleTypography.metadata),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: BirdleTypography.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: BirdleTypography.metadata),
      ],
    );
  }
}

