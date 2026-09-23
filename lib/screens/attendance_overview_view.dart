import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_overview_item.dart';
import '../services/google_sheet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_class_card.dart';

/// ATD-05: Màn hình Hub tổng quan điểm danh (Attendance Overview Hub).
///
/// Hiển thị danh sách tất cả lớp học được phân chia thành 2 khu vực:
/// - **LỚP HỌC HÔM NAY**: Các lớp có lịch học khớp với ngày hiện tại (hoặc nextDate)
/// - **CÁC LỚP KHÁC**: Các lớp học không có lịch hôm nay (xem/sửa lịch sử các buổi đã qua)
///
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
          _error = 'Lỗi tải tổng quan: $e';
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
                    'Tổng quan buổi học · ${_formatHeaderDate(DateTime.now())}',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const Spacer(),
              _buildRefreshButton(),
            ],
          ),
          const SizedBox(height: 24),

          // ── Body ─────────────────────────────────────────────────────────────
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
      return _buildSkeletonGrid();
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
        icon: Icons.class_outlined,
        title: 'Chưa có lớp học nào',
        subtitle: 'Tạo sheet lớp học trong Google Sheets rồi nhấn làm mới.',
        action: IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: BirdleColors.brand),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Khu vực 1: Lớp hôm nay ───────────────────────────────────────
          if (_overview!.todayClasses.isNotEmpty) ...[
            _buildSectionHeader(
              'LỚP HÔM NAY',
              count: _overview!.todayClasses.length,
              color: BirdleColors.brand,
            ),
            const SizedBox(height: 12),
            _buildClassGrid(_overview!.todayClasses, isToday: true),
            const SizedBox(height: 28),
          ],

          // ── Khu vực 2: Các lớp khác ──────────────────────────────────────
          if (_overview!.otherClasses.isNotEmpty) ...[
            _buildSectionHeader(
              'CÁC LỚP KHÁC',
              count: _overview!.otherClasses.length,
              color: BirdleColors.textMuted,
            ),
            const SizedBox(height: 12),
            _buildClassGrid(_overview!.otherClasses, isToday: false),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('LỚP HÔM NAY', color: BirdleColors.brand),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AttendanceClassCardSkeleton(),
              AttendanceClassCardSkeleton(),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionHeader('CÁC LỚP KHÁC', color: BirdleColors.textMuted),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AttendanceClassCardSkeleton(),
              AttendanceClassCardSkeleton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, {int? count, Color color = BirdleColors.textMuted}) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
            fontFamily: BirdleTypography.fontFamily,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: BirdleTypography.fontFamily,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClassGrid(List<ClassOverviewItem> items, {required bool isToday}) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) => AttendanceClassCard(
        item: item,
        isToday: isToday,
        onTap: () {
          widget.onSelectClass(item.className);
          widget.onSelectClassItem?.call(item, isToday);
        },
        onActionPressed: () {
          widget.onSelectClass(item.className);
          widget.onSelectClassItem?.call(item, isToday);
        },
      )).toList(),
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
