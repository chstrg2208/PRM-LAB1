import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/ai_analytics_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

class AiInsightsView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final VoidCallback onConfigureByok;
  final List<Map<String, dynamic>>? historyLogs;
  final AnalyticsDataStatus analyticsStatus;
  final String? analyticsError;
  final bool isLoadingAnalytics;
  final VoidCallback? onRetryLoadAnalytics;

  const AiInsightsView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.onConfigureByok,
    this.historyLogs,
    this.analyticsStatus = AnalyticsDataStatus.loaded,
    this.analyticsError,
    this.isLoadingAnalytics = false,
    this.onRetryLoadAnalytics,
  });

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  final TextEditingController _questionCtrl = TextEditingController();
  final List<Map<String, String>> _insightsQnA = [];
  late AiAttendanceReport _report;
  bool _isLoadingAi = false;
  String? _currentQuery;

  @override
  void initState() {
    super.initState();
    _refreshAnalysis();
  }

  @override
  void didUpdateWidget(covariant AiInsightsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.students != widget.students ||
        oldWidget.records != widget.records ||
        oldWidget.historyLogs != widget.historyLogs ||
        oldWidget.analyticsStatus != widget.analyticsStatus ||
        oldWidget.analyticsError != widget.analyticsError) {
      _refreshAnalysis();
    }
  }

  void _refreshAnalysis() {
    _report = AiAnalyticsService.analyzeAttendance(
      students: widget.students,
      currentRecords: widget.records,
      historyLogs: widget.historyLogs,
      status: widget.analyticsStatus,
      errorMessage: widget.analyticsError,
    );
  }

  void _askAi(String question) async {
    final q = question.trim();
    if (q.isEmpty || _isLoadingAi) return;

    final apiKey = StorageService.getGeminiApiKey();
    setState(() {
      _isLoadingAi = true;
      _currentQuery = q;
      _questionCtrl.clear();
    });

    final answer = await AiAnalyticsService.askGeminiAi(
      apiKey: apiKey,
      prompt: q,
      report: _report,
      students: widget.students,
    );

    if (mounted) {
      setState(() {
        _isLoadingAi = false;
        _insightsQnA.insert(0, {'q': q, 'a': answer});
        _currentQuery = null;
      });
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = StorageService.getGeminiApiKey();
    final hasApiKey = apiKey.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Section 18 design.md)
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Insights', style: BirdleTypography.pageTitle),
                  SizedBox(height: 4),
                  Text(
                    'Understand attendance patterns using your data',
                    style: BirdleTypography.metadata,
                  ),
                ],
              ),
              const Spacer(),
              if (!hasApiKey)
                BirdleSecondaryButton(
                  icon: Icons.key_outlined,
                  label: 'Cấu hình BYOK Key',
                  onPressed: widget.onConfigureByok,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // BYOK Transparency Banner (Section 19 design.md)
          if (!hasApiKey)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: BirdleColors.textSecondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI Insights đang chạy ở chế độ Phân tích quy tắc nội bộ (Offline). Nhập Google Gemini API Key của bạn để mở khóa mô hình phân tích tạo sinh tự nhiên.',
                      style: BirdleTypography.metadata,
                    ),
                  ),
                  BirdleGhostButton(
                    label: 'Configure BYOK',
                    color: BirdleColors.brand,
                    onPressed: widget.onConfigureByok,
                  ),
                ],
              ),
            ),

          // Analytics Data Status Banner
          if (widget.isLoadingAnalytics) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.brand),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đang tải dữ liệu lịch sử điểm danh từ Google Sheets...',
                      style: BirdleTypography.metadata,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_report.status == AnalyticsDataStatus.unconfigured) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.surfaceSecondary,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_off, size: 16, color: BirdleColors.warning),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Chưa cấu hình URL Google Apps Script để tải dữ liệu lịch sử điểm danh từ Google Sheets.',
                      style: BirdleTypography.metadata,
                    ),
                  ),
                  BirdleGhostButton(
                    label: 'Cấu hình ngay',
                    color: BirdleColors.brand,
                    onPressed: widget.onConfigureByok,
                  ),
                ],
              ),
            ),
          ] else if (_report.status == AnalyticsDataStatus.error) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BirdleColors.dangerLight,
                borderRadius: BirdleRadius.smBorder,
                border: Border.all(color: BirdleColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: BirdleColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lỗi tải lịch sử điểm danh: ${_report.errorMessage ?? "Không thể kết nối đến Google Sheets."}',
                      style: const TextStyle(fontSize: 12, color: BirdleColors.danger),
                    ),
                  ),
                  if (widget.onRetryLoadAnalytics != null)
                    BirdleGhostButton(
                      label: 'Thử lại',
                      color: BirdleColors.danger,
                      onPressed: widget.onRetryLoadAnalytics,
                    ),
                ],
              ),
            ),
          ],

          // Attendance Health & Key Observations (Section 18 design.md)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Health Card
              Expanded(
                flex: 2,
                child: BirdleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance Health', style: BirdleTypography.cardTitle),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_report.overallAttendanceRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: BirdleColors.brand,
                              fontFamily: BirdleTypography.fontFamily,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _report.overallAttendanceRate >= 80.0
                                  ? BirdleColors.successLight
                                  : BirdleColors.warningLight,
                              borderRadius: BirdleRadius.pillBorder,
                            ),
                            child: Text(
                              _report.overallAttendanceRate >= 80.0 ? 'Ổn định (Stable)' : 'Cần can thiệp',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _report.overallAttendanceRate >= 80.0
                                    ? BirdleColors.success
                                    : BirdleColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Lớp ${widget.currentClass} có ${_report.failedStudents.length} sinh viên cấm thi và ${_report.warningStudents.length} sinh viên diện nguy cơ.',
                        style: BirdleTypography.metadata,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Key Observations Card
              Expanded(
                flex: 4,
                child: BirdleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Key Observations', style: BirdleTypography.cardTitle),
                      const SizedBox(height: 12),
                      if (widget.isLoadingAnalytics) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.brand),
                            ),
                            SizedBox(width: 10),
                            Text('Đang tải dữ liệu lịch sử điểm danh...', style: BirdleTypography.metadata),
                          ],
                        ),
                      ] else if (_report.status == AnalyticsDataStatus.unconfigured) ...[
                        _buildObservationItem(
                          Icons.link_off,
                          'Chưa cấu hình Google Sheet để đồng bộ lịch sử điểm danh.',
                        ),
                      ] else if (_report.status == AnalyticsDataStatus.error) ...[
                        _buildObservationItem(
                          Icons.error_outline,
                          'Lỗi tải lịch sử điểm danh: ${_report.errorMessage ?? "Không thể kết nối Google Sheet"}.',
                        ),
                        if (widget.onRetryLoadAnalytics != null) ...[
                          const SizedBox(height: 8),
                          BirdleGhostButton(
                            label: 'Thử lại (Retry)',
                            color: BirdleColors.brand,
                            onPressed: widget.onRetryLoadAnalytics,
                          ),
                        ],
                      ] else if (_report.status == AnalyticsDataStatus.empty) ...[
                        _buildObservationItem(
                          Icons.info_outline,
                          'Chưa đủ dữ liệu thống kê lịch sử.',
                        ),
                        const SizedBox(height: 10),
                        _buildObservationItem(
                          Icons.warning_amber_outlined,
                          '${_report.warningStudents.length} sinh viên đang tiệm cận mốc 20% cấm thi (15% - 20%). Cần gửi cảnh báo học vụ trước buổi học kế tiếp.',
                        ),
                      ] else ...[
                        _buildObservationItem(
                          Icons.schedule,
                          'Slot ${_report.worstSlot.slot} (${_report.worstSlot.slotTime}) có tỷ lệ nghỉ cao nhất (${_report.worstSlot.absentRate.toStringAsFixed(1)}% vắng). Cân nhắc điểm danh đột xuất đầu giờ.',
                        ),
                        const SizedBox(height: 10),
                        _buildObservationItem(
                          Icons.calendar_today_outlined,
                          '${_report.worstDay.dayName} ghi nhận nhiều lượt vắng nhất (${_report.worstDay.absentRate.toStringAsFixed(1)}%). Nên gửi nhắc nhở hoặc chấm điểm quiz ngắn.',
                        ),
                        const SizedBox(height: 10),
                        _buildObservationItem(
                          Icons.warning_amber_outlined,
                          '${_report.warningStudents.length} sinh viên đang tiệm cận mốc 20% cấm thi (15% - 20%). Cần gửi cảnh báo học vụ trước buổi học kế tiếp.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Ask About Your Data (Section 18 design.md)
          BirdleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask About Your Data', style: BirdleTypography.cardTitle),
                const SizedBox(height: 6),
                const Text(
                  'Đặt câu hỏi về dữ liệu điểm danh thực tế của lớp học. Trợ lý sử dụng số liệu xác thực từ database.',
                  style: BirdleTypography.metadata,
                ),
                const SizedBox(height: 16),

                // Prompt Input Box
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionCtrl,
                        style: const TextStyle(fontSize: 13, color: BirdleColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ask about this attendance data (e.g., Sinh viên nào có nguy cơ cấm thi?)...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: BirdleColors.textMuted),
                          prefixIcon: const Icon(Icons.help_outline, size: 16, color: BirdleColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: _askAi,
                      ),
                    ),
                    const SizedBox(width: 10),
                    BirdlePrimaryButton(
                      label: 'Hỏi AI',
                      isLoading: _isLoadingAi,
                      onPressed: () => _askAi(_questionCtrl.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Suggested questions chips (Section 18 design.md)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSuggestedChip('Slot mấy sinh viên nghỉ nhiều nhất?'),
                    _buildSuggestedChip('Thứ mấy sinh viên hay vắng?'),
                    _buildSuggestedChip('Danh sách sinh viên cấm thi hoặc nguy cơ?'),
                    _buildSuggestedChip('Tư vấn giải pháp cải thiện chuyên cần?'),
                  ],
                ),

                // Responses Stream
                if (_isLoadingAi && _currentQuery != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.brand),
                      ),
                      const SizedBox(width: 10),
                      Text('Analyzing attendance data for "$_currentQuery"...', style: BirdleTypography.metadata),
                    ],
                  ),
                ],

                if (_insightsQnA.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _insightsQnA.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _insightsQnA[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BirdleColors.surfaceSecondary,
                          borderRadius: BirdleRadius.smBorder,
                          border: Border.all(color: BirdleColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 14, color: BirdleColors.brand),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['q'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: BirdleColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['a'] ?? '',
                              style: const TextStyle(fontSize: 13, color: BirdleColors.textPrimary, height: 1.45),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: BirdleColors.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: BirdleTypography.body),
        ),
      ],
    );
  }

  Widget _buildSuggestedChip(String label) {
    return InkWell(
      onTap: () => _askAi(label),
      borderRadius: BirdleRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: BirdleColors.surfaceSecondary,
          borderRadius: BirdleRadius.pillBorder,
          border: Border.all(color: BirdleColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: BirdleColors.textSecondary),
        ),
      ),
    );
  }
}
