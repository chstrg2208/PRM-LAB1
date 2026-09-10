import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attendance_record.dart';
import '../services/fap_service.dart';
import '../services/storage_service.dart';

class FapSyncDialog extends StatelessWidget {
  final List<AttendanceRecord> records;
  final String className;
  final int slot;

  const FapSyncDialog({
    super.key,
    required this.records,
    required this.className,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final script = FapService.generateFapFillScript(records);
    final presentCount = records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = records.where((r) => r.status == AttendanceStatus.absent).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
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
                    color: const Color(0xFFFFF2E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFFF36F21), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đồng bộ điểm danh lên FAP ($className - Slot $slot)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tự động tích chọn $presentCount Có mặt / $absentCount Vắng trên trang FAP',
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
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cách sử dụng: Mở trang điểm danh trên fap.fpt.edu.vn > Bấm F12 (Console) > Dán đoạn mã dưới đây và bấm Enter. FAP sẽ tự động chọn trúng các ô điểm danh!',
                      style: TextStyle(color: Color(0xFF166534), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Mã Script tự động điền FAP:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  script,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontFamily: 'Consolas, monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Mở trang FAP (fap.fpt.edu.vn)'),
                  onPressed: () {
                    StorageService.openBrowser('https://fap.fpt.edu.vn');
                  },
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF36F21),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Sao chép mã Script'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: script));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã sao chép mã script vào Clipboard!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
