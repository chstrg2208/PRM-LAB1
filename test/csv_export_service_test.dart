import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/services/csv_export_service.dart';

void main() {
  group('BK-10.1: CsvExportService Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('birdle_csv_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. CSV bắt đầu bằng BOM UTF-8 (\uFEFF)', () {
      final csv = CsvExportService.generateCsvContent(students: []);
      expect(csv.startsWith('\uFEFF'), true);
      expect(csv.codeUnitAt(0), 0xFEFF);
    });

    test('2. Header đủ và đúng thứ tự quy định', () {
      final csv = CsvExportService.generateCsvContent(students: []);
      final lines = csv.split('\n');
      expect(lines.length >= 2, true);
      // Dòng đầu tiên sau BOM
      final headerLine = lines[0].replaceFirst('\uFEFF', '').trim();
      expect(
        headerLine,
        'Mã SV,Họ và tên,Lớp,Email,Tổng số buổi,Vắng,Có mặt,Tỷ lệ vắng,Trạng thái',
      );
    });

    test('3. Dữ liệu sinh viên tiếng Việt hiển thị đầy đủ và chính xác', () {
      final students = [
        Student(
          member: 'SE170123',
          code: 'SE170123',
          surname: 'Nguyễn',
          middleName: 'Văn',
          givenName: 'An',
          className: 'SE1801',
          email: 'annvse170123@fpt.edu.vn',
          totalSlots: 20,
          absentSlots: 2,
        ),
      ];

      final csv = CsvExportService.generateCsvContent(students: students);
      expect(csv.contains('SE170123'), true);
      expect(csv.contains('Nguyễn Văn An'), true);
      expect(csv.contains('SE1801'), true);
      expect(csv.contains('annvse170123@fpt.edu.vn'), true);
      expect(csv.contains(',20,2,18,10.0%,ĐỦ ĐIỀU KIỆN'), true);
    });

    test('4. Phân loại chuẩn xác trạng thái chuyên cần trong CSV', () {
      final students = [
        // 4.1. Đủ điều kiện (< 15%)
        Student(rollNumber: 'SV01', fullName: 'SV Đủ Điều Kiện', className: 'SE1801', totalSlots: 20, absentSlots: 2),
        // 4.2. Cảnh báo (15% <= rate < 20% và còn lượt vắng)
        Student(rollNumber: 'SV02', fullName: 'SV Cảnh Báo', className: 'SE1801', totalSlots: 20, absentSlots: 3),
        // 4.3. Chạm ngưỡng đúng 20% (4/20 = 20%)
        Student(rollNumber: 'SV03', fullName: 'SV Đúng 20%', className: 'SE1801', totalSlots: 20, absentSlots: 4),
        // 4.4. Hết lượt vắng dưới 20% (4/21 = 19.05%)
        Student(rollNumber: 'SV04', fullName: 'SV Hết Lượt Vắng', className: 'SE1801', totalSlots: 21, absentSlots: 4),
        // 4.5. Cấm thi (> 20%)
        Student(rollNumber: 'SV05', fullName: 'SV Cấm Thi', className: 'SE1801', totalSlots: 20, absentSlots: 5),
      ];

      final csv = CsvExportService.generateCsvContent(students: students);

      expect(csv.contains('SV01,SV Đủ Điều Kiện,SE1801,,20,2,18,10.0%,ĐỦ ĐIỀU KIỆN'), true);
      expect(csv.contains('SV02,SV Cảnh Báo,SE1801,,20,3,17,15.0%,CẢNH BÁO (15-20%)'), true);
      expect(csv.contains('SV03,SV Đúng 20%,SE1801,,20,4,16,20.0%,CHẠM NGƯỠNG (20%)'), true);
      expect(csv.contains('SV04,SV Hết Lượt Vắng,SE1801,,21,4,17,19.0%,HẾT LƯỢT VẮNG'), true);
      expect(csv.contains('SV05,SV Cấm Thi,SE1801,,20,5,15,25.0%,CẤM THI (>20%)'), true);
    });

    test('5. Tên hoặc trường có dấu phẩy, dấu nháy kép, xuống dòng được quote/escape chuẩn RFC 4180', () {
      final students = [
        Student(
          rollNumber: 'SE999',
          customFullName: 'Trần "Pro", Văn B',
          className: 'SE1801, Special',
          email: 'test@fpt.edu.vn',
          totalSlots: 20,
          absentSlots: 0,
        ),
      ];

      final csv = CsvExportService.generateCsvContent(students: students);
      // Dấu " bên trong phải thành "" và toàn bộ trường phải bọc trong ""
      expect(csv.contains('"Trần ""Pro"", Văn B"'), true);
      expect(csv.contains('"SE1801, Special"'), true);
    });

    test('6. exportToFile ghi file thật vào temporary directory và kiểm tra nội dung', () async {
      final students = [
        Student(rollNumber: 'CE190585', fullName: 'Lâm Quốc Minh', className: 'SE1801', totalSlots: 30, absentSlots: 7),
      ];

      final testTime = DateTime(2026, 9, 22, 14, 30, 0);
      final result = await CsvExportService.exportToFile(
        students: students,
        className: 'SE1801',
        targetDirectory: tempDir,
        timestamp: testTime,
      );

      expect(result.success, true);
      expect(result.filePath, isNotNull);
      expect(result.filePath!.contains('Birdle_BaoCao_SE1801_20260922_143000.csv'), true);

      final exportedFile = File(result.filePath!);
      expect(exportedFile.existsSync(), true);

      // Đọc lại nội dung file và kiểm tra BOM UTF-8
      final bytes = await exportedFile.readAsBytes();
      expect(bytes.length >= 3, true);
      // UTF-8 BOM bytes: 0xEF, 0xBB, 0xBF
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      final content = await exportedFile.readAsString();
      expect(content.contains('Mã SV,Họ và tên,Lớp,Email'), true);
      expect(content.contains('CE190585,Lâm Quốc Minh,SE1801'), true);
      expect(content.contains('CẤM THI (>20%)'), true);
    });

    test('6.1. exportToFile tự động thêm suffix tránh ghi đè nếu file đã tồn tại', () async {
      final students = [
        Student(rollNumber: 'SE1', fullName: 'Student 1', className: 'SE1801'),
      ];
      final testTime = DateTime(2026, 9, 22, 14, 30, 0);

      // Lần 1
      final res1 = await CsvExportService.exportToFile(
        students: students,
        className: 'SE1801',
        targetDirectory: tempDir,
        timestamp: testTime,
      );
      expect(res1.success, true);

      // Lần 2 với cùng timestamp -> phải tạo file _1.csv
      final res2 = await CsvExportService.exportToFile(
        students: students,
        className: 'SE1801',
        targetDirectory: tempDir,
        timestamp: testTime,
      );
      expect(res2.success, true);
      expect(res2.filePath!.contains('_1.csv'), true);
      expect(File(res1.filePath!).existsSync(), true);
      expect(File(res2.filePath!).existsSync(), true);
    });

    test('7. Directory không ghi được hoặc không xác định được trả lỗi trung thực', () async {
      // 7.1. Khi targetDirectory = null và không tìm thấy default Downloads
      final resNoDir = await CsvExportService.exportToFile(
        students: [],
        className: 'SE1801',
        targetDirectory: null,
      );
      // Nếu môi trường test không có Downloads hoặc có, test behavior tương ứng:
      if (resNoDir.success == false) {
        expect(resNoDir.message.contains('Không thể xác định thư mục tải xuống'), true);
      }

      // 7.2. Target path trỏ vào một file đã tồn tại chứ không phải directory
      final fakeFileAsDir = File('${tempDir.path}${Platform.pathSeparator}dummy_file.txt');
      fakeFileAsDir.writeAsStringSync('blocker');

      final resBlocked = await CsvExportService.exportToFile(
        students: [],
        className: 'SE1801',
        targetDirectory: Directory(fakeFileAsDir.path),
      );
      expect(resBlocked.success, false);
      expect(resBlocked.message.contains('Không có quyền ghi hoặc không thể tạo thư mục'), true);
    });

    test('8. Sanitize className chống path traversal và ký tự bất hợp lệ', () {
      expect(CsvExportService.sanitizeClassName('../../bad_class'), 'bad_class');
      expect(CsvExportService.sanitizeClassName('SE1801/Lab:1*?'), 'SE1801_Lab_1');
      expect(CsvExportService.sanitizeClassName('  PRM392  '), 'PRM392');
      expect(CsvExportService.sanitizeClassName('...'), 'UnknownClass');
      expect(CsvExportService.sanitizeClassName(''), 'UnknownClass');

      final filename = CsvExportService.generateFileName(className: '../../hack/class');
      expect(filename.contains('..'), false);
      expect(filename.contains('/'), false);
      expect(filename.contains(r'\'), false);
      expect(filename.startsWith('Birdle_BaoCao_hack_class_'), true);
    });
  });
}
