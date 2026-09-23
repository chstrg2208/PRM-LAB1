import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/class_overview_item.dart';
import 'package:birdle/screens/attendance_overview_view.dart';
import 'package:birdle/widgets/attendance_class_card.dart';

void main() {
  group('ATD-05: Attendance Hub UI & Card Tests', () {
    final sampleTodayClass = ClassOverviewItem(
      className: 'SE1801_PRM393',
      subject: 'Lập trình di động với Flutter',
      subjectCode: 'PRM393',
      slot: 2,
      slotTime: '09:30 - 11:45',
      daysOfWeek: 'T3-T6',
      room: 'NVH-603',
      currentSession: 5,
      totalSessions: 20,
      sessionStatus: SessionStatus.notYet,
      nextDate: DateTime(2026, 9, 25),
      lastSession: 4,
      lastDate: DateTime(2026, 9, 22),
      lastStatus: 'present',
    );

    final sampleDoneTodayClass = ClassOverviewItem(
      className: 'IA1801_CSN101',
      subject: 'An toàn mạng căn bản',
      subjectCode: 'CSN101',
      slot: 4,
      slotTime: '15:15 - 17:30',
      daysOfWeek: 'T3-T6',
      room: 'NVH-611',
      currentSession: 6,
      totalSessions: 20,
      sessionStatus: SessionStatus.done,
      nextDate: DateTime(2026, 9, 29),
      lastSession: 5,
      lastDate: DateTime(2026, 9, 23),
      lastStatus: 'present',
    );

    final sampleOtherClass = ClassOverviewItem(
      className: 'SE1802_PRM393',
      subject: 'Lập trình di động',
      subjectCode: 'PRM393',
      slot: 1,
      slotTime: '07:00 - 09:15',
      daysOfWeek: 'T2-T5',
      room: 'BE-302',
      currentSession: 4,
      totalSessions: 20,
      sessionStatus: SessionStatus.notYet,
      nextDate: DateTime(2026, 9, 24),
      lastSession: 3,
      lastDate: DateTime(2026, 9, 21),
      lastStatus: 'absent',
    );

    testWidgets('1. Render đủ 2 khu vực card: LỚP HÔM NAY và CÁC LỚP KHÁC', (tester) async {
      final overview = AttendanceOverview(
        todayClasses: [sampleTodayClass, sampleDoneTodayClass],
        otherClasses: [sampleOtherClass],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceOverviewView(
              sheetUrl: 'https://script.google.com/test',
              initialOverview: overview,
              onSelectClass: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('LỚP HÔM NAY'), findsOneWidget);
      expect(find.text('CÁC LỚP KHÁC'), findsOneWidget);

      // 3 cards được render
      expect(find.byType(AttendanceClassCard), findsNWidgets(3));
      expect(find.text('SE1801_PRM393'), findsOneWidget);
      expect(find.text('IA1801_CSN101'), findsOneWidget);
      expect(find.text('SE1802_PRM393'), findsOneWidget);
    });

    testWidgets('2. Card hiển thị đầy đủ 7 thông số nghiệp vụ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceClassCard(
              item: sampleTodayClass,
              isToday: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tên lớp & Môn học
      expect(find.text('SE1801_PRM393'), findsOneWidget);
      expect(find.text('Lập trình di động với Flutter'), findsOneWidget);

      // 2. Slot & Giờ
      expect(find.text('Slot 2 (09:30 - 11:45)'), findsOneWidget);

      // 3 & 4. Lịch học & Phòng
      expect(find.text('T3-T6'), findsOneWidget);
      expect(find.text('NVH-603'), findsOneWidget);

      // 5. Tiến độ buổi học
      expect(find.text('Buổi 5/20'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      // 6. Trạng thái badge
      expect(find.text('Hôm nay'), findsOneWidget);

      // 7. Nút hành động lớp hôm nay chưa điểm danh
      expect(find.text('Điểm danh ngay'), findsOneWidget);
    });

    testWidgets('3. Lớp hôm nay đã điểm danh hiển thị badge "Đã điểm danh" và nút "Xem điểm danh"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceClassCard(
              item: sampleDoneTodayClass,
              isToday: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✓ Đã điểm danh'), findsOneWidget);
      expect(find.text('Xem điểm danh'), findsOneWidget);
    });

    testWidgets('4. Card lớp khác hiển thị metadata gần nhất, ngày tiếp theo và nút "Xem / Sửa lịch sử"', (tester) async {
      String? selectedClass;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceClassCard(
              item: sampleOtherClass,
              isToday: false,
              onTap: () => selectedClass = sampleOtherClass.className,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SE1802_PRM393'), findsOneWidget);
      expect(find.textContaining('Gần nhất: Buổi 3 · 21/09/2026'), findsOneWidget);
      expect(find.textContaining('Học tiếp: 24/09/2026'), findsOneWidget);
      expect(find.text('Xem / Sửa lịch sử'), findsOneWidget);

      // Bấm nút action
      await tester.tap(find.text('Xem / Sửa lịch sử'));
      expect(selectedClass, 'SE1802_PRM393');
    });

    testWidgets('5. Bấm nút "Điểm danh ngay" gọi đúng callback onSelectClass', (tester) async {
      String? selected;

      final overview = AttendanceOverview(
        todayClasses: [sampleTodayClass],
        otherClasses: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceOverviewView(
              sheetUrl: 'https://script.google.com/test',
              initialOverview: overview,
              onSelectClass: (c) => selected = c,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Điểm danh ngay'));
      expect(selected, 'SE1801_PRM393');
    });

    testWidgets('6. Loading state hiển thị Skeleton cards', (tester) async {
      final completer = Completer<AttendanceOverview>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceOverviewView(
              sheetUrl: 'https://script.google.com/test',
              onLoadOverview: () => completer.future,
              onSelectClass: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(); // build initial frame in loading state

      expect(find.byType(AttendanceClassCardSkeleton), findsWidgets);

      // Complete future to clean up pending async operations
      completer.complete(const AttendanceOverview());
      await tester.pumpAndSettle();
    });

    testWidgets('7. Empty state khi chưa có lớp học nào', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceOverviewView(
              sheetUrl: 'https://script.google.com/test',
              initialOverview: const AttendanceOverview(todayClasses: [], otherClasses: []),
              onSelectClass: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có lớp học nào'), findsOneWidget);
    });

    testWidgets('8. Empty state khi chưa kết nối Google Sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceOverviewView(
              sheetUrl: '',
              onSelectClass: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa kết nối Google Sheet'), findsOneWidget);
    });
  });
}
