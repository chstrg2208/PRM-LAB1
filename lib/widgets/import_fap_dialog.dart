import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/fap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BirdleRadius.mdBorder),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BirdleColors.surfaceSecondary,
                    borderRadius: BirdleRadius.smBorder,
                  ),
                  child: const Icon(Icons.file_download_outlined, color: BirdleColors.brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập danh sách từ FAP (Lớp ${widget.currentClass})',
                        style: BirdleTypography.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Dán mã nguồn HTML trang FAP hoặc danh sách sinh viên có Mã SV (SE..., HE...)',
                        style: BirdleTypography.metadata,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 7,
              style: const TextStyle(fontSize: 12.5, fontFamily: 'Consolas, monospace'),
              decoration: const InputDecoration(
                hintText: 'Dán nội dung bảng FAP vào đây...\nVí dụ:\n1  SE170123  Nguyễn Văn An\n2  SE170456  Trần Thị Bình\n...',
                contentPadding: EdgeInsets.all(12),
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
                BirdleSecondaryButton(
                  icon: Icons.search,
                  label: 'Phân tích dữ liệu',
                  onPressed: _parse,
                ),
                const SizedBox(width: 12),
                if (_hasParsed)
                  Text(
                    'Tìm thấy: ${_parsedStudents.length} sinh viên',
                    style: TextStyle(
                      color: _parsedStudents.isNotEmpty ? BirdleColors.success : BirdleColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            if (_hasParsed && _parsedStudents.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: BirdleColors.border),
                  borderRadius: BirdleRadius.smBorder,
                ),
                child: ListView.separated(
                  itemCount: _parsedStudents.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = _parsedStudents[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: BirdleColors.surfaceSecondary,
                        child: Text(
                          s.rollNumber.length >= 2 ? s.rollNumber.substring(0, 2) : 'SV',
                          style: const TextStyle(fontSize: 10, color: BirdleColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('${s.rollNumber} - ${s.fullName}', style: BirdleTypography.bodyMedium),
                      subtitle: Text(s.email, style: BirdleTypography.caption),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BirdleGhostButton(
                  label: 'Hủy',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                BirdlePrimaryButton(
                  icon: Icons.check,
                  label: 'Nhập ${_parsedStudents.length} sinh viên',
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
