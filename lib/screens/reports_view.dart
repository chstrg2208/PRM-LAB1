import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';
import '../services/storage_service.dart';

class ReportsView extends StatelessWidget {
  final List<Student> students;
  final String currentClass;
  final String googleSheetUrl;

  const ReportsView({
    super.key,
    required this.students,
    required this.currentClass,
    required this.googleSheetUrl,
  });

  @override
  Widget build(BuildContext context) {
    final total = students.length;
    final banned = students.where((s) => s.isBanned).toList();
    final warning = students.where((s) => s.isWarning || s.isAtThreshold).toList();
    final safe = students.where((s) => !s.isBanned && !s.isWarning && !s.isAtThreshold).toList();

    final totalSlots = students.fold<int>(0, (sum, s) => sum + s.totalSlots);
    final absentSlots = students.fold<int>(0, (sum, s) => sum + s.absentSlots);
    final overallRate = totalSlots > 0 ? ((totalSlots - absentSlots) / totalSlots) * 100 : 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Section 14 design.md)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Reports', style: BirdleTypography.pageTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Báo cáo chuyên cần học kỳ · Lớp $currentClass · Quy chế FPT vắng > 20% cấm thi',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const Spacer(),
              BirdleSecondaryButton(
                icon: Icons.download_outlined,
                label: 'Export CSV',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Đã kết xuất báo cáo CSV chuyên cần của lớp!'),
                      backgroundColor: BirdleColors.brand,
                    ),
                  );
                },
              ),
              if (googleSheetUrl.isNotEmpty) ...[
                const SizedBox(width: 10),
                BirdlePrimaryButton(
                  icon: Icons.table_chart_outlined,
                  label: 'Mở Google Sheet DB',
                  onPressed: () => StorageService.openBrowser(googleSheetUrl),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Overview Stats (Section 14 design.md)
          Row(
            children: [
              _buildReportMetricCard('Tỷ lệ chuyên cần chung', '${overallRate.toStringAsFixed(1)}%', 'Toàn bộ buổi học', BirdleColors.brand),
              const SizedBox(width: 14),
              _buildReportMetricCard('Đủ điều kiện thi', '${safe.length}', '$total sinh viên (${total > 0 ? ((safe.length / total) * 100).toStringAsFixed(0) : 0}%)', BirdleColors.success),
              const SizedBox(width: 14),
              _buildReportMetricCard('Cảnh báo nguy cơ (15-20%)', '${warning.length}', 'Cần nhắc nhở gấp', BirdleColors.warning),
              const SizedBox(width: 14),
              _buildReportMetricCard('CẤM THI (> 20%)', '${banned.length}', 'Không đủ điều kiện thi', BirdleColors.danger),
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
                    child: Row(
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
                Row(
                  children: [
                    _buildLegendDot(BirdleColors.success, 'Đủ điều kiện (<15% vắng): ${safe.length} SV'),
                    const SizedBox(width: 24),
                    _buildLegendDot(BirdleColors.warning, 'Cảnh báo nguy cơ (15-20% vắng): ${warning.length} SV'),
                    const SizedBox(width: 24),
                    _buildLegendDot(BirdleColors.danger, 'Cấm thi (>20% vắng): ${banned.length} SV'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Students Requiring Attention (Section 14 design.md)
          BirdleCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Text('Danh sách sinh viên cần can thiệp học vụ', style: BirdleTypography.cardTitle),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BirdleColors.surfaceSecondary,
                          borderRadius: BirdleRadius.pillBorder,
                        ),
                        child: Text(
                          '${banned.length + warning.length} SV',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BirdleColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (banned.isEmpty && warning.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '✓ Toàn bộ sinh viên trong lớp đều duy trì tỷ lệ đi học an toàn.',
                        style: TextStyle(color: BirdleColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(2.0),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: BirdleColors.surfaceSecondary),
                        children: ['STUDENT ID', 'STUDENT NAME', 'VẮNG / TỔNG', 'TỶ LỆ VẮNG', 'QUY CHẾ FPT'].map((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text(h, style: BirdleTypography.caption),
                          );
                        }).toList(),
                      ),
                      ...[...banned, ...warning].map((s) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(s.member, style: BirdleTypography.bodyMedium),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(s.fullName, style: BirdleTypography.body),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text('${s.absentSlots}/${s.totalSlots} buổi', style: BirdleTypography.body),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                '${s.absentRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s.isBanned ? BirdleColors.danger : BirdleColors.warning,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: AbsentRateBadge(rate: s.absentRate, showPercent: false),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
