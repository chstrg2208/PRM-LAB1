import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/services/csv_export_service.dart';
import 'package:birdle/widgets/report_preview_dialog.dart';

void main() {
  group('ReportSummaryPreviewDialog Widget Tests', () {
    final testStudents = [
      Student(rollNumber: 'SE1801', fullName: 'Lâm Quốc Minh', className: 'SE1801', totalSlots: 20, absentSlots: 5), // Banned (>20%)
      Student(rollNumber: 'SE1802', fullName: 'Nguyễn Văn An', className: 'SE1801', totalSlots: 20, absentSlots: 3), // Warning (15%)
      Student(rollNumber: 'SE1803', fullName: 'Lê Văn Bình', className: 'SE1801', totalSlots: 20, absentSlots: 0), // 100%
    ];

    testWidgets('1. Hiển thị đầy đủ thông số tóm tắt: Lớp, Sĩ số, Tỷ lệ chuyên cần, Số SV cấm thi, Cấu trúc 20 slot', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportSummaryPreviewDialog(
              className: 'SE1801_PRM393',
              students: testStudents,
              onConfirmExport: (delimiter) async => const CsvExportResult(success: true, message: 'Thành công'),
            ),
          ),
        ),
      );

      // Verify Header and Subtitle
      expect(find.text('Xem trước Báo cáo Chuyên cần'), findsOneWidget);
      expect(find.textContaining('Xác nhận thông số trước khi xuất file'), findsOneWidget);

      // Verify Metrics
      expect(find.text('Lớp SE1801_PRM393'), findsOneWidget);
      expect(find.text('3 sinh viên'), findsOneWidget); // Sĩ số
      expect(find.text('1 sinh viên'), findsNWidgets(3)); // 1 SV cấm thi, 1 SV cảnh báo, 1 SV chuyên cần 100%
      expect(find.textContaining('20 Buổi học (B1 → B20)'), findsOneWidget);

      // Verify Delimiter Selector
      expect(find.textContaining('Chấm phẩy ( ; )'), findsOneWidget);
      expect(find.textContaining('Dấu phẩy ( , )'), findsOneWidget);

      // Verify Actions
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xác nhận tải về'), findsOneWidget);
    });

    testWidgets('2. Chống double-click: khi bấm Xác nhận tải về, hiển thị spinner và khóa nút', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int exportCalls = 0;
      String? usedDelimiter;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportSummaryPreviewDialog(
              className: 'SE1801',
              students: testStudents,
              onConfirmExport: (delimiter) async {
                exportCalls++;
                usedDelimiter = delimiter;
                await Future.delayed(const Duration(milliseconds: 200));
                return const CsvExportResult(success: true, message: 'OK');
              },
            ),
          ),
        ),
      );

      // Tap confirm button
      await tester.tap(find.text('Xác nhận tải về'));
      await tester.pump(); // Start export

      expect(exportCalls, 1);
      expect(usedDelimiter, ';'); // Mặc định là ';'
      expect(find.text('Đang xuất CSV...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Try tapping again while exporting - should not trigger second export
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(exportCalls, 1);

      // Complete export
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('3. Đóng dialog sạch sẽ khi bấm Hủy', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ReportSummaryPreviewDialog.show(
                    context: ctx,
                    className: 'SE1801',
                    students: testStudents,
                    onConfirmExport: (delimiter) async => const CsvExportResult(success: true, message: 'OK'),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );


      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Xem trước Báo cáo Chuyên cần'), findsOneWidget);

      // Tap Hủy
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Xem trước Báo cáo Chuyên cần'), findsNothing);
    });
  });
}
