import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';

class DashboardView extends StatelessWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final int currentSlot;
  final DateTime currentDate;
  final bool isSheetConnected;
  final VoidCallback onGoToAttendance;
  final VoidCallback onGoToFapSync;
  final VoidCallback onGoToSettings;

  const DashboardView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.currentSlot,
    required this.currentDate,
    required this.isSheetConnected,
    required this.onGoToAttendance,
    required this.onGoToFapSync,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final totalStudents = students.length;
    final presentCount = records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount = records.where((r) => r.status == AttendanceStatus.late).length;
    final pendingCount = totalStudents - (presentCount + absentCount + lateCount);

    final attendanceRate = totalStudents > 0
        ? ((presentCount + (lateCount * 0.7)) / totalStudents) * 100
        : 0.0;

    final atRiskStudents = students.where((s) => s.absentRate >= 15.0).toList();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(currentDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 11 Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Good morning', style: BirdleTypography.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Attendance workspace · $formattedDate',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),
              BirdleSecondaryButton(
                icon: Icons.file_upload_outlined,
                label: 'Import from FAP',
                onPressed: onGoToFapSync,
              ),
              const SizedBox(width: 10),
              BirdlePrimaryButton(
                icon: Icons.fact_check_outlined,
                label: "Open Today's Attendance",
                onPressed: onGoToAttendance,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // One Strong Summary Block: Today's Attendance (Section 11 design.md)
          BirdleCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Attendance", style: BirdleTypography.cardTitle),
                        const SizedBox(height: 3),
                        Text(
                          '$currentClass · Slot $currentSlot (${ClassSession.getSlotTime(currentSlot)})',
                          style: BirdleTypography.metadata,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BirdleColors.brandLight,
                        borderRadius: BirdleRadius.pillBorder,
                      ),
                      child: Text(
                        'Tỷ lệ: ${attendanceRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BirdleColors.brand,
                          fontFamily: BirdleTypography.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Numbers strip
                Row(
                  children: [
                    _buildStatItem('Tổng sinh viên', '$totalStudents', null),
                    _buildDivider(),
                    _buildStatItem('Có mặt (Present)', '$presentCount', BirdleColors.success),
                    _buildDivider(),
                    _buildStatItem('Vắng (Absent)', '$absentCount', BirdleColors.danger),
                    _buildDivider(),
                    _buildStatItem('Muộn (Late)', '$lateCount', BirdleColors.warning),
                    _buildDivider(),
                    _buildStatItem('Chưa điểm danh', '${pendingCount < 0 ? 0 : pendingCount}', BirdleColors.textMuted),
                  ],
                ),
                const SizedBox(height: 20),

                // Visual distribution bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (presentCount > 0)
                          Expanded(
                            flex: presentCount,
                            child: Container(color: BirdleColors.success),
                          ),
                        if (lateCount > 0)
                          Expanded(
                            flex: lateCount,
                            child: Container(color: BirdleColors.warning),
                          ),
                        if (absentCount > 0)
                          Expanded(
                            flex: absentCount,
                            child: Container(color: BirdleColors.danger),
                          ),
                        if (pendingCount > 0)
                          Expanded(
                            flex: pendingCount,
                            child: Container(color: BirdleColors.pending.withValues(alpha: 0.3)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-column layout: Recent Activity & Students Requiring Attention
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Students Requiring Attention (Section 11 design.md)
              Expanded(
                flex: 3,
                child: BirdleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Students Requiring Attention',
                                      overflow: TextOverflow.ellipsis,
                                      style: BirdleTypography.cardTitle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BirdleColors.dangerLight,
                                      borderRadius: BirdleRadius.pillBorder,
                                    ),
                                    child: Text(
                                      '${atRiskStudents.length}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BirdleColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ngưỡng cấm thi: >= 20%',
                              style: BirdleTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      if (students.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              isSheetConnected
                                  ? 'Chưa có dữ liệu sinh viên cho lớp $currentClass.'
                                  : 'Chưa cấu hình Google Sheet Database.',
                              style: const TextStyle(color: BirdleColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else if (atRiskStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '✓ Tất cả sinh viên đang duy trì chuyên cần tốt (dưới 15% vắng).',
                              style: TextStyle(color: BirdleColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.2),
                            1: FlexColumnWidth(2.2),
                            2: FlexColumnWidth(1.4),
                            3: FlexColumnWidth(1.5),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: BirdleColors.surfaceSecondary),
                              children: ['STUDENT ID', 'STUDENT', 'ABSENT RATE', 'STATUS'].map((h) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(h, style: BirdleTypography.caption),
                                );
                              }).toList(),
                            ),
                            ...atRiskStudents.map((s) {
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
                                    child: Text(
                                      '${s.absentSlots}/${s.totalSlots} (${s.absentRate.toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                        color: s.isBanned ? BirdleColors.danger : BirdleColors.warning,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
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
              ),
              const SizedBox(width: 20),

              // Right: Recent Activity (Section 11 design.md)
              Expanded(
                flex: 2,
                child: BirdleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Activity', style: BirdleTypography.cardTitle),
                      const SizedBox(height: 16),
                      _buildActivityItem(
                        Icons.sync,
                        'Imported attendance from FAP',
                        'Lớp $currentClass · Slot $currentSlot',
                        'Today · 09:42',
                      ),
                      const SizedBox(height: 14),
                      _buildActivityItem(
                        Icons.table_chart_outlined,
                        'Attendance synced to Google Sheets',
                        'Đã lưu ${records.length} bản ghi điểm danh',
                        'Today · 09:47',
                      ),
                      const SizedBox(height: 14),
                      _buildActivityItem(
                        Icons.insights_outlined,
                        'AI analysis generated',
                        'Phát hiện xu hướng vắng Slot $currentSlot',
                        'Today · 09:49',
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            isSheetConnected ? Icons.cloud_done : Icons.cloud_off,
                            size: 16,
                            color: isSheetConnected ? BirdleColors.brand : BirdleColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSheetConnected ? 'Google Sheet DB Connected' : 'Google Sheet Unconfigured',
                              style: BirdleTypography.metadata,
                            ),
                          ),
                          BirdleGhostButton(
                            label: 'Cài đặt',
                            onPressed: onGoToSettings,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color? color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, overflow: TextOverflow.ellipsis, style: BirdleTypography.metadata),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color ?? BirdleColors.textPrimary,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: BirdleColors.border,
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String subtitle, String timestamp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: BirdleColors.surfaceSecondary,
            borderRadius: BirdleRadius.smBorder,
          ),
          child: Icon(icon, size: 16, color: BirdleColors.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BirdleTypography.bodyMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: BirdleTypography.metadata),
            ],
          ),
        ),
        Text(timestamp, style: BirdleTypography.caption),
      ],
    );
  }
}
