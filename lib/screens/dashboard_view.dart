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
  final List<Map<String, dynamic>> todayClasses;
  final List<String> availableClasses;
  final ValueChanged<String>? onClassChanged;
  final void Function(String className, int slot)? onSelectClassAndSlot;
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
    this.todayClasses = const [],
    this.availableClasses = const [],
    this.onClassChanged,
    this.onSelectClassAndSlot,
    required this.onGoToAttendance,
    required this.onGoToFapSync,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final totalStudents = students.length;
    final presentCount = records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = records.where((r) => r.status == AttendanceStatus.absent).length;
    final notYetCount = records.where((r) => r.status == AttendanceStatus.notYet).length;

    // Sĩ số các nhóm chuyên cần theo chuẩn ĐH FPT (Quy chế vắng > 20% cấm thi)
    final bannedStudents = students.where((s) => s.isBanned).toList();
    final warningStudents = students.where((s) => !s.isBanned && (s.isWarning || s.hasExhaustedAbsenceAllowance)).toList();
    final safeStudents = students.where((s) => !s.isBanned && !s.isWarning && !s.hasExhaustedAbsenceAllowance).toList();

    // Tỷ lệ chuyên cần chung của toàn bộ lớp học (tránh chia cho 0)
    final totalClassSlots = students.fold<int>(0, (sum, s) => sum + s.totalSlots);
    final totalClassAbsent = students.fold<int>(0, (sum, s) => sum + s.absentSlots);
    final overallClassAttendanceRate = totalClassSlots > 0
        ? ((totalClassSlots - totalClassAbsent) / totalClassSlots) * 100
        : (students.isNotEmpty ? 100.0 : 0.0);

    // Tỷ lệ chuyên cần slot hôm nay
    final attendanceRate = totalStudents > 0
        ? (presentCount / totalStudents) * 100
        : 0.0;

    // Màu sắc động cho Tỷ lệ chuyên cần chung
    Color overallRateColor;
    if (overallClassAttendanceRate >= 85.0) {
      overallRateColor = BirdleColors.success;
    } else if (overallClassAttendanceRate >= 80.0) {
      overallRateColor = BirdleColors.warning;
    } else {
      overallRateColor = BirdleColors.danger;
    }

    final atRiskStudents = students.where((s) => s.absentRate >= 15.0 || s.hasExhaustedAbsenceAllowance).toList();
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
                      value: (availableClasses.contains(currentClass) || availableClasses.isEmpty) && currentClass.isNotEmpty
                          ? currentClass
                          : null,
                      hint: const Text('Chọn lớp', style: TextStyle(fontSize: 13, color: BirdleColors.textMuted)),
                      underline: const SizedBox(),
                      isDense: true,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: BirdleColors.textPrimary, fontSize: 13),
                      items: (availableClasses.isNotEmpty ? availableClasses : [currentClass])
                          .map((c) => DropdownMenuItem(value: c, child: Text('Lớp $c')))
                          .toList(),
                      onChanged: availableClasses.isNotEmpty && onClassChanged != null
                          ? (val) {
                              if (val != null) onClassChanged!(val);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

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

          // 4 Stat Cards Tổng quan chuyên cần chuẩn FPT
          Row(
            children: [
              _buildMetricCard(
                label: 'Tỷ lệ chuyên cần chung',
                value: '${overallClassAttendanceRate.toStringAsFixed(1)}%',
                subtitle: totalStudents > 0 ? 'Toàn bộ sinh viên lớp $currentClass' : 'Chưa có sinh viên',
                accentColor: overallRateColor,
                icon: Icons.pie_chart_outline,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                label: 'Sĩ số an toàn',
                value: '${safeStudents.length}',
                subtitle: 'Vắng ≤ 15% (${totalStudents > 0 ? ((safeStudents.length / totalStudents) * 100).toStringAsFixed(0) : 0}%)',
                accentColor: BirdleColors.success,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                label: 'Nguy cơ cấm thi',
                value: '${warningStudents.length}',
                subtitle: 'Vắng 15% - 20% (còn 0-1 buổi)',
                accentColor: BirdleColors.warning,
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                label: 'CẤM THI (> 20%)',
                value: '${bannedStudents.length}',
                subtitle: 'Vượt ngưỡng vắng FPT',
                accentColor: BirdleColors.danger,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Khối hiển thị Lịch dạy hôm nay theo chuẩn 4 Slot FPT
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: BirdleColors.brand),
                  const SizedBox(width: 8),
                  const Text('Lịch dạy hôm nay (Chuẩn 4 Slot FPT)', style: BirdleTypography.sectionTitle),
                  const Spacer(),
                  Text(
                    '${todayClasses.length} lớp có tiết',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (todayClasses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BirdleColors.surface,
                    borderRadius: BirdleRadius.mdBorder,
                    border: Border.all(color: BirdleColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'Hôm nay không có lớp nào có lịch dạy theo thời khóa biểu FPT (T2-T5 / T3-T6 / T4-T7).',
                      style: TextStyle(color: BirdleColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: todayClasses.map((c) {
                    final cName = c['className']?.toString() ?? '';
                    final slot = int.tryParse(c['slot']?.toString() ?? '1') ?? 1;
                    final slotTime = c['slotTime']?.toString() ?? ClassSession.getSlotTime(slot);
                    final isDone = c['isAttendanceDone'] == true;
                    final sessNo = c['sessionNumber'] ?? 1;
                    final totalStu = c['totalStudents'] ?? 0;
                    final room = c['room'] ?? 'BE-302';
                    final isSelected = cName == currentClass && slot == currentSlot;

                    return SizedBox(
                      width: 320,
                      child: BirdleCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: BirdleColors.brand.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Slot $slot',
                                    style: const TextStyle(
                                      color: BirdleColors.brand,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    slotTime,
                                    style: BirdleTypography.metadata,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isDone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: BirdleColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Đã điểm danh', style: TextStyle(color: BirdleColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: BirdleColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Chưa điểm danh', style: TextStyle(color: BirdleColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Lớp $cName · $room',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BirdleColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tiến độ: Buổi $sessNo/20 · $totalStu sinh viên',
                              style: BirdleTypography.metadata,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: isSelected
                                  ? BirdlePrimaryButton(
                                      label: 'Vào điểm danh ngay',
                                      icon: Icons.qr_code_scanner,
                                      onPressed: onGoToAttendance,
                                    )
                                  : BirdleSecondaryButton(
                                      label: 'Chọn lớp này',
                                      icon: Icons.arrow_forward,
                                      onPressed: () {
                                        if (onSelectClassAndSlot != null) {
                                          onSelectClassAndSlot!(cName, slot);
                                        }
                                        onGoToAttendance();
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
                    _buildStatItem('Chưa điểm danh', '$notYetCount', BirdleColors.textMuted),
                    _buildDivider(),
                    _buildStatItem('Có mặt (Present)', '$presentCount', BirdleColors.success),
                    _buildDivider(),
                    _buildStatItem('Vắng (Absent)', '$absentCount', BirdleColors.danger),
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
                        if (absentCount > 0)
                          Expanded(
                            flex: absentCount,
                            child: Container(color: BirdleColors.danger),
                          ),
                        if (notYetCount > 0)
                          Expanded(
                            flex: notYetCount,
                            child: Container(color: BirdleColors.surfaceSecondary),
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
                              'Ngưỡng cấm thi: > 20%',
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
                                    child: AbsentRateBadge(rate: s.absentRate, student: s, showPercent: false),
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

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
  }) {
    return Expanded(
      child: BirdleCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: BirdleTypography.metadata,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.8)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accentColor,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: BirdleTypography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
