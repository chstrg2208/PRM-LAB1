import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/class_overview_item.dart';
import '../services/google_sheet_service.dart';
import '../theme/app_theme.dart';

/// ATD-04: Màn hình Hub tổng quan điểm danh.
///
/// Hiển thị danh sách tất cả lớp học được phân chia thành 2 nhóm:
/// - **Lớp hôm nay**: lớp có lịch học khớp với ngày hiện tại
/// - **Các lớp khác**: lớp học không có buổi hôm nay
///
/// Click vào một card lớp sẽ gọi [onSelectClass] để điều hướng vào [AttendanceView].
class AttendanceOverviewView extends StatefulWidget {
  /// URL Google Apps Script đã cấu hình
  final String sheetUrl;

  /// Callback khi giảng viên chọn một lớp để điểm danh
  final void Function(String className) onSelectClass;

  /// Callback điều hướng tới màn hình Settings
  final VoidCallback? onGoToSettings;

  const AttendanceOverviewView({
    super.key,
    required this.sheetUrl,
    required this.onSelectClass,
    this.onGoToSettings,
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
    _load();
  }

  Future<void> _load() async {
    if (widget.sheetUrl.isEmpty) {
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
      final overview = await GoogleSheetService.fetchAttendanceOverview(widget.sheetUrl);
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
    // Chưa cấu hình Sheet URL
    if (widget.sheetUrl.isEmpty) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: BirdleColors.brand),
            SizedBox(height: 16),
            Text('Đang tải danh sách lớp học...', style: BirdleTypography.metadata),
          ],
        ),
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
          // ── Lớp hôm nay ──────────────────────────────────────────────────
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

          // ── Các lớp khác ─────────────────────────────────────────────────
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

  Widget _buildSectionHeader(String label, {int? count, Color color = BirdleColors.textMuted}) {
    return Row(
      children: [
        Container(
          width: 3,
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
            fontSize: 11,
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
      children: items.map((item) => _ClassCard(
        item: item,
        isToday: isToday,
        onTap: () => widget.onSelectClass(item.className),
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

// ─────────────────────────────────────────────────────────────────────────────
/// Card hiển thị thông tin tổng quan một lớp học
// ─────────────────────────────────────────────────────────────────────────────
class _ClassCard extends StatefulWidget {
  final ClassOverviewItem item;
  final bool isToday;
  final VoidCallback onTap;

  const _ClassCard({
    required this.item,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // Màu accent theo trạng thái
    final Color accentColor = widget.isToday
        ? (item.isAttendanceDone ? BirdleColors.success : BirdleColors.brand)
        : BirdleColors.textMuted;
    final Color accentLight = widget.isToday
        ? (item.isAttendanceDone ? BirdleColors.successLight : BirdleColors.brandLight)
        : BirdleColors.surfaceSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BirdleColors.surface,
            borderRadius: BirdleRadius.mdBorder,
            border: Border.all(
              color: _hovered
                  ? accentColor.withValues(alpha: 0.5)
                  : BirdleColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: class badge + status badge ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.className,
                      style: BirdleTypography.cardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(item: item, isToday: widget.isToday),
                ],
              ),
              const SizedBox(height: 6),

              // Subject
              Text(
                item.subject.isNotEmpty ? item.subject : item.subjectCode,
                style: BirdleTypography.metadata,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // ── Info row ──────────────────────────────────────────────────
              Row(
                children: [
                  _InfoChip(icon: Icons.schedule_outlined, label: 'Slot ${item.slot} · ${item.slotTime}'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _InfoChip(icon: Icons.calendar_today_outlined, label: item.daysOfWeek),
                  const SizedBox(width: 12),
                  _InfoChip(icon: Icons.room_outlined, label: item.room),
                ],
              ),
              const SizedBox(height: 14),

              // ── Progress bar ──────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Buổi ${item.currentSession}/${item.totalSessions}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(item.progressRatio * 100).toStringAsFixed(0)}%',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.progressRatio,
                  minHeight: 5,
                  backgroundColor: accentLight,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 14),

              // ── Bottom row: last attendance / next date ───────────────────
              if (widget.isToday)
                _TodayActionRow(item: item, onTap: widget.onTap, accentColor: accentColor)
              else
                _OtherClassFooter(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge (Hôm nay / Đã điểm danh / Các lớp khác / Buổi X)
class _StatusBadge extends StatelessWidget {
  final ClassOverviewItem item;
  final bool isToday;

  const _StatusBadge({required this.item, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;

    if (!isToday) {
      if (item.lastSession != null && item.lastSession! > 0) {
        label = 'Buổi ${item.lastSession}';
        bg = BirdleColors.pendingLight;
        fg = BirdleColors.pending;
      } else {
        label = 'Khác';
        bg = BirdleColors.pendingLight;
        fg = BirdleColors.pending;
      }
    } else if (item.isAttendanceDone) {
      label = '✓ Đã điểm danh';
      bg = BirdleColors.successLight;
      fg = BirdleColors.success;
    } else {
      label = 'Hôm nay';
      bg = BirdleColors.brandLight;
      fg = BirdleColors.brand;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFamily: BirdleTypography.fontFamily,
        ),
      ),
    );
  }
}

/// Chip icon + label nhỏ
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: BirdleColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: BirdleTypography.metadata),
      ],
    );
  }
}

/// Footer cho lớp học hôm nay: nút "Mở điểm danh"
class _TodayActionRow extends StatelessWidget {
  final ClassOverviewItem item;
  final VoidCallback onTap;
  final Color accentColor;

  const _TodayActionRow({required this.item, required this.onTap, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          item.isAttendanceDone ? Icons.visibility_outlined : Icons.fact_check_outlined,
          size: 15,
          color: accentColor,
        ),
        label: Text(
          item.isAttendanceDone ? 'Xem điểm danh' : 'Mở điểm danh',
          style: TextStyle(fontSize: 13, color: accentColor, fontFamily: BirdleTypography.fontFamily),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BirdleRadius.smBorder),
        ),
      ),
    );
  }
}

/// Footer cho lớp khác: hiển thị buổi điểm danh gần nhất + ngày học tiếp theo
class _OtherClassFooter extends StatelessWidget {
  final ClassOverviewItem item;

  const _OtherClassFooter({required this.item});

  @override
  Widget build(BuildContext context) {
    final lastDateStr = item.lastDate != null
        ? DateFormat('dd/MM/yyyy').format(item.lastDate!)
        : '—';
    final nextDateStr = item.nextDate != null
        ? DateFormat('dd/MM/yyyy').format(item.nextDate!)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 13, color: BirdleColors.textMuted),
            const SizedBox(width: 4),
            Text(
              'Gần nhất: ${item.lastSession != null ? "Buổi ${item.lastSession}" : "—"} · $lastDateStr',
              style: BirdleTypography.metadata,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.arrow_forward_outlined, size: 13, color: BirdleColors.textMuted),
            const SizedBox(width: 4),
            Text(
              'Học tiếp: $nextDateStr',
              style: BirdleTypography.metadata,
            ),
          ],
        ),
      ],
    );
  }
}
