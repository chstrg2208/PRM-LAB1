import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/screens/students_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BK-05: Chuẩn hóa dữ liệu Họ - Đệm - Tên FAP', () {
    test('1. Parse đúng dữ liệu FAP: CODE, SURNAME, MIDDLE NAME, GIVEN NAME', () {
      final json = {
        'CODE': 'SE180001',
        'SURNAME': 'Lâm',
        'MIDDLE NAME': 'Quốc',
        'GIVEN NAME': 'Minh',
      };

      final student = Student.fromJson(json);

      expect(student.rollNumber, 'SE180001');
      expect(student.code, 'SE180001');
      expect(student.surname, 'Lâm');
      expect(student.middleName, 'Quốc');
      expect(student.givenName, 'Minh');
      expect(student.fullName, 'Lâm Quốc Minh');

      // 2. Xác minh CODE không xuất hiện trong fullName
      expect(student.fullName.contains('SE180001'), isFalse);
    });

    test('3. Xử lý tên thiếu middle name, tên một từ, null/rỗng không crash, không khoảng trắng thừa', () {
      // Thiếu middle name (ví dụ: Nguyễn An)
      final noMiddleJson = {
        'CODE': 'SE180002',
        'SURNAME': 'Nguyễn',
        'MIDDLE NAME': '',
        'GIVEN NAME': 'An',
      };
      final sNoMiddle = Student.fromJson(noMiddleJson);
      expect(sNoMiddle.fullName, 'Nguyễn An');
      expect(sNoMiddle.fullName.contains('  '), isFalse);

      // Tên một từ (ví dụ: chỉ có givenName hoặc surname)
      final oneWordJson = {
        'CODE': 'SE180003',
        'SURNAME': '',
        'MIDDLE NAME': '',
        'GIVEN NAME': 'Minh',
      };
      final sOneWord = Student.fromJson(oneWordJson);
      expect(sOneWord.fullName, 'Minh');

      // Có khoảng trắng thừa ở các trường
      final untrimmedJson = {
        'CODE': ' SE180004 ',
        'SURNAME': '  Trần  ',
        'MIDDLE NAME': '   Thị   ',
        'GIVEN NAME': '   Bình   ',
      };
      final sUntrimmed = Student.fromJson(untrimmedJson);
      expect(sUntrimmed.rollNumber, 'SE180004');
      expect(sUntrimmed.surname, 'Trần');
      expect(sUntrimmed.middleName, 'Thị');
      expect(sUntrimmed.givenName, 'Bình');
      expect(sUntrimmed.fullName, 'Trần Thị Bình');
      expect(sUntrimmed.fullName.contains('  '), isFalse);

      // Rỗng hoàn toàn
      final emptyJson = <String, dynamic>{};
      final sEmpty = Student.fromJson(emptyJson);
      expect(sEmpty.fullName, startsWith('Sinh viên'));
      expect(() => sEmpty.fullName, returnsNormally);
    });
  });

  group('BK-05: StudentsView Tìm kiếm & Hiển thị chuẩn FAP', () {
    final testStudents = [
      Student(
        code: 'SE180001',
        member: 'SE180001',
        surname: 'Lâm',
        middleName: 'Quốc',
        givenName: 'Minh',
        email: 'minhlqse180001@fpt.edu.vn',
        className: 'SE1801',
      ),
      Student(
        code: 'SE180002',
        member: 'SE180002',
        surname: 'Nguyễn',
        middleName: 'Văn',
        givenName: 'An',
        email: 'annvse180002@fpt.edu.vn',
        className: 'SE1801',
      ),
    ];

    testWidgets('4.1. Hiển thị đúng mã SV, Họ và tên (không đảo lộn thứ tự họ tên)', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentsView(
              students: testStudents,
              currentClass: 'SE1801',
              onUpdateStudents: (_) {},
              onClassChanged: (_) {},
              onSyncToSheet: () {},
              onGoToImport: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hiển thị mã SV và họ tên đúng
      expect(find.text('SE180001'), findsOneWidget);
      expect(find.text('Lâm Quốc Minh'), findsOneWidget);
      expect(find.text('SE180002'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);

      // Mở dialog chi tiết của sinh viên Lâm Quốc Minh
      final detailButtons = find.byTooltip('Xem hồ sơ chi tiết');
      expect(detailButtons, findsNWidgets(2));
      await tester.tap(detailButtons.first);
      await tester.pumpAndSettle();

      // Kiểm tra trong dialog chi tiết nhãn chuẩn FAP
      expect(find.text('Mã SV (CODE)'), findsOneWidget);
      expect(find.text('Họ (SURNAME)'), findsOneWidget);
      expect(find.text('Tên đệm (MIDDLE NAME)'), findsOneWidget);
      expect(find.text('Tên gọi (GIVEN NAME)'), findsOneWidget);
      expect(find.text('Họ và tên đầy đủ'), findsOneWidget);
      expect(find.text('Lâm'), findsOneWidget);
      expect(find.text('Quốc'), findsOneWidget);
      expect(find.text('Minh'), findsOneWidget);
    });

    testWidgets('4.2. Tìm kiếm theo họ tên đầy đủ, tên gọi, và mã SV', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentsView(
              students: testStudents,
              currentClass: 'SE1801',
              onUpdateStudents: (_) {},
              onClassChanged: (_) {},
              onSyncToSheet: () {},
              onGoToImport: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // 1. Tìm theo "Lâm Quốc Minh"
      await tester.enterText(searchField, 'Lâm Quốc Minh');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Lâm Quốc Minh')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Nguyễn Văn An')), findsNothing);

      // 2. Tìm theo tên gọi "Minh"
      await tester.enterText(searchField, 'Minh');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Lâm Quốc Minh')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Nguyễn Văn An')), findsNothing);

      // 3. Tìm theo mã sinh viên "SE180001"
      await tester.enterText(searchField, 'SE180001');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('SE180001')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('SE180002')), findsNothing);

      // 4. Tìm theo sinh viên khác "An"
      await tester.enterText(searchField, 'An');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Nguyễn Văn An')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Lâm Quốc Minh')), findsNothing);
    });
  });
}
