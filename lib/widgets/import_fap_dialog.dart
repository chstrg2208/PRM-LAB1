import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/fap_service.dart';

class ImportFapDialog extends StatefulWidget {
  final String currentClass;
  final Function(List<Student>) onImport;

  const ImportFapDialog({
    super.key,
    required this.currentClass,
    required this.onImport,
  });

  @override
  State<ImportFapDialog> createState() => _ImportFapDialogState();
}

class _ImportFapDialogState extends State<ImportFapDialog> {
  final TextEditingController _textController = TextEditingController();
  List<Student> _parsedStudents = [];
  bool _hasParsed = false;

  void _parse() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final result = FapService.parseStudentList(text, widget.currentClass);
    setState(() {
      _parsedStudents = result;
      _hasParsed = true;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập danh sách từ FAP (Lớp ${widget.currentClass})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dán mã nguồn HTML trang FAP hoặc danh sách sinh viên có Mã SV (SE..., HE...)',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: 'Dán nội dung bảng FAP vào đây...\nVí dụ:\n1  SE170123  Nguyễn Văn An\n2  SE170456  Trần Thị Bình\n...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (_) {
                if (_hasParsed) {
                  setState(() {
                    _hasParsed = false;
                    _parsedStudents = [];
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('Phân tích dữ liệu'),
                  onPressed: _parse,
                ),
                const SizedBox(width: 12),
                if (_hasParsed)
                  Text(
                    'Tìm thấy: ${_parsedStudents.length} sinh viên',
                    style: TextStyle(
                      color: _parsedStudents.isNotEmpty ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (_hasParsed && _parsedStudents.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  itemCount: _parsedStudents.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = _parsedStudents[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFFFF2E8),
                        child: Text(
                          s.rollNumber.substring(0, 2),
                          style: const TextStyle(fontSize: 10, color: Color(0xFFF36F21), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('${s.rollNumber} - ${s.fullName}'),
                      subtitle: Text(s.email),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF36F21),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text('Nhập ${_parsedStudents.length} sinh viên'),
                  onPressed: _parsedStudents.isEmpty
                      ? null
                      : () {
                          widget.onImport(_parsedStudents);
                          Navigator.pop(context);
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
