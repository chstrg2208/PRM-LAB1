import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_schedule.dart';
import '../services/ai_analytics_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

class AiInsightsView extends StatefulWidget {
  final List<String> availableClasses;
  final ValueChanged<String>? onClassChanged;
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final VoidCallback onConfigureByok;
  final List<Map<String, dynamic>>? historyLogs;
  final AnalyticsDataStatus analyticsStatus;
  final String? analyticsError;
  final bool isLoadingAnalytics;
  final VoidCallback? onRetryLoadAnalytics;
  final ClassSchedule? schedule;

  const AiInsightsView({
    super.key,
    this.availableClasses = const [],
    this.onClassChanged,
    required this.students,
    required this.records,
    required this.currentClass,
    required this.onConfigureByok,
    this.historyLogs,
    this.analyticsStatus = AnalyticsDataStatus.loaded,
    this.analyticsError,
    this.isLoadingAnalytics = false,
    this.onRetryLoadAnalytics,
    this.schedule,
  });

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  final TextEditingController _questionCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
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
        oldWidget.currentClass != widget.currentClass ||
        oldWidget.availableClasses != widget.availableClasses ||
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
      schedule: widget.schedule,
    );

    if (mounted) {
      setState(() {
        _isLoadingAi = false;
        _insightsQnA.add({'q': q, 'a': answer});
        _currentQuery = null;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendEmailWarning() async {
    // 1. Thu thập cả nhóm Cấm thi (>20%) và nhóm Can thiệp sớm (còn 0-1 buổi vắng)
    final earlyWarning = widget.students
        .where((s) => s.remainingAllowedAbsences <= 1 || s.isBanned)
        .toList();

    // Khử trùng lặp theo rollNumber
    final Map<String, Student> uniqueMap = {};
    for (final s in [..._report.failedStudents, ..._report.warningStudents, ...earlyWarning]) {
      uniqueMap[s.rollNumber] = s;
    }
    final atRiskStudents = uniqueMap.values.toList();

    if (atRiskStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Chưa có sinh viên nào cần cảnh báo! Lớp đang an toàn.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Chuẩn hóa Email: Hỗ trợ linh hoạt cả mail cá nhân/mail thường của K19+ và mail FPT
    final emails = atRiskStudents
        .map((s) {
          final raw = s.email.trim();
          if (raw.isNotEmpty && raw.contains('@')) {
            return raw;
          }
          return '${s.rollNumber.toLowerCase()}@fpt.edu.vn';
        })
        .where((e) => e.isNotEmpty && e.contains('@'))
        .toSet()
        .toList();

    // 3. Soạn nội dung email súc tích, chuẩn quy chế đào tạo ĐH FPT
    final bodyLines = StringBuffer();
    bodyLines.writeln('Kính gửi các bạn sinh viên lớp ${widget.currentClass},');
    bodyLines.writeln('');
    bodyLines.writeln('Giảng viên thông báo cảnh báo chuyên cần (Quy chế Đào tạo ĐH FPT - ngưỡng vắng tối đa 20%):');
    bodyLines.writeln('Tỷ lệ chuyên cần chung của lớp: ${_report.overallAttendanceRate.toStringAsFixed(1)}%');
    bodyLines.writeln('');
    for (final s in atRiskStudents) {
      final status = s.isBanned
          ? 'CẤM THI (Vắng ${s.absentSlots}/${s.totalSlots} buổi - ${s.absentRate.toStringAsFixed(0)}%)'
          : 'CẢNH BÁO NGUY CƠ (Còn ${s.remainingAllowedAbsences} buổi vắng trước khi cấm thi)';
      bodyLines.writeln('• ${s.rollNumber} - ${s.fullName}: $status');
    }
    bodyLines.writeln('');
    bodyLines.writeln('Đề nghị các bạn lưu ý chuyên cần và liên hệ Giảng viên / Phòng Đào tạo nếu cần hỗ trợ.');
    bodyLines.writeln('Trân trọng.');

    final mailBody = bodyLines.toString();

    // 4. Encode URL an toàn tuyệt đối chống vỡ font qua class Uri của Dart
    final emailLaunchUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'bcc': emails.join(','),
        'subject': '[Cảnh báo chuyên cần FPT] Lớp ${widget.currentClass} - Thông báo nguy cơ cấm thi',
        'body': mailBody,
      },
    );

    // 5. Mở mail client và sao chép Clipboard dự phòng
    StorageService.openBrowser(emailLaunchUri.toString());
    await Clipboard.setData(ClipboardData(text: emails.join('; ')));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã mở mail & sao chép ${emails.length} email vào Clipboard!'),
          backgroundColor: BirdleColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Sao chép nội dung thư',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mailBody));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép toàn bộ mẫu email vào Clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _chatScrollCtrl.dispose();
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
          // Header với Expanded & Wrap chống tràn (Task 4.1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildClassDropdown(),
                  if (!hasApiKey)
                    BirdleSecondaryButton(
                      icon: Icons.key_outlined,
                      label: 'Cấu hình BYOK Key',
                      onPressed: widget.onConfigureByok,
                    ),
                ],
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

          // Dashboard phân tích xu hướng học vụ theo lớp (Task 4.3)
          _buildAcademicTrendsSection(),
          const SizedBox(height: 16),

          // Nút Gửi cảnh báo qua email (Sub-task 4.4)
          Builder(
            builder: (context) {
              final atRiskCount = widget.students.where((s) => s.remainingAllowedAbsences <= 1 || s.isBanned).length;
              return Row(
                children: [
                  BirdleSecondaryButton(
                    icon: Icons.email_outlined,
                    label: 'Gửi cảnh báo qua email',
                    iconColor: BirdleColors.warning,
                    onPressed: _sendEmailWarning,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$atRiskCount sinh viên trong diện cảnh báo (Can thiệp sớm & Cấm thi)',
                    style: BirdleTypography.metadata,
                  ),
                ],
              );
            },
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

                // Quick Prompt Chips (Task 5.1)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSuggestedChip('🔍 Ai đang có nguy cơ cấm thi?'),
                    _buildSuggestedChip('⏰ Slot nào sinh viên nghỉ nhiều nhất?'),
                    _buildSuggestedChip('📅 Thứ mấy sinh viên hay vắng?'),
                    _buildSuggestedChip('💡 Đề xuất giải pháp kéo sinh viên đi học?'),
                  ],
                ),

                // Chat Bubble Stream (Task 5.2)
                if (_insightsQnA.isNotEmpty || (_isLoadingAi && _currentQuery != null)) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 480),
                    child: ListView.builder(
                      controller: _chatScrollCtrl,
                      shrinkWrap: true,
                      itemCount: _insightsQnA.length + (_isLoadingAi && _currentQuery != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loading bubble at the end
                        if (index >= _insightsQnA.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildUserBubble(_currentQuery ?? ''),
                                const SizedBox(height: 10),
                                _buildAiTypingBubble(),
                              ],
                            ),
                          );
                        }

                        final item = _insightsQnA[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildUserBubble(item['q'] ?? ''),
                              const SizedBox(height: 10),
                              _buildAiBubble(item['a'] ?? ''),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSuggestedChip(String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _askAi(label),
        borderRadius: BirdleRadius.pillBorder,
        hoverColor: BirdleColors.brandLight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: BirdleColors.surfaceSecondary,
            borderRadius: BirdleRadius.pillBorder,
            border: Border.all(color: BirdleColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: BirdleColors.textSecondary),
          ),
        ),
      ),
    );
  }

  // ───── Bubble Chat Components (Task 5.2) ─────

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(flex: 2),
        Flexible(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BirdleColors.brand,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 14,
          backgroundColor: BirdleColors.surfaceSecondary,
          child: Icon(Icons.person, size: 16, color: BirdleColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildAiBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: BirdleColors.brandLight,
          child: Icon(Icons.auto_awesome, size: 16, color: BirdleColors.brand),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BirdleColors.surfaceSecondary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              border: Border.all(color: BirdleColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMarkdownText(text),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Đã sao chép nội dung!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BirdleRadius.smBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BirdleColors.surface,
                        borderRadius: BirdleRadius.smBorder,
                        border: Border.all(color: BirdleColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 12, color: BirdleColors.textMuted),
                          SizedBox(width: 4),
                          Text('Sao chép', style: TextStyle(fontSize: 11, color: BirdleColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildAiTypingBubble() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: BirdleColors.brandLight,
          child: Icon(Icons.auto_awesome, size: 16, color: BirdleColors.brand),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BirdleColors.surfaceSecondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: BirdleColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.brand),
              ),
              const SizedBox(width: 10),
              Text(
                'Đang phân tích dữ liệu...',
                style: TextStyle(fontSize: 12.5, color: BirdleColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Simple markdown parser: handles **bold**, bullet points (•, -), and line breaks
  Widget _buildMarkdownText(String text) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      final line = lines[i];
      // Parse bold **...**
      final parts = line.split(RegExp(r'\*\*'));
      for (int j = 0; j < parts.length; j++) {
        if (j % 2 == 1) {
          // Bold
          spans.add(TextSpan(
            text: parts[j],
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: BirdleColors.textPrimary,
              height: 1.5,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: parts[j],
            style: const TextStyle(
              fontSize: 13,
              color: BirdleColors.textPrimary,
              height: 1.5,
            ),
          ));
        }
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildClassDropdown() {
    final available = widget.availableClasses;
    final current = widget.currentClass;
    final selectedValue = available.contains(current)
        ? current
        : (available.isNotEmpty ? available.first : null);

    if (available.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: BirdleColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BirdleColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 16, color: BirdleColors.textMuted),
            SizedBox(width: 8),
            Text('Đang tải lớp...', style: TextStyle(fontSize: 13, color: BirdleColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BirdleColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: BirdleColors.textSecondary),
          isDense: false,
          items: available.map((cls) {
            return DropdownMenuItem<String>(
              value: cls,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_outlined, size: 16, color: BirdleColors.brand),
                  const SizedBox(width: 8),
                  Text(
                    cls,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BirdleColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newClass) {
            if (newClass != null && widget.onClassChanged != null) {
              widget.onClassChanged!(newClass);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAcademicTrendsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final card1 = _buildSlotTrendCard();
        final card2 = _buildDayTrendCard();
        final card3 = _buildEarlyWarningCard();

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card1,
              const SizedBox(height: 14),
              card2,
              const SizedBox(height: 14),
              card3,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 16),
              Expanded(child: card2),
              const SizedBox(width: 16),
              Expanded(child: card3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotTrendCard() {
    final hasAbsents = _report.worstSlot.absentCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BirdleColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasAbsents ? BirdleColors.warningLight : BirdleColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: hasAbsents ? BirdleColors.warning : BirdleColors.success,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Khung giờ vắng cao điểm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BirdleColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasAbsents) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Slot ${_report.worstSlot.slot}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BirdleColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _report.worstSlot.slotTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BirdleColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BirdleColors.warningLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_report.worstSlot.absentCount} lượt vắng (${_report.worstSlot.absentRate.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BirdleColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Khung giờ sáng sớm sinh viên thường ngủ quên hoặc kẹt xe giờ cao điểm. Đề xuất điểm danh đột xuất đầu giờ hoặc tổ chức mini-quiz 5 phút.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textSecondary, height: 1.4),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 20, color: BirdleColors.success),
                SizedBox(width: 6),
                Text(
                  'Chưa ghi nhận ca vắng nào',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BirdleColors.success),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '100% sinh viên tham gia đầy đủ và đúng giờ qua tất cả các slot học. Chuyên cần lớp đạt trạng thái lý tưởng.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTrendCard() {
    final hasAbsents = _report.worstDay.absentCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BirdleColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasAbsents ? const Color(0xFFEDE9FE) : BirdleColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: hasAbsents ? const Color(0xFF7C3AED) : BirdleColors.success,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thứ trong tuần hay vắng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BirdleColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasAbsents) ...[
            Text(
              _report.worstDay.dayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: BirdleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_report.worstDay.absentCount} lượt vắng (${_report.worstDay.absentRate.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _report.worstDay.weekday == 1
                  ? 'Thứ Hai đầu tuần sinh viên thường có tâm lý uể oải sau ngày nghỉ cuối tuần. Giảng viên nên gửi thông báo nhắc lịch học vào tối Chủ Nhật.'
                  : (_report.worstDay.weekday == 5
                      ? 'Thứ Sáu cuối tuần sinh viên có xu hướng nghỉ sớm để về quê hoặc giải trí. Cần lưu ý giám sát sĩ số sát sao hơn.'
                      : 'Ngày ${_report.worstDay.dayName} có số lượt vắng nổi trội trong tuần. Giảng viên nên tạo thêm các hoạt động tương tác trong lớp.'),
              style: const TextStyle(fontSize: 12, color: BirdleColors.textSecondary, height: 1.4),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 20, color: BirdleColors.success),
                SizedBox(width: 6),
                Text(
                  'Chuyên cần đồng đều',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BirdleColors.success),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tỷ lệ chuyên cần duy trì ổn định và tích cực qua tất cả các ngày trong tuần. Không có ngày nào ghi nhận tỷ lệ nghỉ bất thường.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarlyWarningCard() {
    final earlyWarningStudents = widget.students
        .where((s) => s.remainingAllowedAbsences <= 1 && !s.isBanned)
        .toList();
    final bannedStudents = widget.students.where((s) => s.isBanned).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BirdleColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BirdleColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: earlyWarningStudents.isNotEmpty
                      ? BirdleColors.dangerLight
                      : (bannedStudents.isNotEmpty ? BirdleColors.warningLight : BirdleColors.successLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  earlyWarningStudents.isNotEmpty
                      ? Icons.warning_amber_rounded
                      : (bannedStudents.isNotEmpty ? Icons.info_outline_rounded : Icons.verified_user_outlined),
                  size: 20,
                  color: earlyWarningStudents.isNotEmpty
                      ? BirdleColors.danger
                      : (bannedStudents.isNotEmpty ? BirdleColors.warning : BirdleColors.success),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Can thiệp sớm (Early Warning)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BirdleColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Trạng thái 1: Có sinh viên sát ngưỡng cấm thi (còn 0-1 buổi vắng)
          if (earlyWarningStudents.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '${earlyWarningStudents.length}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BirdleColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'sinh viên chỉ còn 0-1 buổi vắng',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BirdleColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...earlyWarningStudents.take(3).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BirdleColors.dangerLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BirdleColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${s.rollNumber} - ${s.fullName} (Còn ${s.remainingAllowedAbsences}b)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BirdleColors.danger,
                      ),
                    ),
                  );
                }),
                if (earlyWarningStudents.length > 3)
                  Tooltip(
                    message: earlyWarningStudents
                        .skip(3)
                        .map((s) => '${s.rollNumber}: ${s.fullName} (Còn ${s.remainingAllowedAbsences} buổi)')
                        .join('\n'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BirdleColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BirdleColors.border),
                      ),
                      child: Text(
                        '+${earlyWarningStudents.length - 3} bạn khác...',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BirdleColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cần liên hệ nhắc nhở trước buổi học tới để tránh bị vượt ngưỡng 20% cấm thi FPT.',
              style: TextStyle(fontSize: 11.5, color: BirdleColors.textSecondary, height: 1.3),
            ),
          ]

          // Trạng thái 2: Không có SV 0-1 buổi nhưng có SV ĐÃ CẤM THI
          else if (bannedStudents.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '${bannedStudents.length}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BirdleColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'sinh viên đã bị CẤM THI (>20%)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: BirdleColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Lớp đã ghi nhận sinh viên vượt ngưỡng quy chế đào tạo. Các sinh viên còn lại đều trong ngưỡng an toàn.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textSecondary, height: 1.4),
            ),
          ]

          // Trạng thái 3: Cả 2 nhóm đều bằng 0 -> 100% An toàn tuyệt đối
          else ...[
            const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 20, color: BirdleColors.success),
                SizedBox(width: 6),
                Text(
                  '100% sinh viên an toàn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BirdleColors.success),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Không có sinh viên nào tiệm cận ngưỡng cấm thi (>20%). Sĩ số lớp học đảm bảo điều kiện thi cử 100%.',
              style: TextStyle(fontSize: 12, color: BirdleColors.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

