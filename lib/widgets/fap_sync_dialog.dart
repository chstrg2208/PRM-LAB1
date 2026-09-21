import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attendance_record.dart';
import '../services/fap_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BirdleRadius.mdBorder),
      child: Container(
        width: 660,
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
                    color: BirdleColors.brandLight,
                    borderRadius: BirdleRadius.smBorder,
                  ),
                  child: const Icon(Icons.bolt, color: BirdleColors.brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đồng bộ điểm danh lên FAP ($className · Slot $slot)',
                        style: BirdleTypography.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tự động tích chọn $presentCount Có mặt / $absentCount Vắng trên trang FAP',
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: BirdleColors.brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cách sử dụng: Mở trang điểm danh trên fap.fpt.edu.vn > Bấm F12 (Console) > Dán đoạn mã dưới đây và bấm Enter. FAP sẽ tự động chọn trúng các ô điểm danh!',
                      style: TextStyle(fontSize: 12.5, color: BirdleColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Mã Script tự động điền FAP:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: BirdleColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  script,
                  style: const TextStyle(
                    color: BirdleColors.textPrimary,
                    fontFamily: 'Consolas, monospace',
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BirdleSecondaryButton(
                  icon: Icons.open_in_browser,
                  label: 'Mở trang FAP (fap.fpt.edu.vn)',
                  onPressed: () => StorageService.openBrowser('https://fap.fpt.edu.vn'),
                ),
                Row(
                  children: [
                    BirdleGhostButton(
                      label: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    BirdlePrimaryButton(
                      icon: Icons.copy,
                      label: 'Sao chép mã Script',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: script));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Đã sao chép mã script vào Clipboard!'),
                            backgroundColor: BirdleColors.brand,
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
