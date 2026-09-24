import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/models/class_overview_item.dart';
import 'package:birdle/screens/attendance_overview_view.dart';
import 'package:birdle/widgets/weekly_schedule_view.dart';

void main() {
  group('Attendance Overview Timetable Tests', () {
    final sampleClass1 = ClassOverviewItem(
      className: 'SE1917',
      subject: 'Lập trình .NET',
      subjectCode: 'PRN232',
      slot: 1,
      slotTime: '07:00 - 09:15',
      daysOfWeek: 'T2-T4',
      room: 'NVH-602',
      currentSession: 5,
      totalSessions: 20,
      sessionStatus: SessionStatus.notYet,
      nextDate: DateTime(2026, 9, 25),
      lastSession: 4,
      lastDate: DateTime(2026, 9, 22),
      lastStatus: 'present',
    );

    final sampleClass2 = ClassOverviewItem(
      className: 'SE1913',
      subject: 'Lập trình PRM',
      subjectCode: 'PRM393',
      slot: 1,
      slotTime: '07:00 - 09:15',
      daysOfWeek: 'T3-T6',
      room: 'NVH-604',
      currentSession: 6,
      totalSessions: 20,
      sessionStatus: SessionStatus.done,
      nextDate: DateTime(2026, 9, 29),
      lastSession: 5,
      lastDate: DateTime(2026, 9, 23),
      lastStatus: 'present',
    );

    testWidgets('1. Overview View directly renders WeeklyScheduleView', (tester) async {
      final overview = AttendanceOverview(
        todayClasses: [sampleClass1],
        otherClasses: [sampleClass2],
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

      // Directly renders weekly timetable
      expect(find.byType(WeeklyScheduleView), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('SLOT'), findsOneWidget);
      expect(find.text('Slot 1'), findsWidgets);
    });

    testWidgets('2. WeeklyScheduleView renders timetable grid correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyScheduleView(
              allClasses: [sampleClass1, sampleClass2],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check days of week
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('T4'), findsOneWidget);
      expect(find.text('T5'), findsOneWidget);
      expect(find.text('T6'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);

      // Slots 1 to 6
      for (int i = 1; i <= 6; i++) {
        expect(find.text('Slot $i'), findsOneWidget);
      }

      // Check class item inside timetable
      expect(find.text('SE1917-PRN232'), findsWidgets);
    });

    testWidgets('3. Tap on timetable cell triggers class selection', (tester) async {
      String? selectedClass;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyScheduleView(
              allClasses: [sampleClass1],
              onClassTap: (item) => selectedClass = item.className,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SE1917-PRN232').first);
      expect(selectedClass, 'SE1917');
    });

    testWidgets('4. Future sessions in WeeklyScheduleView are always marked (Not yet)', (tester) async {
      final futureClass = ClassOverviewItem(
        className: 'SE1999',
        subject: 'Capstone Project',
        subjectCode: 'PRM393',
        slot: 3,
        slotTime: '12:30 - 14:45',
        daysOfWeek: 'CN',
        room: 'NVH-602',
        currentSession: 1,
        totalSessions: 20,
        sessionStatus: SessionStatus.done,
        nextDate: DateTime(2026, 9, 27),
        lastSession: 1,
        lastDate: DateTime(2026, 9, 20),
        lastStatus: 'present',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyScheduleView(
              allClasses: [futureClass],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that cell displays (Not yet)
      expect(find.text('(Not yet)'), findsWidgets);
    });
  });
}
