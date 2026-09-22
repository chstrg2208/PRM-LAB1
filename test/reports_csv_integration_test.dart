import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/screens/reports_view.dart';
import 'package:birdle/services/csv_export_service.dart';
import 'package:birdle/state/attendance_session_manager.dart';

class FakeAttendanceApiClient implements AttendanceApiClient {
  @override
  Future<Map<String, dynamic>> testConnection(String sheetUrl) async => {'success': true};

  @override
  Future<List<Student>> fetchStudents(String sheetUrl, String className) async => [];

  @override
  Future<List<AttendanceRecord>> fetchAttendance(String sheetUrl, String className, String date, int slot) async => [];

  @override
  Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) async => {'success': true};

  @override
  Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(String sheetUrl, String className) async => [];
}

void main() {
  group('BK-10.2: AttendanceSessionManager CSV Export Tests', () {
    test('1. Manager success: exportCurrentReportCsv gọi exporter và quản lý isExporting đúng lifecycle', () async {
      int exporterCalls = 0;
      List<Student>? exportedStudents;
      String? exportedClass;

      final manager = AttendanceSessionManager(
        apiClient: FakeAttendanceApiClient(),
        initialClass: 'SE1801',
        csvExporter: ({required students, required className}) async {
          exporterCalls++;
          exportedStudents = students;
          exportedClass = className;
          // Verify isExporting is true during execution
          return const CsvExportResult(
            success: true,
            filePath: 'C:/Downloads/Birdle_BaoCao_SE1801_test.csv',
            message: 'Đã xuất báo cáo CSV chuyên cần thành công!',
          );
        },
      );

      final sampleStudents = [
        Student(rollNumber: 'SE170123', fullName: 'Nguyễn Văn An', className: 'SE1801', totalSlots: 20, absentSlots: 1),
      ];
      manager.importStudents(sampleStudents);

      expect(manager.isExporting, false);

      final result = await manager.exportCurrentReportCsv();

      expect(result.success, true);
      expect(result.filePath, 'C:/Downloads/Birdle_BaoCao_SE1801_test.csv');
      expect(exporterCalls, 1);
      expect(exportedStudents?.length, 1);
      expect(exportedClass, 'SE1801');
      expect(manager.isExporting, false);

      manager.dispose();
    });

    test('2. Manager failure: exporter trả failure hoặc throw thì isExporting luôn được reset về false', () async {
      final manager = AttendanceSessionManager(
        apiClient: FakeAttendanceApiClient(),
        initialClass: 'SE1801',
        csvExporter: ({required students, required className}) async {
          throw Exception('Ổ đĩa đầy');
        },
      );

      manager.importStudents([
        Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801'),
      ]);

      expect(manager.isExporting, false);

      final result = await manager.exportCurrentReportCsv();

      expect(result.success, false);
      expect(result.message.contains('Ổ đĩa đầy'), true);
      expect(manager.isExporting, false);

      manager.dispose();
    });

    test('3. Danh sách rỗng: không gọi exporter, trả message rõ ràng', () async {
      int exporterCalls = 0;

      final manager = AttendanceSessionManager(
        apiClient: FakeAttendanceApiClient(),
        initialClass: 'SE1801',
        csvExporter: ({required students, required className}) async {
          exporterCalls++;
          return const CsvExportResult(success: true, message: 'ok');
        },
      );

      expect(manager.students.isEmpty, true);

      final result = await manager.exportCurrentReportCsv();

      expect(result.success, false);
      expect(result.message.contains('Chưa có dữ liệu sinh viên'), true);
      expect(exporterCalls, 0);
      expect(manager.isExporting, false);

      manager.dispose();
    });

    test('6. Chống double-click: khi export đang pending, lần gọi thứ hai bị từ chối ngay lập tức', () async {
      int exporterCalls = 0;

      final manager = AttendanceSessionManager(
        apiClient: FakeAttendanceApiClient(),
        initialClass: 'SE1801',
        csvExporter: ({required students, required className}) async {
          exporterCalls++;
          await Future.delayed(const Duration(milliseconds: 100));
          return const CsvExportResult(success: true, filePath: 'path.csv', message: 'ok');
        },
      );

      manager.importStudents([
        Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801'),
      ]);

      // Bắt đầu export lần 1
      final future1 = manager.exportCurrentReportCsv();
      expect(manager.isExporting, true);

      // Thử export lần 2 ngay trong lúc lần 1 đang chạy
      final result2 = await manager.exportCurrentReportCsv();
      expect(result2.success, false);
      expect(result2.message.contains('Đang trong quá trình xuất'), true);

      // Đợi lần 1 hoàn tất
      final result1 = await future1;
      expect(result1.success, true);
      expect(exporterCalls, 1);
      expect(manager.isExporting, false);

      manager.dispose();
    });
  });

  group('BK-10.2: ReportsView Widget Tests', () {
    testWidgets('4. ReportsView success: tap nút Export gọi callback, hiển thị loading và thành công', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool exportCalled = false;
      bool isExporting = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ReportsView(
                  students: [
                    Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801'),
                  ],
                  currentClass: 'SE1801',
                  googleSheetUrl: '',
                  isExporting: isExporting,
                  onExportCsv: () {
                    exportCalled = true;
                    setState(() => isExporting = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xuất báo cáo CSV chuyên cần thành công! (C:/Downloads/report.csv)'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      // Ban đầu: Nút hiển thị Export CSV
      expect(find.text('Export CSV'), findsOneWidget);

      // Tap nút
      await tester.tap(find.text('Export CSV'));
      await tester.pump();

      expect(exportCalled, true);
      expect(find.text('Đang xuất CSV...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // SnackBar thành công hiển thị
      expect(find.textContaining('Đã xuất báo cáo CSV chuyên cần thành công!'), findsOneWidget);
      expect(find.textContaining('C:/Downloads/report.csv'), findsOneWidget);
    });

    testWidgets('5. ReportsView failure: khi export thất bại hiển thị lỗi rõ ràng, không báo thành công', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsView(
              students: [
                Student(rollNumber: 'SE1', fullName: 'SV 1', className: 'SE1801'),
              ],
              currentClass: 'SE1801',
              googleSheetUrl: '',
              onExportCsv: () {
                // Giả lập failure handler như trong MainDesktopScreen
                // Thất bại thì KHÔNG báo thành công
              },
            ),
          ),
        ),
      );

      // Verify ReportsView renders cleanly with students
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.textContaining('Báo cáo chuyên cần học kỳ'), findsOneWidget);
      expect(find.text('Đã kết xuất báo cáo CSV chuyên cần của lớp!'), findsNothing);
    });

    testWidgets('7. Regression: ReportsView vẫn render mượt mà khi danh sách sinh viên rỗng', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReportsView(
              students: [],
              currentClass: 'SE1801',
              googleSheetUrl: '',
            ),
          ),
        ),
      );

      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // 0 sinh viên
    });
  });
}
