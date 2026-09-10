import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../widgets/status_badge.dart';
import '../widgets/fap_sync_dialog.dart';
import '../widgets/import_fap_dialog.dart';

class AttendanceView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
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
  final Function(List<Student>) onImportStudents;

  const AttendanceView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.currentSlot,
    required this.currentDate,
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
    required this.onImportStudents,
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.rollNumber.toLowerCase().contains(q) || s.fullName.toLowerCase().contains(q);
    }).toList();

    final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount = widget.records.where((r) => r.status == AttendanceStatus.late).length;

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Control Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // Class Selector
                const Icon(Icons.school_outlined, color: Color(0xFFF36F21)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.currentClass,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                  items: ['SE1801', 'SE1802', 'SE1803', 'IA1801', 'PRM392-Lab']
                      .map((c) => DropdownMenuItem(value: c, child: Text('Lớp $c')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) widget.onClassChanged(val);
                  },
                ),
                const SizedBox(width: 24),

                // Date Picker
                const Icon(Icons.calendar_today_outlined, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(widget.currentDate),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Slot Selector
                const Icon(Icons.access_time, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: widget.currentSlot,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                  items: List.generate(6, (i) => i + 1)
                      .map(
                        (slot) => DropdownMenuItem(
                          value: slot,
                          child: Text('Slot $slot (${ClassSession.getSlotTime(slot)})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) widget.onSlotChanged(val);
                  },
                ),

                const Spacer(),

                // Action Buttons Toolbar
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Nhập từ FAP'),
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
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Tải từ Sheet'),
                  onPressed: widget.onReloadFromSheet,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Lưu vào Google Sheet'),
                  onPressed: widget.onSaveToSheet,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF36F21),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.bolt, size: 20),
                  label: const Text('Đồng bộ lên FAP', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
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

          // Quick Summary & Batch Actions Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Text('Sĩ số: ${widget.students.length}   |   ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Có mặt: $presentCount  ', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                    Text('Vắng: $absentCount  ', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    Text('Muộn: $lateCount', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              TextButton.icon(
                icon: const Icon(Icons.done_all, color: Color(0xFF059669), size: 18),
                label: const Text('Tất cả có mặt', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                onPressed: widget.onMarkAllPresent,
              ),
              TextButton.icon(
                icon: const Icon(Icons.close, color: Color(0xFFDC2626), size: 18),
                label: const Text('Tất cả vắng', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                onPressed: widget.onMarkAllAbsent,
              ),

              const Spacer(),

              // Search box
              SizedBox(
                width: 260,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Tìm theo MSSV hoặc Tên...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Attendance Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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

                          return _buildStudentRow(student, record, index + 1);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Student student, AttendanceRecord record, int stt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: record.status == AttendanceStatus.absent ? const Color(0xFFFEF2F2).withAlpha(80) : Colors.transparent,
      child: Row(
        children: [
          // STT
          SizedBox(
            width: 32,
            child: Text(
              '$stt',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFF2E8),
            child: Text(
              student.rollNumber.substring(0, 2),
              style: const TextStyle(
                color: Color(0xFFF36F21),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info (RollNumber + Name)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      student.rollNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 8),
                    AbsentRateBadge(rate: student.absentRate),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  student.fullName,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),

          // 3-State Toggle Buttons (Có mặt / Vắng / Muộn)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusOption(
                  label: 'Có mặt',
                  icon: Icons.check,
                  isSelected: record.status == AttendanceStatus.present,
                  activeColor: const Color(0xFF059669),
                  activeBg: const Color(0xFFD1FAE5),
                  onTap: () => widget.onStatusChanged(student.rollNumber, AttendanceStatus.present),
                ),
                const SizedBox(width: 8),
                _buildStatusOption(
                  label: 'Vắng',
                  icon: Icons.close,
                  isSelected: record.status == AttendanceStatus.absent,
                  activeColor: const Color(0xFFDC2626),
                  activeBg: const Color(0xFFFEE2E2),
                  onTap: () => widget.onStatusChanged(student.rollNumber, AttendanceStatus.absent),
                ),
                const SizedBox(width: 8),
                _buildStatusOption(
                  label: 'Muộn',
                  icon: Icons.access_time,
                  isSelected: record.status == AttendanceStatus.late,
                  activeColor: const Color(0xFFD97706),
                  activeBg: const Color(0xFFFEF3C7),
                  onTap: () => widget.onStatusChanged(student.rollNumber, AttendanceStatus.late),
                ),
              ],
            ),
          ),

          // Note Field
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 36,
              child: TextFormField(
                initialValue: record.note,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Ghi chú...',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (val) => widget.onNoteChanged(student.rollNumber, val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
