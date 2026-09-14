import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/ai_analytics_service.dart';
import '../services/storage_service.dart';
import '../widgets/status_badge.dart';

class AiInsightsView extends StatefulWidget {
  final List<Student> students;
  final List<AttendanceRecord> records;
  final String currentClass;
  final List<Map<String, dynamic>>? historyLogs;

  const AiInsightsView({
    super.key,
    required this.students,
    required this.records,
    required this.currentClass,
    this.historyLogs,
  });

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  final TextEditingController _questionCtrl = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  late AiAttendanceReport _report;
  bool _isLoadingAi = false;
  String? _currentAsking;

  @override
  void initState() {
    super.initState();
    _refreshAnalysis();
  }

  @override
  void didUpdateWidget(covariant AiInsightsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.students != widget.students || oldWidget.records != widget.records) {
      _refreshAnalysis();
    }
  }

  void _refreshAnalysis() {
    _report = AiAnalyticsService.analyzeAttendance(
      students: widget.students,
      currentRecords: widget.records,
      historyLogs: widget.historyLogs,
    );
  }

  void _askAi(String question) async {
    final q = question.trim();
    if (q.isEmpty || _isLoadingAi) return;

    final apiKey = StorageService.getGeminiApiKey();
    setState(() {
      _isLoadingAi = true;
      _currentAsking = q;
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
        _chatHistory.add({'q': q, 'a': answer});
        _currentAsking = null;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header AI Executive Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withAlpha(50),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              StorageService.getGeminiApiKey().isNotEmpty
                                  ? '✨ GOOGLE GEMINI 1.5 FLASH AI'
                                  : '📊 REAL DATA ANALYTICS ENGINE',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Lớp ${widget.currentClass}',
                            style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Trợ Lý AI Phân Tích Chuyên Cần & Điểm Danh FAP',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _report.aiSummary,
                        style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3 Big Highlight Answer Cards
          Row(
            children: [
              // 1. Slot nghỉ nhiều nhất
              Expanded(
                child: _buildHighlightCard(
                  icon: Icons.access_time_filled,
                  iconBg: const Color(0xFFFFEDD5),
                  iconColor: const Color(0xFFEA580C),
                  title: 'Slot nghỉ nhiều nhất',
                  value: 'Slot ${_report.worstSlot.slot}',
                  subtitle: '${_report.worstSlot.slotTime} (${_report.worstSlot.absentRate.toStringAsFixed(1)}% vắng)',
                  badgeText: '${_report.worstSlot.absentCount} lượt vắng',
                  badgeColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),

              // 2. Thứ nghỉ nhiều nhất
              Expanded(
                child: _buildHighlightCard(
                  icon: Icons.calendar_today_rounded,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Thứ nghỉ nhiều nhất',
                  value: _report.worstDay.dayName,
                  subtitle: 'Tỷ lệ vắng ${_report.worstDay.absentRate.toStringAsFixed(1)}%',
                  badgeText: '${_report.worstDay.absentCount} lượt vắng',
                  badgeColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),

              // 3. Fail attendance
              Expanded(
                child: _buildHighlightCard(
                  icon: Icons.dangerous_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Fail Attendance (Cấm thi)',
                  value: '${_report.failedStudents.length} SV',
                  subtitle: 'Vắng >= 20% số buổi',
                  badgeText: _report.failedStudents.isNotEmpty ? 'Cần xử lý' : 'An toàn',
                  badgeColor: _report.failedStudents.isNotEmpty ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Charts & Distribution Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Slot Breakdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, color: Color(0xFFF36F21), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Phân bổ vắng theo Slot học',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._report.slotStats.map((stat) => _buildSlotBar(stat)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right: Day of Week Breakdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.date_range, color: Color(0xFF4F46E5), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Phân bổ vắng theo Thứ trong tuần',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._report.dayStats.map((dStat) => _buildDayBar(dStat)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Failed Students Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cancel_presentation, color: Colors.red, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Danh sách sinh viên FAIL ATTENDANCE (Cấm thi >= 20%)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_report.failedStudents.length} sinh viên',
                        style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_report.failedStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.verified, color: Colors.green.shade400, size: 36),
                        const SizedBox(height: 6),
                        const Text(
                          'Chúc mừng! Không có sinh viên nào trong lớp bị fail attendance.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _report.failedStudents.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _report.failedStudents[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFEE2E2),
                          child: Text(
                            s.member.substring(0, 2),
                            style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text('${s.member} - ${s.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Đã vắng ${s.absentSlots}/${s.totalSlots} buổi học • Email: ${s.email}'),
                        trailing: AbsentRateBadge(rate: s.absentRate),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Interactive AI Chat / Ask Section
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hội thoại Trợ lý AI Điểm danh',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Hỏi đáp tự nhiên về chuyên cần, xu hướng vắng và tư vấn giải pháp học vụ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_chatHistory.isNotEmpty || _isLoadingAi)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _chatHistory.clear();
                            _currentAsking = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                // Chat Messages Area
                if (_chatHistory.isEmpty && !_isLoadingAi)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.forum_outlined, size: 28, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có tin nhắn nào',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Đặt bất kỳ câu hỏi nào cho Trợ lý AI ở khung bên dưới để bắt đầu trò chuyện.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 480),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _chatHistory.length + (_isLoadingAi ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index == _chatHistory.length) {
                          return _buildAiLoadingBubble();
                        }
                        final item = _chatHistory[index];
                        return _buildConversationItem(item['q']!, item['a']!);
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // Modern Rounded Input Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.only(left: 18, right: 6, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nhập câu hỏi cho AI (ví dụ: Slot mấy nghỉ nhiều, phân tích tình hình lớp)...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: _askAi,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: const ShapeDecoration(
                            shape: CircleBorder(),
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                          ),
                          child: IconButton(
                            icon: _isLoadingAi
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                            tooltip: 'Gửi câu hỏi',
                            onPressed: _isLoadingAi ? null : () => _askAi(_questionCtrl.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required String badgeText,
    required MaterialColor badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.shade200),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSlotBar(SlotStat stat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Slot ${stat.slot} (${stat.slotTime})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(
                '${stat.absentRate.toStringAsFixed(1)}% vắng (${stat.absentCount} lượt)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: stat.absentRate >= 25 ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stat.absentRate / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                stat.absentRate >= 25 ? const Color(0xFFEF4444) : const Color(0xFFF36F21),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(DayStat dStat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dStat.dayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(
                '${dStat.absentRate.toStringAsFixed(1)}% vắng (${dStat.absentCount} lượt)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: dStat.absentRate >= 25 ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: dStat.absentRate / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                dStat.absentRate >= 25 ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Question (Right aligned)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.person_rounded, size: 16, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // AI Answer (Left aligned)
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SelectableText(
                    answer,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiLoadingBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentAsking != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _currentAsking!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.person_rounded, size: 16, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'AI đang phân tích và soạn câu trả lời...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
