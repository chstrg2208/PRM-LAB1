import 'package:flutter/material.dart';
import '../models/student.dart';
import '../widgets/status_badge.dart';
import '../widgets/import_fap_dialog.dart';

class StudentsView extends StatefulWidget {
  final List<Student> students;
  final String currentClass;
  final Function(List<Student>) onUpdateStudents;
  final Function(String) onClassChanged;
  final VoidCallback onSyncToSheet;

  const StudentsView({
    super.key,
    required this.students,
    required this.currentClass,
    required this.onUpdateStudents,
    required this.onClassChanged,
    required this.onSyncToSheet,
  });

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  void _showAddStudentDialog() {
    final memberCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final middleNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm sinh viên mới (4-5 trường chuẩn)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: memberCtrl,
                decoration: const InputDecoration(
                  labelText: 'MEMBER (Mã SV)',
                  hintText: 'Ví dụ: CE190585 hoặc SE170123',
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && emailCtrl.text.isEmpty) {
                    emailCtrl.text = '${val.toLowerCase()}@fpt.edu.vn';
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CODE (Họ)',
                        hintText: 'Ví dụ: Lâm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: surnameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SURNAME (Đệm)',
                        hintText: 'Ví dụ: Quốc',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: middleNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'MIDDLE NAME / GIVEN NAME (Tên)',
                  hintText: 'Ví dụ: Minh',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email FPT',
                  hintText: 'Ví dụ: minhlqce190585@fpt.edu.vn',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF36F21),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final member = memberCtrl.text.trim().toUpperCase();
              final code = codeCtrl.text.trim();
              final surname = surnameCtrl.text.trim();
              final middleName = middleNameCtrl.text.trim();

              if (member.isNotEmpty) {
                final newStudents = List<Student>.from(widget.students);
                newStudents.add(
                  Student(
                    member: member,
                    code: code,
                    surname: surname,
                    middleName: middleName,
                    email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : '${member.toLowerCase()}@fpt.edu.vn',
                    className: widget.currentClass,
                    totalSlots: 20,
                    absentSlots: 0,
                  ),
                );
                widget.onUpdateStudents(newStudents);
                Navigator.pop(context);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _deleteStudent(Student student) {
    final newStudents = widget.students.where((s) => s.rollNumber != student.rollNumber).toList();
    widget.onUpdateStudents(newStudents);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students.where((s) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.rollNumber.toLowerCase().contains(q) || s.fullName.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.school, color: Color(0xFFF36F21)),
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
                Text(
                  'Tổng sĩ số: ${widget.students.length} sinh viên',
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                const Spacer(),

                // Buttons
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Nhập từ FAP'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ImportFapDialog(
                        currentClass: widget.currentClass,
                        onImport: (imported) {
                          final existingRolls = widget.students.map((s) => s.rollNumber).toSet();
                          final newOnes = imported.where((s) => !existingRolls.contains(s.rollNumber)).toList();
                          widget.onUpdateStudents([...widget.students, ...newOnes]);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Đồng bộ lên Google Sheet'),
                  onPressed: widget.onSyncToSheet,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF36F21),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Thêm sinh viên'),
                  onPressed: _showAddStudentDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Search bar
          Row(
            children: [
              SizedBox(
                width: 320,
                height: 42,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Tìm kiếm MSSV, tên...',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _search = val.trim();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Students List Table
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
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFFF2E8),
                        child: Text(
                          student.rollNumber.substring(0, 2),
                          style: const TextStyle(
                            color: Color(0xFFF36F21),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${student.rollNumber} - ${student.fullName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${student.email} • Tổng buổi: ${student.totalSlots} • Vắng: ${student.absentSlots}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AbsentRateBadge(rate: student.absentRate),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'Xóa sinh viên',
                            onPressed: () => _deleteStudent(student),
                          ),
                        ],
                      ),
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
}
