import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_overview_item.dart';
import '../theme/app_theme.dart';

/// ATD-05b: Lịch dạy theo tuần (Weekly Timetable Calendar).
///
/// Hiển thị dạng bảng Slot (1–6) × Thứ (T2–CN) giống giao diện FAP
/// "Lecture of week". Mỗi ô chứa thông tin lớp, trạng thái điểm danh,
/// và thời gian slot.
class WeeklyScheduleView extends StatefulWidget {
  final List<ClassOverviewItem> allClasses;
  final void Function(ClassOverviewItem item)? onClassTap;

  const WeeklyScheduleView({
    super.key,
    required this.allClasses,
    this.onClassTap,
  });

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _getMonday(DateTime.now());
  }

  /// Lấy ngày Thứ Hai đầu tuần
  DateTime _getMonday(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  void _previousWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  void _goToCurrentWeek() => setState(() => _weekStart = _getMonday(DateTime.now()));

  /// Map lịch dạy (daysOfWeek "T2-T5") sang ngày trong tuần (1=T2 ... 7=CN)
  List<int> _parseDaysOfWeek(String daysOfWeek) {
    final days = <int>[];
    final upper = daysOfWeek.toUpperCase().replaceAll(' ', '');
    if (upper.contains('T2')) days.add(1); // Monday
    if (upper.contains('T3')) days.add(2);
    if (upper.contains('T4')) days.add(3);
    if (upper.contains('T5')) days.add(4);
    if (upper.contains('T6')) days.add(5);
    if (upper.contains('T7')) days.add(6);
    if (upper.contains('CN')) days.add(7);
    return days;
  }

  /// Tìm classes ở [slot] và [dayIndex] (1=Mon..7=Sun)
  List<ClassOverviewItem> _classesAt(int slot, int dayIndex) {
    return widget.allClasses.where((c) {
      if (c.slot != slot) return false;
      final days = _parseDaysOfWeek(c.daysOfWeek);
      return days.contains(dayIndex);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dayHeaders = <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final today = DateTime.now();
    final todayIndex = today.weekday; // 1=Mon..7=Sun
    final isCurrentWeek = _weekStart.year == _getMonday(today).year &&
        _weekStart.month == _getMonday(today).month &&
        _weekStart.day == _getMonday(today).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Week navigation bar ─────────────────────────────────────────
        _buildWeekNavBar(isCurrentWeek),
        const SizedBox(height: 16),

        // ── Timetable grid ──────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const minWidth = 700.0;
              final needsScroll = constraints.maxWidth < minWidth;

              final gridContent = Container(
                width: needsScroll ? minWidth : double.infinity,
                decoration: BoxDecoration(
                  color: BirdleColors.surface,
                  borderRadius: BirdleRadius.mdBorder,
                  border: Border.all(color: BirdleColors.border),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header row: Day columns
                      _buildHeaderRow(dayHeaders, isCurrentWeek, todayIndex),

                      // Slot rows 1–6
                      for (int slot = 1; slot <= 6; slot++)
                        _buildSlotRow(slot, dayHeaders.length, isCurrentWeek, todayIndex),
                    ],
                  ),
                ),
              );

              if (needsScroll) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: gridContent,
                );
              }
              return gridContent;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekNavBar(bool isCurrentWeek) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('dd/MM');
    final weekLabel = '${fmt.format(_weekStart)} — ${fmt.format(weekEnd)}';
    final yearLabel = _weekStart.year.toString();

    return Row(
      children: [
        // Year badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BirdleColors.brandLight,
            borderRadius: BirdleRadius.smBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 14, color: BirdleColors.brand),
              const SizedBox(width: 6),
              Text(
                'NĂM $yearLabel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BirdleColors.brand,
                  fontFamily: BirdleTypography.fontFamily,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Week label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BirdleColors.surfaceSecondary,
            borderRadius: BirdleRadius.smBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range, size: 14, color: BirdleColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'TUẦN: $weekLabel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BirdleColors.textSecondary,
                  fontFamily: BirdleTypography.fontFamily,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Navigation buttons
        IconButton(
          onPressed: _previousWeek,
          icon: const Icon(Icons.chevron_left, size: 20),
          tooltip: 'Tuần trước',
          style: IconButton.styleFrom(
            backgroundColor: BirdleColors.surfaceSecondary,
            foregroundColor: BirdleColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: isCurrentWeek ? null : _goToCurrentWeek,
          child: Text(
            'Tuần này',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isCurrentWeek ? BirdleColors.textDisabled : BirdleColors.brand,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _nextWeek,
          icon: const Icon(Icons.chevron_right, size: 20),
          tooltip: 'Tuần sau',
          style: IconButton.styleFrom(
            backgroundColor: BirdleColors.surfaceSecondary,
            foregroundColor: BirdleColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(List<String> dayHeaders, bool isCurrentWeek, int todayIndex) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF4A90D9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(BirdleRadius.md),
          topRight: Radius.circular(BirdleRadius.md),
        ),
      ),
      child: Row(
        children: [
          // Slot column header
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Text(
              'SLOT',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: BirdleTypography.fontFamily,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Day columns
          for (int i = 0; i < dayHeaders.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: (isCurrentWeek && (i + 1) == todayIndex)
                      ? const Color(0xFF3A7BC8)
                      : Colors.transparent,
                ),
                child: Column(
                  children: [
                    Text(
                      dayHeaders[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (isCurrentWeek && (i + 1) == todayIndex)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                        fontFamily: BirdleTypography.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM').format(_weekStart.add(Duration(days: i))),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: (isCurrentWeek && (i + 1) == todayIndex)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontFamily: BirdleTypography.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(int slot, int dayCount, bool isCurrentWeek, int todayIndex) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BirdleColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Slot label
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary.withValues(alpha: 0.5),
                border: Border(
                  right: BorderSide(color: BirdleColors.border.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Slot $slot',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BirdleColors.textPrimary,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _slotTimeShort(slot),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: BirdleColors.textMuted,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                ],
              ),
            ),

            // Day cells
            for (int day = 1; day <= dayCount; day++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: (isCurrentWeek && day == todayIndex)
                        ? const Color(0xFFF0F7FF)
                        : Colors.transparent,
                    border: Border(
                      right: day < dayCount
                          ? BorderSide(color: BirdleColors.border.withValues(alpha: 0.3))
                          : BorderSide.none,
                    ),
                  ),
                  child: _buildCellContent(slot, day),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellContent(int slot, int dayIndex) {
    final classes = _classesAt(slot, dayIndex);
    if (classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '-',
            style: TextStyle(
              fontSize: 12,
              color: BirdleColors.textDisabled,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
        ),
      );
    }

    final cellDate = _weekStart.add(Duration(days: dayIndex - 1));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: classes.map((c) => _buildClassCell(c, cellDate)).toList(),
      ),
    );
  }

  Widget _buildClassCell(ClassOverviewItem c, DateTime cellDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(cellDate.year, cellDate.month, cellDate.day);

    final bool isFuture = targetDate.isAfter(today);
    final bool isToday = targetDate.isAtSameMomentAs(today);

    // Xác định trạng thái điểm danh cho ô lịch cụ thể theo ngày:
    // 1. TƯƠNG LAI (chưa tới ngày dạy): BẮT BUỘC "Not yet"
    // 2. HÔM NAY: "Done" nếu buổi hôm nay đã điểm danh, ngược lại "Not yet"
    // 3. QUÁ KHỨ: "Done" nếu đã có lịch sử điểm danh buổi đó
    final bool isDone;
    if (isFuture) {
      isDone = false; // Chưa tới ngày dạy thì tuyệt đối không thể là Done
    } else if (isToday) {
      isDone = c.isAttendanceDone;
    } else {
      // Quá khứ
      if (c.lastDate != null) {
        final lastD = DateTime(c.lastDate!.year, c.lastDate!.month, c.lastDate!.day);
        isDone = !lastD.isBefore(targetDate);
      } else {
        isDone = c.lastSession != null && c.lastSession! > 0;
      }
    }

    final statusColor = isDone ? BirdleColors.success : BirdleColors.danger;
    final statusBg = isDone ? BirdleColors.successLight : BirdleColors.dangerLight;
    final statusLabel = isDone ? '(Attended)' : '(Not yet)';

    return MouseRegion(
      cursor: widget.onClassTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onClassTap != null ? () => widget.onClassTap!(c) : null,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: BirdleColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: BirdleColors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class name + subject code
              Text(
                '${c.className}-${c.subjectCode}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: BirdleColors.textPrimary,
                  fontFamily: BirdleTypography.fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Room
              Text(
                'at ${c.room}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: BirdleColors.textSecondary,
                  fontFamily: BirdleTypography.fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Status badge row
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontFamily: BirdleTypography.fontFamily,
                      ),
                    ),
                  ),

                  // EduNext-style badge (subject badge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: BirdleColors.brandLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      c.subjectCode.isNotEmpty ? c.subjectCode : 'Class',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: BirdleColors.brand,
                        fontFamily: BirdleTypography.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // Time slot chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone
                      ? BirdleColors.successLight
                      : const Color(0xFFE8F7F1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  c.slotTime,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? BirdleColors.success
                        : const Color(0xFF10845F),
                    fontFamily: BirdleTypography.fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _slotTimeShort(int slot) {
    switch (slot) {
      case 1: return '7:00-9:15';
      case 2: return '9:30-11:45';
      case 3: return '12:30-14:45';
      case 4: return '15:00-17:15';
      case 5: return '17:30-19:45';
      case 6: return '20:00-22:15';
      default: return '';
    }
  }
}
