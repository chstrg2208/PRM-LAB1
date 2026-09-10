import 'package:flutter/material.dart';
import '../models/student.dart';
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
    final bannedStudents = students.where((s) => s.isBanned).toList();
    final warningStudents = students.where((s) => s.isWarning).toList();
    final safeStudents = students.where((s) => !s.isBanned && !s.isWarning).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo Cáo Chuyên Cần Toàn Kỳ - Lớp $currentClass',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quy định ĐH FPT: Vắng mặt quá 20% tổng số buổi sẽ không đủ điều kiện thi kết thúc môn',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                if (googleSheetUrl.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Mở Google Sheet DB'),
                    onPressed: () {
                      StorageService.openBrowser(googleSheetUrl);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overview Status Cards
          Row(
            children: [
              Expanded(
                child: _buildReportCard(
                  title: 'Đủ điều kiện thi',
                  count: '${safeStudents.length}',
                  percentage: students.isNotEmpty ? '${((safeStudents.length / students.length) * 100).toStringAsFixed(0)}%' : '0%',
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildReportCard(
                  title: 'Cảnh báo vắng (15-20%)',
                  count: '${warningStudents.length}',
                  percentage: students.isNotEmpty ? '${((warningStudents.length / students.length) * 100).toStringAsFixed(0)}%' : '0%',
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildReportCard(
                  title: 'Bị cấm thi (>=20%)',
                  count: '${bannedStudents.length}',
                  percentage: students.isNotEmpty ? '${((bannedStudents.length / students.length) * 100).toStringAsFixed(0)}%' : '0%',
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                  icon: Icons.dangerous_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Detailed Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: SizedBox(
                        width: 30,
                        child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      title: Text(
                        '${s.rollNumber} - ${s.fullName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Đã học: ${s.totalSlots} slot | Có mặt: ${s.totalSlots - s.absentSlots} slot | Vắng: ${s.absentSlots} slot',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: AbsentRateBadge(rate: s.absentRate),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String count,
    required String percentage,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('($percentage)', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
