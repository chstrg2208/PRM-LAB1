import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/csv_export_service.dart';
import '../theme/app_theme.dart';

typedef ReportExportCallback = Future<CsvExportResult> Function(String delimiter);

/// Hộp thoại xem trước tóm tắt thông số học vụ trước khi xuất báo cáo CSV 20 buổi
class ReportSummaryPreviewDialog extends StatefulWidget {
  final String className;
  final List<Student> students;
  final ReportExportCallback onConfirmExport;
  final String defaultDelimiter;

  const ReportSummaryPreviewDialog({
    super.key,
    required this.className,
    required this.students,
    required this.onConfirmExport,
    this.defaultDelimiter = ';',
  });

  static Future<CsvExportResult?> show({
    required BuildContext context,
    required String className,
    required List<Student> students,
    required ReportExportCallback onConfirmExport,
    String defaultDelimiter = ';',
  }) {
    return showDialog<CsvExportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReportSummaryPreviewDialog(
        className: className,
        students: students,
        onConfirmExport: onConfirmExport,
        defaultDelimiter: defaultDelimiter,
      ),
    );
  }

  @override
  State<ReportSummaryPreviewDialog> createState() => _ReportSummaryPreviewDialogState();
}

class _ReportSummaryPreviewDialogState extends State<ReportSummaryPreviewDialog> {
  bool _isExporting = false;
  String? _errorMessage;
  late String _selectedDelimiter;

  @override
  void initState() {
    super.initState();
    _selectedDelimiter = widget.defaultDelimiter;
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onConfirmExport(_selectedDelimiter);
      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _isExporting = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Lỗi trong quá trình xuất file: $e';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final totalStudents = widget.students.length;
    final bannedCount = widget.students.where((s) => s.isBanned).length;
    final atRiskCount = widget.students.where((s) => (s.isWarning || s.hasExhaustedAbsenceAllowance) && !s.isBanned).length;
    final perfectCount = widget.students.where((s) => s.absentSlots == 0).length;


    // Tỷ lệ chuyên cần trung bình
    double avgAttendance = 100.0;
    if (totalStudents > 0) {
      double totalPercent = 0;
      for (final s in widget.students) {
        totalPercent += (100.0 - s.absentRate);
      }
      avgAttendance = (totalPercent / totalStudents).clamp(0.0, 100.0);
    }

    final Color rateColor = avgAttendance >= 85.0
        ? BirdleColors.success
        : (avgAttendance >= 80.0 ? BirdleColors.warning : BirdleColors.danger);

    return PopScope(
      canPop: !_isExporting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: BirdleColors.surface,
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header với Icon bảng tính Excel xanh lá
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Color(0xFF107C41),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Xem trước Báo cáo Chuyên cần',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: BirdleColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Xác nhận thông số trước khi xuất file CSV / Excel 20 buổi',
                          style: TextStyle(
                            fontSize: 12,
                            color: BirdleColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isExporting)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: BirdleColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Đóng',
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Bảng tóm tắt thông số học vụ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BirdleColors.appBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BirdleColors.border),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      icon: Icons.school_outlined,
                      label: 'Lớp & Mã môn',
                      value: widget.className.isNotEmpty ? 'Lớp ${widget.className}' : 'Tất cả sinh viên',
                      valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: BirdleColors.brand),
                    ),
                    const Divider(height: 18, color: BirdleColors.border),
                    _buildSummaryRow(
                      icon: Icons.people_outline_rounded,
                      label: 'Sĩ số danh sách',
                      value: '$totalStudents sinh viên',
                    ),
                    const Divider(height: 18, color: BirdleColors.border),
                    _buildSummaryRow(
                      icon: Icons.pie_chart_outline_rounded,
                      label: 'Tỷ lệ chuyên cần chung',
                      value: '${avgAttendance.toStringAsFixed(1)}%',
                      valueColor: rateColor,
                      isBold: true,
                    ),
                    const Divider(height: 18, color: BirdleColors.border),
                    _buildSummaryRow(
                      icon: Icons.block_flipped,
                      label: 'Sinh viên Cấm thi (>20%)',
                      value: '$bannedCount sinh viên',
                      valueColor: bannedCount > 0 ? BirdleColors.danger : BirdleColors.success,
                      isBold: bannedCount > 0,
                    ),
                    if (atRiskCount > 0) ...[
                      const Divider(height: 18, color: BirdleColors.border),
                      _buildSummaryRow(
                        icon: Icons.warning_amber_rounded,
                        label: 'Cảnh báo nguy cơ (15-20%)',
                        value: '$atRiskCount sinh viên',
                        valueColor: BirdleColors.warning,
                      ),
                    ],
                    const Divider(height: 18, color: BirdleColors.border),
                    _buildSummaryRow(
                      icon: Icons.verified_outlined,
                      label: 'Chuyên cần tuyệt đối (100%)',
                      value: '$perfectCount sinh viên',
                      valueColor: BirdleColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bộ chọn dấu phân cách (Delimiter Selector)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BirdleColors.appBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BirdleColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: BirdleColors.brand),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dấu phân cách cột (Tương thích ứng dụng mở):',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: BirdleColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _isExporting ? null : () => setState(() => _selectedDelimiter = ';'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedDelimiter == ';'
                                    ? BirdleColors.brand.withValues(alpha: 0.12)
                                    : BirdleColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedDelimiter == ';' ? BirdleColors.brand : BirdleColors.border,
                                  width: _selectedDelimiter == ';' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedDelimiter == ';' ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 16,
                                    color: _selectedDelimiter == ';' ? BirdleColors.brand : BirdleColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Chấm phẩy ( ; )',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Excel Windows VN (Tự chia cột)',
                                          style: TextStyle(fontSize: 10.5, color: BirdleColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _isExporting ? null : () => setState(() => _selectedDelimiter = ','),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedDelimiter == ','
                                    ? BirdleColors.brand.withValues(alpha: 0.12)
                                    : BirdleColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedDelimiter == ',' ? BirdleColors.brand : BirdleColors.border,
                                  width: _selectedDelimiter == ',' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedDelimiter == ',' ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 16,
                                    color: _selectedDelimiter == ',' ? BirdleColors.brand : BirdleColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dấu phẩy ( , )',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Google Sheets / Mac / US',
                                          style: TextStyle(fontSize: 10.5, color: BirdleColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Thẻ ghi chú định dạng file xuất
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: BirdleColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BirdleColors.border),
                ),

                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: BirdleColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Định dạng xuất: 20 Buổi học (B1 → B20) · Bảng mã UTF-8 BOM chuẩn Excel · Thoát ký tự RFC 4180.',
                        style: TextStyle(fontSize: 11.5, color: BirdleColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: BirdleColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BirdleColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: BirdleColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: BirdleColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        color: _isExporting ? BirdleColors.textMuted : BirdleColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isExporting ? null : _handleExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF107C41).withValues(alpha: 0.6),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isExporting) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Đang xuất CSV...',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ] else ...[
                          const Icon(Icons.download_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Xác nhận tải về',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: BirdleColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: BirdleColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? BirdleColors.textPrimary,
              ),
        ),
      ],
    );
  }

}
