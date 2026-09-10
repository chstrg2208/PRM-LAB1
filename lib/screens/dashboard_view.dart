import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../widgets/status_badge.dart';

class DashboardView extends StatelessWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final int currentSlot;
  final DateTime currentDate;
  final bool isSheetConnected;
  final VoidCallback onGoToAttendance;
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
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final totalStudents = students.length;
    final presentCount = records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount = records.where((r) => r.status == AttendanceStatus.late).length;

    final attendancePercentage = totalStudents > 0 ? ((presentCount + lateCount) / totalStudents) * 100 : 0.0;
    final atRiskStudents = students.where((s) => s.absentRate >= 15.0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF36F21),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'PRM392 / PRM393 - FPT UNIVERSITY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSheetConnected ? const Color(0xFF10B981).withAlpha(50) : Colors.amber.withAlpha(50),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSheetConnected ? const Color(0xFF10B981) : Colors.amber,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: isSheetConnected ? const Color(0xFF10B981) : Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSheetConnected ? 'Google Sheet: Đã kết nối' : 'Google Sheet: Cần cấu hình',
                                  style: TextStyle(
                                    color: isSheetConnected ? const Color(0xFF10B981) : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hệ Thống Điểm Danh FAP - Google Sheet DB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quản lý chuyên cần lớp $currentClass • Slot $currentSlot • Ngày ${currentDate.day}/${currentDate.month}/${currentDate.year}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF36F21),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Bắt đầu Điểm danh ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: onGoToAttendance,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Tổng sinh viên',
                  value: '$totalStudents',
                  subtitle: 'Lớp $currentClass',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Có mặt hôm nay',
                  value: '$presentCount',
                  subtitle: '${attendancePercentage.toStringAsFixed(0)}% chuyên cần',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Vắng mặt',
                  value: '$absentCount',
                  subtitle: '$lateCount đi muộn',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Nguy cơ cấm thi',
                  value: '${atRiskStudents.length}',
                  subtitle: 'Vắng >= 15% tổng slot',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Section: At Risk Students & Fast Access
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // At Risk Students Table
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cảnh báo chuyên cần (Quy chế FPT > 20% vắng)',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${atRiskStudents.length} sinh viên',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (atRiskStudents.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.thumb_up_alt_outlined, color: Colors.green.shade400, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Tuyệt vời! Không có sinh viên nào có nguy cơ bị cấm thi.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: atRiskStudents.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = atRiskStudents[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: s.isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                                child: Text(
                                  s.rollNumber.substring(0, 2),
                                  style: TextStyle(
                                    color: s.isBanned ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text('${s.rollNumber} - ${s.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Đã vắng ${s.absentSlots}/${s.totalSlots} buổi học'),
                              trailing: AbsentRateBadge(rate: s.absentRate),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Quick Actions & Setup Card
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thao tác nhanh',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActionButton(
                        icon: Icons.flash_on,
                        title: 'Đồng bộ FAP nhanh',
                        subtitle: 'Tự động tích chọn Present/Absent',
                        color: const Color(0xFFF36F21),
                        onTap: onGoToAttendance,
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActionButton(
                        icon: Icons.cloud_sync_outlined,
                        title: 'Kết nối Google Sheet DB',
                        subtitle: 'Đọc/ghi dữ liệu bảng tính đám mây',
                        color: const Color(0xFF059669),
                        onTap: onGoToSettings,
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActionButton(
                        icon: Icons.table_chart_outlined,
                        title: 'Quản lý danh sách lớp',
                        subtitle: 'Nhập từ FAP hoặc cập nhật SV',
                        color: const Color(0xFF2563EB),
                        onTap: onGoToAttendance,
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
