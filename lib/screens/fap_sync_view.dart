import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/fap_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';

class FapSyncView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final int currentSlot;
  final Function(List<Student>) onImportStudents;
  final VoidCallback onSaveToSheet;

  const FapSyncView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.currentSlot,
    required this.onImportStudents,
    required this.onSaveToSheet,
  });

  @override
  State<FapSyncView> createState() => _FapSyncViewState();
}

class _FapSyncViewState extends State<FapSyncView> {
  int _activeTab = 0; // 0: FAP Sync, 1: Import Center
  bool _isSyncing = false;
  int _syncStep = 0; // 0 to 4
  final TextEditingController _importTextCtrl = TextEditingController();
  List<Student> _parsedStudents = [];
  bool _hasParsed = false;
  final List<Map<String, dynamic>> _syncHistory = [
    {
      'time': '09:42',
      'class': 'SE1801',
      'records': 9,
      'result': 'Thành công',
      'status': 'success',
    },
    {
      'time': '08:15',
      'class': 'SE1801',
      'records': 9,
      'result': 'Thành công',
      'status': 'success',
    },
  ];

  @override
  void dispose() {
    _importTextCtrl.dispose();
    super.dispose();
  }

  void _runFapSyncSimulation() async {
    setState(() {
      _isSyncing = true;
      _syncStep = 1;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _syncStep = 2);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _syncStep = 3);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _syncStep = 4);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      final now = DateTime.now();
      _syncHistory.insert(0, {
        'time': DateFormat('HH:mm').format(now),
        'class': widget.currentClass,
        'records': widget.records.length,
        'result': 'Thành công',
        'status': 'success',
      });
    });

    final script = FapService.generateFapFillScript(widget.records);
    await Clipboard.setData(ClipboardData(text: script));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đã chuẩn bị script FAP & sao chép vào Clipboard. Dán vào F12 Console để hoàn tất!'),
          backgroundColor: BirdleColors.brand,
        ),
      );
    }
  }

  void _parseImportText() {
    final text = _importTextCtrl.text.trim();
    if (text.isEmpty) return;

    final list = FapService.parseStudentList(text, widget.currentClass);
    setState(() {
      _parsedStudents = list;
      _hasParsed = true;
    });
  }

  void _confirmImport() {
    if (_parsedStudents.isEmpty) return;
    widget.onImportStudents(_parsedStudents);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Đã nạp thành công ${_parsedStudents.length} sinh viên vào lớp ${widget.currentClass}!'),
        backgroundColor: BirdleColors.brand,
      ),
    );
    setState(() {
      _importTextCtrl.clear();
      _parsedStudents = [];
      _hasParsed = false;
      _activeTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FAP Integration & Import Center', style: BirdleTypography.pageTitle),
                    SizedBox(height: 4),
                    Text(
                      'Tích hợp luồng dữ liệu cổng FAP, xử lý file và đồng bộ điểm danh tự động',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),
              BirdleSecondaryButton(
                icon: Icons.open_in_new,
                label: 'Mở trang FAP (fap.fpt.edu.vn)',
                onPressed: () => StorageService.openBrowser('https://fap.fpt.edu.vn'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sub tabs (FAP Sync vs Import Center)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: BirdleColors.surfaceSecondary,
              borderRadius: BirdleRadius.smBorder,
              border: Border.all(color: BirdleColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton(0, 'FAP Sync & Auto-Fill', Icons.sync),
                _buildTabButton(1, 'Import Center & File Pipeline', Icons.file_upload_outlined),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_activeTab == 0) _buildFapSyncContent() else _buildImportCenterContent(),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BirdleRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? BirdleColors.surface : Colors.transparent,
          borderRadius: BirdleRadius.smBorder,
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? BirdleColors.brand : BirdleColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? BirdleColors.textPrimary : BirdleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFapSyncContent() {
    final presentCount = widget.records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = widget.records.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount = widget.records.where((r) => r.status == AttendanceStatus.late).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Connection & Action Card
        BirdleCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BirdleColors.brandLight,
                  borderRadius: BirdleRadius.smBorder,
                ),
                child: const Icon(Icons.bolt, color: BirdleColors.brand, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Lớp ${widget.currentClass} · Slot ${widget.currentSlot}', style: BirdleTypography.cardTitle),
                        const SizedBox(width: 10),
                        const ConnectionStatusChip(label: 'FAP Sẵn sàng', isConnected: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.students.length} sinh viên ($presentCount Có mặt, $absentCount Vắng, $lateCount Muộn) đang chờ gửi lên FAP',
                      style: BirdleTypography.metadata,
                    ),
                  ],
                ),
              ),
              BirdleSecondaryButton(
                icon: Icons.copy,
                label: 'Sao chép Script F12',
                onPressed: () async {
                  final script = FapService.generateFapFillScript(widget.records);
                  await Clipboard.setData(ClipboardData(text: script));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Đã sao chép mã script! Hãy dán vào F12 Console của FAP để tự động tích chọn.'),
                        backgroundColor: BirdleColors.brand,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              BirdlePrimaryButton(
                icon: Icons.sync,
                label: 'Sync to FAP',
                isLoading: _isSyncing,
                onPressed: _runFapSyncSimulation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Timeline Progress (Section 17 design.md)
        BirdleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quy trình Đồng bộ FAP (Sync Timeline)', style: BirdleTypography.cardTitle),
              const SizedBox(height: 16),
              _buildTimelineStep(
                1,
                'Kết nối cổng đào tạo FAP',
                'Xác thực phiên làm việc và định danh lớp ${widget.currentClass}',
                _syncStep >= 1,
                _syncStep == 1 && _isSyncing,
              ),
              _buildTimelineStep(
                2,
                'Đọc bảng điểm danh trên FAP',
                'Quét cấu trúc bảng và vị trí radio button theo MSSV',
                _syncStep >= 2,
                _syncStep == 2 && _isSyncing,
              ),
              _buildTimelineStep(
                3,
                'Kiểm tra & Đối chiếu dữ liệu (Validation)',
                'Khớp $presentCount Có mặt / $absentCount Vắng với danh sách sinh viên',
                _syncStep >= 3,
                _syncStep == 3 && _isSyncing,
              ),
              _buildTimelineStep(
                4,
                'Tự động điền & Highlight kết quả',
                'Tự động tick chọn radio và tô màu dòng sinh viên trên FAP',
                _syncStep >= 4,
                _syncStep == 4 && _isSyncing,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sync History (Section 17 design.md)
        BirdleCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Lịch sử Đồng bộ FAP (Sync History)', style: BirdleTypography.cardTitle),
              ),
              const Divider(),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: BirdleColors.surfaceSecondary),
                    children: ['THỜI GIAN', 'LỚP HỌC', 'BẢN GHI', 'KẾT QUẢ'].map((h) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(h, style: BirdleTypography.caption),
                      );
                    }).toList(),
                  ),
                  ..._syncHistory.map((row) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(row['time'] as String, style: BirdleTypography.bodyMedium),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(row['class'] as String, style: BirdleTypography.body),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('${row['records']} SV', style: BirdleTypography.metadata),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: BirdleColors.success),
                              const SizedBox(width: 6),
                              Text(row['result'] as String, style: const TextStyle(fontSize: 12.5, color: BirdleColors.success, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(int stepNumber, String title, String subtitle, bool isDone, bool isCurrent, {bool isLast = false}) {
    Color indicatorColor;
    Widget iconWidget;

    if (isCurrent) {
      indicatorColor = BirdleColors.brand;
      iconWidget = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (isDone) {
      indicatorColor = BirdleColors.brand;
      iconWidget = const Icon(Icons.check, size: 13, color: Colors.white);
    } else {
      indicatorColor = BirdleColors.border;
      iconWidget = Text('$stepNumber', style: const TextStyle(fontSize: 11, color: BirdleColors.textMuted, fontWeight: FontWeight.bold));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: iconWidget,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? BirdleColors.brand : BirdleColors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isDone || isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isDone || isCurrent ? BirdleColors.textPrimary : BirdleColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: BirdleTypography.metadata),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportCenterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop zone / Input Box (Section 15 design.md)
        BirdleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nạp danh sách sinh viên & điểm danh', style: BirdleTypography.cardTitle),
              const SizedBox(height: 4),
              const Text(
                'Dán nội dung bảng từ FAP (gồm cột MSSV, Họ tên) hoặc dán text để hệ thống tự động bóc tách',
                style: BirdleTypography.metadata,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _importTextCtrl,
                maxLines: 5,
                style: const TextStyle(fontSize: 13, fontFamily: 'Consolas, monospace'),
                decoration: InputDecoration(
                  hintText: 'Ví dụ dán vào đây:\n1  SE170123  Nguyễn Văn An\n2  SE170456  Trần Thị Bình\n3  CE190585  Lâm Quốc Minh...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: BirdleColors.textMuted),
                  fillColor: BirdleColors.surfaceSecondary,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BirdleRadius.smBorder,
                    borderSide: const BorderSide(color: BirdleColors.border),
                  ),
                ),
                onChanged: (_) {
                  if (_hasParsed) {
                    setState(() => _hasParsed = false);
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: BirdleColors.textMuted),
                  const SizedBox(width: 6),
                  const Text('Hỗ trợ định dạng: Text, HTML Table, CSV, JSON', style: BirdleTypography.metadata),
                  const Spacer(),
                  BirdleSecondaryButton(
                    label: 'Xóa',
                    onPressed: () {
                      _importTextCtrl.clear();
                      setState(() {
                        _parsedStudents = [];
                        _hasParsed = false;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  BirdlePrimaryButton(
                    icon: Icons.filter_list,
                    label: 'Phân tích & Preview',
                    onPressed: _parseImportText,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Import Preview (Section 16 design.md)
        if (_hasParsed)
          BirdleCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Import Preview', style: BirdleTypography.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            'Phát hiện ${_parsedStudents.length} sinh viên hợp lệ sẵn sàng nạp vào lớp ${widget.currentClass}',
                            style: BirdleTypography.metadata,
                          ),
                        ],
                      ),
                      const Spacer(),
                      BirdleSecondaryButton(
                        label: 'Hủy bỏ',
                        onPressed: () => setState(() => _hasParsed = false),
                      ),
                      const SizedBox(width: 10),
                      BirdlePrimaryButton(
                        icon: Icons.done,
                        label: 'Xác nhận Nạp ${_parsedStudents.length} sinh viên',
                        onPressed: _confirmImport,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2.5),
                    3: FlexColumnWidth(2.5),
                    4: FlexColumnWidth(1.2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: BirdleColors.surfaceSecondary),
                      children: ['#', 'MÃ SINH VIÊN', 'HỌ VÀ TÊN', 'EMAIL FPT', 'XÁC THỰC'].map((h) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text(h, style: BirdleTypography.caption),
                        );
                      }).toList(),
                    ),
                    ..._parsedStudents.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final s = entry.value;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text('$i', style: BirdleTypography.metadata),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text(s.member, style: BirdleTypography.bodyMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text(s.fullName, style: BirdleTypography.body),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text(s.email, style: BirdleTypography.metadata),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle, size: 14, color: BirdleColors.success),
                                SizedBox(width: 4),
                                Text('Hợp lệ', style: TextStyle(fontSize: 12, color: BirdleColors.success, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
