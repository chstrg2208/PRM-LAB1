import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_overview_item.dart';
import '../services/google_sheet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weekly_schedule_view.dart';

/// Màn hình Lịch dạy điểm danh (Attendance Timetable Hub).
///
/// Hiển thị trực tiếp Lịch dạy theo tuần (Lecture of week) chuẩn FAP
/// với đầy đủ các Slot (1–6) × Thứ trong tuần (T2–CN).
/// Hỗ trợ Dependency Injection cho `onLoadOverview` và `initialOverview` phục vụ testing độc lập.
class AttendanceOverviewView extends StatefulWidget {
  /// URL Google Apps Script đã cấu hình
  final String sheetUrl;

  /// Callback khi giảng viên chọn một lớp để điểm danh
  final void Function(String className) onSelectClass;

  /// Callback điều hướng tới màn hình Settings
  final VoidCallback? onGoToSettings;

  /// Dữ liệu khởi tạo (tùy chọn, phục vụ kiểm thử)
  final AttendanceOverview? initialOverview;

  /// Callback nạp dữ liệu tùy biến (tùy chọn, phục vụ Dependency Injection / Test)
  final Future<AttendanceOverview> Function()? onLoadOverview;

  /// Callback nâng cao khi giảng viên chọn lớp kèm metadata và cờ hôm nay
  final void Function(ClassOverviewItem item, bool isToday)? onSelectClassItem;

  const AttendanceOverviewView({
    super.key,
    required this.sheetUrl,
    required this.onSelectClass,
    this.onSelectClassItem,
    this.onGoToSettings,
    this.initialOverview,
    this.onLoadOverview,
  });

  @override
  State<AttendanceOverviewView> createState() => _AttendanceOverviewViewState();
}

class _AttendanceOverviewViewState extends State<AttendanceOverviewView> {
  AttendanceOverview? _overview;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialOverview != null) {
      _overview = widget.initialOverview;
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOverview != oldWidget.initialOverview && widget.initialOverview != null) {
      setState(() {
        _overview = widget.initialOverview;
      });
    }
  }

  Future<void> _load() async {
    if (widget.onLoadOverview == null && widget.sheetUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = null;
        _overview = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final AttendanceOverview overview;
      if (widget.onLoadOverview != null) {
        overview = await widget.onLoadOverview!();
      } else {
        overview = await GoogleSheetService.fetchAttendanceOverview(widget.sheetUrl);
      }
      if (mounted) {
        setState(() {
          _overview = overview;
          _isLoading = false;
        });
      }
    } on GoogleSheetException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi tải lịch dạy: $e';
          _isLoading = false;
        });
      }
    }
  }

  static String _formatHeaderDate(DateTime dt) {
    const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final dayName = days[dt.weekday - 1];
    final dateStr = DateFormat('dd/MM/yyyy').format(dt);
    return '$dayName, $dateStr';
  }

  /// Xử lý khi bấm vào một ô lớp học trên lịch tuần
  void _handleClassItemTap(ClassOverviewItem item) {
    if (widget.onSelectClassItem != null) {
      final isToday = _overview?.todayClasses.any((c) => c.className == item.className) ?? false;
      widget.onSelectClassItem!(item, isToday);
    } else {
      widget.onSelectClass(item.className);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance', style: BirdleTypography.pageTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Lịch dạy tuần · ${_formatHeaderDate(DateTime.now())}',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const Spacer(),
              _buildRefreshButton(),
            ],
          ),
          const SizedBox(height: 20),

          // ── Body: Lịch dạy tuần dạng Calendar ───────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.brand),
            )
          : const Icon(Icons.refresh, size: 18, color: BirdleColors.textSecondary),
      tooltip: 'Làm mới',
      onPressed: _isLoading ? null : _load,
    );
  }

  Widget _buildBody() {
    // Chưa cấu hình Sheet URL và không có custom loader
    if (widget.onLoadOverview == null && widget.sheetUrl.isEmpty && widget.initialOverview == null) {
      return _buildEmptyState(
        icon: Icons.link_off_outlined,
        title: 'Chưa kết nối Google Sheet',
        subtitle: 'Vào Settings để cấu hình URL Google Apps Script.',
        action: widget.onGoToSettings != null
            ? TextButton.icon(
                onPressed: widget.onGoToSettings,
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Mở Settings'),
              )
            : null,
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: BirdleColors.brand),
      );
    }

    if (_error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        iconColor: BirdleColors.danger,
        title: 'Không thể tải dữ liệu',
        subtitle: _error!,
        action: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16, color: BirdleColors.brand),
          label: const Text('Thử lại', style: TextStyle(color: BirdleColors.brand)),
        ),
      );
    }

    if (_overview == null || _overview!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Chưa có lịch dạy nào',
        subtitle: 'Tạo sheet lớp học trong Google Sheets rồi nhấn làm mới.',
        action: IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: BirdleColors.brand),
        ),
      );
    }

    // Hiển thị trực tiếp Lịch dạy theo tuần (Lecture of week)
    return WeeklyScheduleView(
      allClasses: _overview!.allClasses,
      onClassTap: _handleClassItemTap,
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = BirdleColors.textMuted,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: iconColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title, style: BirdleTypography.sectionTitle),
          const SizedBox(height: 8),
          Text(subtitle, style: BirdleTypography.metadata, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}
