import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/student.dart';
import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/screens/attendance_view.dart';
import 'package:birdle/widgets/attendance_student_row.dart';

void main() {
  group('BK-02: Attendance Note Debounce & Controller Lifecycle Tests', () {
    final sampleStudents = [
      Student(
        member: 'CE190585',
        code: 'CE190585',
        surname: 'Lâm',
        middleName: 'Quốc',
        givenName: 'Minh',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        member: 'SE170123',
        code: 'SE170123',
        surname: 'Nguyễn',
        middleName: 'Văn',
        givenName: 'An',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        member: 'SE170456',
        code: 'SE170456',
        surname: 'Trần',
        middleName: 'Thị',
        givenName: 'Bình',
        className: 'SE1801',
        totalSlots: 20,
        absentSlots: 2,
      ),
    ];

    final sampleRecords = [
      AttendanceRecord(
        rollNumber: 'CE190585',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.present,
        note: 'Ghi chú ban đầu',
      ),
      AttendanceRecord(
        rollNumber: 'SE170123',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.absent,
        note: '',
      ),
      AttendanceRecord(
        rollNumber: 'SE170456',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        status: AttendanceStatus.late,
        note: '',
      ),
    ];

    Widget buildTestHarness({
      required List<Student> students,
      required List<AttendanceRecord> records,
      Function(String, AttendanceStatus)? onStatusChanged,
      Function(String, String)? onNoteChanged,
      VoidCallback? onSaveToSheet,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AttendanceView(
            students: students,
            records: records,
            currentClass: 'SE1801',
            currentSlot: 1,
            currentDate: DateTime(2026, 9, 22),
            isLoading: false,
            onClassChanged: (_) {},
            onSlotChanged: (_) {},
            onDateChanged: (_) {},
            onStatusChanged: onStatusChanged ?? (_, _) {},
            onNoteChanged: onNoteChanged ?? (_, _) {},
            onMarkAllPresent: () {},
            onMarkAllAbsent: () {},
            onSaveToSheet: onSaveToSheet ?? () {},
            onReloadFromSheet: () {},
            onGoToFapSync: () {},
            onImportStudents: (_) {},
          ),
        ),
      );
    }

    testWidgets('1. Render màn hình với nhiều sinh viên: số TextField và dữ liệu hiển thị đúng', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestHarness(
        students: sampleStudents,
        records: sampleRecords,
      ));
      await tester.pump();

      // Verify AttendanceStudentRow widgets rendered with stable ValueKey
      expect(find.byType(AttendanceStudentRow), findsNWidgets(3));
      expect(find.byKey(const ValueKey('attendance_row_CE190585')), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance_row_SE170123')), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance_row_SE170456')), findsOneWidget);

      // Verify TextFields count (1 search field + 3 student note fields = 4)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));

      // Verify initial note in first student's TextField
      expect(find.text('Ghi chú ban đầu'), findsOneWidget);
    });

    testWidgets('2. Nhập ghi chú "Đi trễ 10 phút": giữ focus, không cursor jump, chỉ callback sau 300ms', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final noteCalls = <Map<String, String>>[];
      await tester.pumpWidget(buildTestHarness(
        students: sampleStudents,
        records: sampleRecords,
        onNoteChanged: (roll, note) => noteCalls.add({'roll': roll, 'note': note}),
      ));
      await tester.pump();

      // Find second student note TextField
      final rowFinder = find.byKey(const ValueKey('attendance_row_SE170123'));
      final noteFieldFinder = find.descendant(of: rowFinder, matching: find.byType(TextField));

      // Enter text
      await tester.enterText(noteFieldFinder, 'Đi trễ 10 phút');
      await tester.pump(const Duration(milliseconds: 100));

      // Before 300ms, debounce should NOT have triggered the callback yet
      expect(noteCalls.isEmpty, true, reason: 'Callback must not be called before 300ms');

      // Verify text remains intact in TextField
      expect(find.text('Đi trễ 10 phút'), findsOneWidget);

      // Rebuild parent tree while typing to verify focus & controller persistence
      await tester.pump(const Duration(milliseconds: 100));
      expect(noteCalls.isEmpty, true, reason: 'Still under 300ms total');
      expect(find.text('Đi trễ 10 phút'), findsOneWidget);

      // Wait until debounce period completes (past 300ms)
      await tester.pump(const Duration(milliseconds: 150));

      // Now callback should have fired exactly once with the final text
      expect(noteCalls.length, 1);
      expect(noteCalls.first['roll'], 'SE170123');
      expect(noteCalls.first['note'], 'Đi trễ 10 phút');
    });

    testWidgets('3. Gõ liên tiếp nhiều ký tự: chỉ callback giá trị cuối cùng sau debounce', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final noteCalls = <Map<String, String>>[];
      await tester.pumpWidget(buildTestHarness(
        students: sampleStudents,
        records: sampleRecords,
        onNoteChanged: (roll, note) => noteCalls.add({'roll': roll, 'note': note}),
      ));
      await tester.pump();

      final rowFinder = find.byKey(const ValueKey('attendance_row_SE170123'));
      final noteFieldFinder = find.descendant(of: rowFinder, matching: find.byType(TextField));

      // Rapid keystrokes
      await tester.enterText(noteFieldFinder, 'A');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(noteFieldFinder, 'AB');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(noteFieldFinder, 'ABC');
      await tester.pump(const Duration(milliseconds: 100));

      // No intermediate callbacks should have fired
      expect(noteCalls.isEmpty, true);

      // Let debounce timer expire
      await tester.pump(const Duration(milliseconds: 350));

      // Only 1 callback with 'ABC'
      expect(noteCalls.length, 1);
      expect(noteCalls.first['note'], 'ABC');
    });

    testWidgets('4. Dispose widget trước khi hết debounce: không có callback muộn, không exception', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final noteCalls = <Map<String, String>>[];
      await tester.pumpWidget(buildTestHarness(
        students: sampleStudents,
        records: sampleRecords,
        onNoteChanged: (roll, note) => noteCalls.add({'roll': roll, 'note': note}),
      ));
      await tester.pump();

      final rowFinder = find.byKey(const ValueKey('attendance_row_SE170123'));
      final noteFieldFinder = find.descendant(of: rowFinder, matching: find.byType(TextField));

      await tester.enterText(noteFieldFinder, 'Sắp bị dispose');
      await tester.pump(const Duration(milliseconds: 100));

      // Dispose the widget by replacing the tree before 300ms expires
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Replaced'))));

      // Wait beyond the 300ms debounce interval
      await tester.pump(const Duration(milliseconds: 400));

      // Callback should NOT be invoked after disposal
      expect(noteCalls.isEmpty, true, reason: 'Debounce callback must not fire after dispose');
    });

    testWidgets('5. Thao tác điểm danh và flush ghi chú: chuyển trạng thái bảo toàn ghi chú mới nhất', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final noteCalls = <Map<String, String>>[];
      final statusCalls = <Map<String, dynamic>>[];

      await tester.pumpWidget(buildTestHarness(
        students: sampleStudents,
        records: sampleRecords,
        onNoteChanged: (roll, note) => noteCalls.add({'roll': roll, 'note': note}),
        onStatusChanged: (roll, status) => statusCalls.add({'roll': roll, 'status': status}),
      ));
      await tester.pump();

      final rowFinder = find.byKey(const ValueKey('attendance_row_SE170123'));
      final noteFieldFinder = find.descendant(of: rowFinder, matching: find.byType(TextField));

      // Enter text and immediately tap status without waiting 300ms
      await tester.enterText(noteFieldFinder, 'Xin nghỉ phép');
      // Tap "Có mặt" pill in that row
      final presentPill = find.descendant(of: rowFinder, matching: find.text('Có mặt'));
      await tester.tap(presentPill);
      await tester.pump();

      // Ghi chú mới nhất phải được flush ngay lập tức trước/khi đổi trạng thái
      expect(noteCalls.length, 1);
      expect(noteCalls.first['note'], 'Xin nghỉ phép');
      expect(statusCalls.length, 1);
      expect(statusCalls.first['status'], AttendanceStatus.present);
    });
  });
}
