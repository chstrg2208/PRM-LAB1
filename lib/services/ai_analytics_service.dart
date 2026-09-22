import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_session.dart';
import '../models/class_schedule.dart';

class SlotStat {
  final int slot;
  final int absentCount;
  final int totalCount;
  final double absentRate;

  SlotStat({
    required this.slot,
    required this.absentCount,
    required this.totalCount,
    required this.absentRate,
  });

  String get slotTime => ClassSession.getSlotTime(slot);
}

class DayStat {
  final int weekday; // 1: Thứ Hai, ..., 7: Chủ Nhật
  final String dayName;
  final int absentCount;
  final int totalCount;
  final double absentRate;

  DayStat({
    required this.weekday,
    required this.dayName,
    required this.absentCount,
    required this.totalCount,
    required this.absentRate,
  });
}

enum AnalyticsDataStatus {
  unconfigured,
  empty,
  loaded,
  error,
}

class AiAttendanceReport {
  final SlotStat worstSlot;
  final DayStat worstDay;
  final List<SlotStat> slotStats;
  final List<DayStat> dayStats;
  final List<Student> failedStudents; // Fail attendance (> 20%)
  final List<Student> warningStudents; // Nguy cơ (15% - 20%)
  final double overallAttendanceRate;
  final String aiSummary;
  final List<String> aiRecommendations;
  final bool hasHistory;
  final AnalyticsDataStatus status;
  final String? errorMessage;

  AiAttendanceReport({
    required this.worstSlot,
    required this.worstDay,
    required this.slotStats,
    required this.dayStats,
    required this.failedStudents,
    required this.warningStudents,
    required this.overallAttendanceRate,
    required this.aiSummary,
    required this.aiRecommendations,
    this.hasHistory = true,
    this.status = AnalyticsDataStatus.loaded,
    this.errorMessage,
  });
}

class AiAnalyticsService {
  /// Phân tích toàn diện dữ liệu điểm danh (chỉ dựa trên dữ liệu thật)
  static AiAttendanceReport analyzeAttendance({
    required List<Student> students,
    required List<AttendanceRecord> currentRecords,
    List<Map<String, dynamic>>? historyLogs,
    AnalyticsDataStatus? status,
    String? errorMessage,
  }) {
    // 1. Phân tích theo Slot (Slot 1 -> Slot 6)
    final Map<int, int> slotAbsents = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    final Map<int, int> slotTotals = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    // 2. Phân tích theo Thứ trong tuần (1: T2 -> 7: CN)
    final Map<int, int> dayAbsents = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final Map<int, int> dayTotals = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    bool hasHistory = false;
    AnalyticsDataStatus effectiveStatus = status ?? AnalyticsDataStatus.loaded;

    if (effectiveStatus == AnalyticsDataStatus.unconfigured) {
      hasHistory = false;
    } else if (effectiveStatus == AnalyticsDataStatus.error) {
      hasHistory = false;
    } else if (historyLogs != null) {
      if (historyLogs.isNotEmpty) {
        hasHistory = true;
        effectiveStatus = AnalyticsDataStatus.loaded;
        for (final log in historyLogs) {
          final slot = int.tryParse(log['slot']?.toString() ?? '1') ?? 1;
          if (slot >= 1 && slot <= 6) {
            final statusStr = (log['status'] ?? '').toString().toLowerCase().trim();
            final isAbsent = statusStr == 'absent' || statusStr == 'vắng';

            slotTotals[slot] = (slotTotals[slot] ?? 0) + 1;
            if (isAbsent) {
              slotAbsents[slot] = (slotAbsents[slot] ?? 0) + 1;
            }

            final dStr = (log['date'] ?? '').toString().trim();
            final dt = DateTime.tryParse(dStr);
            if (dt != null) {
              final wd = dt.weekday;
              if (wd >= 1 && wd <= 7) {
                dayTotals[wd] = (dayTotals[wd] ?? 0) + 1;
                if (isAbsent) {
                  dayAbsents[wd] = (dayAbsents[wd] ?? 0) + 1;
                }
              }
            }
          }
        }
      } else {
        hasHistory = false;
        effectiveStatus = AnalyticsDataStatus.empty;
      }
    } else if (currentRecords.isNotEmpty) {
      // Fallback chỉ dùng khi historyLogs không được truyền nhưng có currentRecords
      hasHistory = true;
      effectiveStatus = AnalyticsDataStatus.loaded;
      for (final r in currentRecords) {
        final s = r.slot;
        if (s >= 1 && s <= 6) {
          slotTotals[s] = (slotTotals[s] ?? 0) + 1;
          if (r.status == AttendanceStatus.absent) {
            slotAbsents[s] = (slotAbsents[s] ?? 0) + 1;
          }

          final date = DateTime.tryParse(r.date);
          if (date != null) {
            final day = date.weekday;
            if (day >= 1 && day <= 7) {
              dayTotals[day] = (dayTotals[day] ?? 0) + 1;
              if (r.status == AttendanceStatus.absent) {
                dayAbsents[day] = (dayAbsents[day] ?? 0) + 1;
              }
            }
          }
        }
      }
    } else {
      hasHistory = false;
      effectiveStatus = AnalyticsDataStatus.empty;
    }

    // Tính toán Slot Stats
    final List<SlotStat> slotStats = [];
    for (int s = 1; s <= 6; s++) {
      final abs = slotAbsents[s] ?? 0;
      final tot = slotTotals[s] ?? 0;
      final rate = tot > 0 ? (abs / tot) * 100 : 0.0;
      slotStats.add(SlotStat(slot: s, absentCount: abs, totalCount: tot, absentRate: rate));
    }

    // Tính toán Day Stats
    final dayNames = {
      1: 'Thứ Hai',
      2: 'Thứ Ba',
      3: 'Thứ Tư',
      4: 'Thứ Năm',
      5: 'Thứ Sáu',
      6: 'Thứ Bảy',
      7: 'Chủ Nhật',
    };
    final List<DayStat> dayStats = [];
    for (int d = 1; d <= 7; d++) {
      final abs = dayAbsents[d] ?? 0;
      final tot = dayTotals[d] ?? 0;
      final rate = tot > 0 ? (abs / tot) * 100 : 0.0;
      dayStats.add(DayStat(
        weekday: d,
        dayName: dayNames[d] ?? 'Thứ $d',
        absentCount: abs,
        totalCount: tot,
        absentRate: rate,
      ));
    }

    // Sắp xếp tìm worstSlot và worstDay
    final sortedSlots = List<SlotStat>.from(slotStats);
    sortedSlots.sort((a, b) {
      final cmp = b.absentRate.compareTo(a.absentRate);
      if (cmp != 0) return cmp;
      return b.absentCount.compareTo(a.absentCount);
    });
    final worstSlot = sortedSlots.first;

    final sortedDays = List<DayStat>.from(dayStats);
    sortedDays.sort((a, b) {
      final cmp = b.absentRate.compareTo(a.absentRate);
      if (cmp != 0) return cmp;
      return b.absentCount.compareTo(a.absentCount);
    });
    final worstDay = sortedDays.first;

    // Lọc sinh viên Fail Attendance (> 20%) và Warning (15% - 20% hoặc đã hết lượt vắng)
    final failedStudents = students.where((s) => s.isBanned).toList();
    final warningStudents = students.where((s) => s.isWarning || s.hasExhaustedAbsenceAllowance).toList();

    // Tỷ lệ chuyên cần chung từ sinh viên
    int totalAbsences = students.fold(0, (sum, s) => sum + s.absentSlots);
    int totalPossibleSlots = students.fold(0, (sum, s) => sum + s.totalSlots);
    final overallAttendanceRate = totalPossibleSlots > 0
        ? ((totalPossibleSlots - totalAbsences) / totalPossibleSlots) * 100
        : 100.0;

    // Sinh tóm tắt và khuyến nghị theo dữ liệu thật
    String aiSummary;
    List<String> recommendations;

    if (effectiveStatus == AnalyticsDataStatus.unconfigured) {
      aiSummary = 'Chưa cấu hình URL Google Sheet / Apps Script. Vui lòng cấu hình URL trong mục Cài đặt để tải lịch sử điểm danh thực tế.';
      recommendations = [
        'Vui lòng cấu hình kết nối Google Apps Script để tải dữ liệu lịch sử điểm danh.',
      ];
    } else if (effectiveStatus == AnalyticsDataStatus.error) {
      aiSummary = 'Lỗi tải dữ liệu lịch sử điểm danh: ${errorMessage ?? "Không thể kết nối cơ sở dữ liệu."}';
      recommendations = [
        'Kiểm tra lại kết nối mạng hoặc cấu hình URL Google Apps Script và thử lại.',
      ];
    } else if (!hasHistory || effectiveStatus == AnalyticsDataStatus.empty) {
      aiSummary = 'Chưa đủ dữ liệu thống kê lịch sử.';
      recommendations = [
        'Chưa đủ dữ liệu thống kê lịch sử để phân tích xu hướng vắng theo slot hoặc thứ.',
        if (warningStudents.isNotEmpty)
          '⚠️ Giảng viên nên gửi thông báo cảnh báo sớm cho ${warningStudents.length} sinh viên đang ngấp nghé ngưỡng 20% cấm thi.',
      ];
    } else {
      aiSummary = _generateNaturalLanguageSummary(
        worstSlot: worstSlot,
        worstDay: worstDay,
        failedCount: failedStudents.length,
        warningCount: warningStudents.length,
        overallRate: overallAttendanceRate,
      );
      recommendations = [
        if (warningStudents.isNotEmpty)
          '⚠️ Giảng viên nên gửi thông báo cảnh báo sớm cho ${warningStudents.length} sinh viên đang ngấp nghé ngưỡng 20% cấm thi.',
        if (worstSlot.absentCount > 0)
          '⏰ Slot ${worstSlot.slot} (${worstSlot.slotTime}) có tỷ lệ vắng lên tới ${worstSlot.absentRate.toStringAsFixed(1)}% (${worstSlot.absentCount} lượt vắng). Cân nhắc điểm danh đột xuất hoặc gửi nhắc nhở trước giờ học.',
        if (worstDay.absentCount > 0)
          '📅 ${worstDay.dayName} là ngày sinh viên có xu hướng vắng nhiều nhất (${worstDay.absentRate.toStringAsFixed(1)}%, ${worstDay.absentCount} lượt vắng). Nên tăng cường tương tác hoặc chấm điểm bài tập nhỏ trong ngày này.',
      ];
      if (recommendations.isEmpty) {
        recommendations = ['Lớp học có chuyên cần xuất sắc, chưa ghi nhận lượt vắng nào trong lịch sử.'];
      }
    }

    return AiAttendanceReport(
      worstSlot: worstSlot,
      worstDay: worstDay,
      slotStats: slotStats,
      dayStats: dayStats,
      failedStudents: failedStudents,
      warningStudents: warningStudents,
      overallAttendanceRate: overallAttendanceRate,
      aiSummary: aiSummary,
      aiRecommendations: recommendations,
      hasHistory: hasHistory,
      status: effectiveStatus,
      errorMessage: errorMessage,
    );
  }

  /// Trả lời câu hỏi tương tác người dùng
  static String answerAiQuestion(String query, AiAttendanceReport report, {List<Student>? students, ClassSchedule? schedule}) {
    final q = query.toLowerCase().trim();

    // 1. Chào hỏi & Thăm hỏi tự nhiên
    if (RegExp(r'^(xin\s+)?chào|\b(hello|hi|hey|alo)\b|\bchúc\b|good\s+(morning|afternoon|evening)|bạn\s+ơi|bot\s+ơi', caseSensitive: false).hasMatch(q)) {
      return '👋 **Xin chào Thầy/Cô!** Em là **FAP Attendance Assistant** - Trợ lý AI hỗ trợ quản lý và phân tích chuyên cần sinh viên FPTU.\n\n'
          '📊 **Tổng quan lớp hiện tại:**\n'
          '• Tỷ lệ chuyên cần chung: **${report.overallAttendanceRate.toStringAsFixed(1)}%**\n'
          '• Slot vắng cao nhất: **Slot ${report.worstSlot.slot}** (${report.worstSlot.absentRate.toStringAsFixed(1)}% vắng)\n'
          '• Thứ vắng nhiều nhất: **${report.worstDay.dayName}** (${report.worstDay.absentRate.toStringAsFixed(1)}% vắng)\n'
          '• Tình trạng cấm thi (>20%): **${report.failedStudents.length} sinh viên** | Nguy cơ (15-20%): **${report.warningStudents.length} sinh viên**\n\n'
          '💡 Thầy/Cô có thể hỏi em về danh sách sinh viên vắng, phân tích theo slot/thứ, tra cứu theo tên/MSSV hoặc đề xuất giải pháp cải thiện!';
    }

    // 2. Hỏi về danh tính AI (bạn là ai, ai tạo ra bạn)
    if (RegExp(r'bạn\s+là\s+ai|who\s+are\s+you|bạn\s+tên\s+gì|ai\s+tạo|giới\s+thiệu\s+bạn', caseSensitive: false).hasMatch(q)) {
      return '🤖 **Em là FAP AI Assistant!**\n'
          'Trợ lý trí tuệ nhân tạo chuyên sâu về quản lý điểm danh và phân tích học vụ tại Đại học FPT.\n\n'
          'Em có khả năng:\n'
          '1. Quét và phát hiện các trường hợp có nguy cơ Fail Attendance (vắng > 20%).\n'
          '2. Phân tích xu hướng vắng theo Slot học và Thứ trong tuần.\n'
          '3. Tra cứu nhanh hồ sơ chuyên cần của từng sinh viên.\n'
          '4. Đưa ra khuyến nghị thực tế giúp giảng viên quản lý lớp học hiệu quả hơn.';
    }

    // 3. Cảm ơn & Lịch sự
    if (RegExp(r'cảm\s+ơn|thank|tks|tạm\s+biệt|bye|ok\b|tốt\s+lắm|hay\s+quá|good\s+job', caseSensitive: false).hasMatch(q)) {
      return '😊 **Rất vui được đồng hành cùng Thầy/Cô!**\n'
          'Chúc Thầy/Cô có buổi dạy tràn đầy năng lượng và hiệu quả. Nếu cần kiểm tra thêm dữ liệu lớp học, Thầy/Cô cứ nhắn em nhé!';
    }

    // 4. Hướng dẫn sử dụng
    if (RegExp(r'hướng\s+dẫn|giúp|help|chức\s+năng|cách\s+dùng|làm\s+được\s+gì', caseSensitive: false).hasMatch(q)) {
      return '🛠️ **Gợi ý các câu hỏi Thầy/Cô có thể hỏi em:**\n'
          '• *"Slot mấy sinh viên nghỉ nhiều nhất?"*\n'
          '• *"Thứ mấy sinh viên hay vắng?"*\n'
          '• *"Danh sách sinh viên cấm thi hoặc nguy cơ"* hoặc *"Thằng nào fail attendance?"*\n'
          '• *"Tra cứu sinh viên [Tên hoặc MSSV]"* (Ví dụ: *CE190585*)\n'
          '• *"Ai đi học đầy đủ 100%?"*\n'
          '• *"Tư vấn giải pháp nâng cao tỷ lệ chuyên cần"*';
    }

    // 5. Tra cứu sinh viên cụ thể theo tên hoặc mã số sinh viên
    if (students != null && students.isNotEmpty) {
      for (final s in students) {
        final roll = s.member.toLowerCase();
        final name = s.fullName.toLowerCase();
        final code = s.code.toLowerCase();
        if ((roll.isNotEmpty && q.contains(roll)) ||
            (code.isNotEmpty && q.contains(code)) ||
            (name.isNotEmpty && q.contains(name))) {
          final isFail = s.isBanned;
          final isExact20 = s.isExactlyAtAbsenceLimit;
          final isExhausted = s.hasExhaustedAbsenceAllowance;
          final isWarn = s.isWarning;
          final status = isFail
              ? '⛔ **CẤM THI (Fail Attendance - vắng > 20%)**'
              : (isExact20
                  ? '⚠️ **CHẠM NGƯỠNG (Hết số buổi vắng được phép - đúng 20%)**'
                  : (isExhausted
                      ? '⚠️ **HẾT LƯỢT VẮNG (Đã hết số buổi vắng được phép - ${s.absentRate.toStringAsFixed(1)}%)**'
                      : (isWarn
                          ? '⚠️ **CẢNH BÁO NGUY CƠ (Vắng 15% - 20%)**'
                          : '✅ **AN TOÀN (Đi học đầy đủ / Chuyên cần tốt)**')));
          final maxAllowed = s.maxAllowedAbsences;
          final remaining = s.remainingAllowedAbsences;
          final advice = isFail
              ? 'Sinh viên đã vượt hạn mức vắng cho phép ($maxAllowed buổi) và không đủ điều kiện thi cuối môn.'
              : (remaining == 0
                  ? 'Sinh viên đã dùng hết số buổi vắng được phép; vắng thêm 1 buổi sẽ vượt ngưỡng và bị cấm thi!'
                  : (remaining == 1
                      ? 'Sinh viên chỉ còn được phép vắng tối đa **1 buổi nữa** trước khi chạm mốc tối đa!'
                      : 'Sinh viên còn được phép vắng tối đa **$remaining buổi**.'));

          return '👤 **Hồ sơ chuyên cần sinh viên:**\n'
              '• **Họ và tên:** ${s.fullName}\n'
              '• **Mã sinh viên:** ${s.member} (Code: ${s.code})\n'
              '• **Số buổi vắng:** ${s.absentSlots}/${s.totalSlots} buổi (**${s.absentRate.toStringAsFixed(1)}%**)\n'
              '• **Trạng thái:** $status\n'
              '• **Ghi chú học vụ:** $advice';
        }
      }
    }

    // 6. Sinh viên đi học đầy đủ / chăm chỉ
    if (RegExp(r'chăm|đầy\s+đủ|100%|không\s+vắng|chuyên\s+cần\s+tốt', caseSensitive: false).hasMatch(q)) {
      if (students != null) {
        final goodStudents = students.where((s) => s.absentSlots == 0).toList();
        if (goodStudents.isNotEmpty) {
          final names = goodStudents.take(8).map((s) => '• **${s.member} - ${s.fullName}** (Vắng 0 buổi - 100%)').join('\n');
          return '🌟 **Sinh viên đi học đầy đủ 100% (${goodStudents.length} bạn):**\n$names'
              '${goodStudents.length > 8 ? '\n• ... và ${goodStudents.length - 8} sinh viên khác.' : ''}\n\n'
              '👏 Rất đáng khen ngợi! Giảng viên có thể cộng điểm khuyến khích hoặc tuyên dương trước lớp.';
        }
      }
      return '🌟 Lớp hiện có nhiều sinh viên duy trì tỷ lệ đi học rất tốt!';
    }

    // 7. Hỏi về Slot / Tiết học
    if (q.contains('slot') || q.contains('tiết') || RegExp(r'\bca\b').hasMatch(q) || q.contains('giờ')) {
      if (!report.hasHistory || report.status == AnalyticsDataStatus.empty || report.worstSlot.totalCount == 0) {
        return '⏰ **Phân tích Slot:** Chưa đủ dữ liệu thống kê lịch sử để phân tích xu hướng vắng theo Slot học.';
      }
      return '⏰ **Phân tích Slot vắng nhiều nhất:**\n'
          'Sinh viên nghỉ nhiều nhất ở **Slot ${report.worstSlot.slot}** (${report.worstSlot.slotTime}) '
          'với tỷ lệ vắng lên đến **${report.worstSlot.absentRate.toStringAsFixed(1)}%** '
          '(${report.worstSlot.absentCount} lượt vắng).\n\n'
          '*Nhận xét của AI:* Đây là khung giờ sinh viên hay gặp trở ngại về thức dậy sớm hoặc kẹt xe giờ cao điểm.\n'
          '💡 *Khuyến nghị:* Giảng viên nên chốt sĩ số điểm danh ngay trong 15 phút đầu slot.';
    }

    // 8. Hỏi về Thứ / Ngày trong tuần
    if (q.contains('thứ') || q.contains('ngày') || q.contains('day') || q.contains('tuần')) {
      if (!report.hasHistory || report.status == AnalyticsDataStatus.empty || report.worstDay.totalCount == 0) {
        return '📅 **Phân tích Thứ trong tuần:** Chưa đủ dữ liệu thống kê lịch sử để phân tích xu hướng ngày vắng trong tuần.';
      }
      return '📅 **Phân tích Thứ vắng nhiều nhất trong tuần:**\n'
          'Sinh viên nghỉ nhiều nhất vào **${report.worstDay.dayName}** '
          'với tỷ lệ vắng chiếm **${report.worstDay.absentRate.toStringAsFixed(1)}%** '
          '(${report.worstDay.absentCount} lượt vắng).\n\n'
          '*Nhận xét của AI:* Sau những ngày nghỉ cuối tuần, sinh viên thường có xu hướng chậm lại hoặc vướng lịch cá nhân.\n'
          '💡 *Khuyến nghị:* Thầy cô nên gửi thông báo lịch học vào tối Chủ Nhật để sinh viên chủ động chuẩn bị bài.';
    }

    // 9. Danh sách Cấm thi / Fail attendance / Nguy cơ
    if (RegExp(r'fail|cấm\s+thi|thằng\s+nào|ai\s+(vắng|nghỉ|bị|fail)|danh\s+sách\s+vắng|nguy\s+cơ|cảnh\s+báo|bị\s+cấm|rớt', caseSensitive: false).hasMatch(q)) {
      if (report.failedStudents.isEmpty && report.warningStudents.isEmpty) {
        return '🎉 **Tuyệt vời!** Hiện tại lớp chưa có sinh viên nào bị Fail Attendance (cấm thi) hoặc chạm ngưỡng cảnh báo!';
      }

      final buffer = StringBuffer();
      if (report.failedStudents.isNotEmpty) {
        buffer.writeln('🚫 **Danh sách sinh viên FAIL ATTENDANCE (Cấm thi > 20%):**');
        buffer.writeln('Hiện có **${report.failedStudents.length} sinh viên** đã vượt ngưỡng vắng 20%:');
        for (final s in report.failedStudents) {
          buffer.writeln('• **${s.member} - ${s.fullName}**: Vắng ${s.absentSlots}/${s.totalSlots} buổi (${s.absentRate.toStringAsFixed(0)}%) - ⛔ **CẤM THI**');
        }
      }

      if (report.warningStudents.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln('');
        buffer.writeln('⚠️ **Sinh viên trong diện NGUY CƠ CAO (15% - 20%):**');
        for (final s in report.warningStudents) {
          buffer.writeln('• **${s.member} - ${s.fullName}**: Vắng ${s.absentSlots}/${s.totalSlots} buổi (${s.absentRate.toStringAsFixed(0)}%) - Chỉ còn 0-1 buổi vắng!');
        }
      }

      buffer.writeln('\n📢 *Đề xuất:* Giảng viên lập biên bản báo phòng Khảo thí / CTSV và gửi thông báo nhắc nhở các bạn sắp vượt ngưỡng.');
      return buffer.toString();
    }

    // 10. Tư vấn giải pháp / Khuyến nghị
    if (RegExp(r'giải\s+pháp|lời\s+khuyên|tư\s+vấn|khuyến\s+nghị|làm\s+sao|cải\s+thiện|biện\s+pháp|đề\s+xuất', caseSensitive: false).hasMatch(q)) {
      return '💡 **Đề xuất & Giải pháp nâng cao chuyên cần cho lớp học:**\n\n'
          '1. **Tập trung vào ${report.worstDay.dayName} & Slot ${report.worstSlot.slot}:** Đây là thời điểm sinh viên có tỷ lệ vắng cao nhất (**${report.worstSlot.absentRate.toStringAsFixed(1)}%**). Giảng viên nên tổ chức mini-quiz tính điểm cộng hoặc điểm danh vào 15 phút đầu giờ.\n'
          '2. **Can thiệp sớm nhóm nguy cơ:** Lớp hiện có **${report.warningStudents.length} sinh viên cảnh báo** và **${report.failedStudents.length} sinh viên cấm thi**. Hãy trao đổi trực tiếp hoặc gửi email cảnh báo trước khi các em chạm mốc 20%.\n'
          '3. **Tạo sự gắn kết trong tiết học:** Sử dụng phương pháp thảo luận nhóm và bài tập thực hành ngắn (hands-on coding) để sinh viên thấy rõ giá trị của việc có mặt tại lớp.';
    }

    // 11. Báo cáo tổng quan / Chuyên cần
    if (RegExp(r'tổng\s+quan|tình\s+hình|báo\s+cáo|tỷ\s+lệ|chuyên\s+cần|overview', caseSensitive: false).hasMatch(q)) {
      return '📊 **Báo cáo tổng quan chuyên cần lớp học:**\n'
          '• Tỷ lệ chuyên cần trung bình toàn lớp: **${report.overallAttendanceRate.toStringAsFixed(1)}%**\n'
          '• Slot sinh viên nghỉ nhiều nhất: **Slot ${report.worstSlot.slot}** (${report.worstSlot.slotTime}) với **${report.worstSlot.absentRate.toStringAsFixed(1)}%**\n'
          '• Thứ vắng nhiều nhất trong tuần: **${report.worstDay.dayName}** với **${report.worstDay.absentRate.toStringAsFixed(1)}%**\n'
          '• Số sinh viên bị cấm thi (> 20%): **${report.failedStudents.length} sinh viên**\n'
          '• Số sinh viên cảnh báo (15-20%): **${report.warningStudents.length} sinh viên**\n\n'
          '${report.aiSummary}';
    }

    // Default Fallback
    return '🤖 **Em đã ghi nhận câu hỏi:** *"$query"*\n\n'
        'Hiện tại lớp đang đạt tỷ lệ chuyên cần **${report.overallAttendanceRate.toStringAsFixed(1)}%**. '
        'Slot ${report.worstSlot.slot} và ${report.worstDay.dayName} là các mốc thời gian vắng cao điểm nhất, '
        'có **${report.failedStudents.length} sinh viên** đã cấm thi và **${report.warningStudents.length} bạn** cận cấm thi.\n\n'
        '💡 *Gợi ý:* Thầy/Cô có thể hỏi các câu hỏi như: *"Thứ mấy vắng nhiều?"*, *"Slot mấy vắng nhiều?"*, *"Danh sách cấm thi"*, *"Tra cứu sinh viên [Tên/MSSV]"*, hoặc *"Lời khuyên cải thiện chuyên cần"*.\n'
        '✨ *Mẹo:* Nhập Google Gemini API Key tại tab **Cài Đặt** để kích hoạt trí tuệ nhân tạo Gemini 1.5 Flash trò chuyện tự do!';
  }

  static String? _activeGeminiModel;

  static Future<String> _resolveAvailableGeminiModel(String apiKey) async {
    if (_activeGeminiModel != null && _activeGeminiModel!.isNotEmpty) {
      return _activeGeminiModel!;
    }

    try {
      final listUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final res = await http.get(listUrl).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List models = (data['models'] as List?) ?? [];
        final usable = models
            .where((m) {
              final methods = (m['supportedGenerationMethods'] as List?) ?? [];
              return methods.contains('generateContent');
            })
            .map((m) => (m['name'] as String? ?? '').replaceFirst('models/', ''))
            .where((m) => m.isNotEmpty)
            .toList();

        const priorities = [
          'gemini-2.5-flash',
          'gemini-2.0-flash',
          'gemini-2.0-flash-exp',
          'gemini-1.5-flash-latest',
          'gemini-1.5-flash',
          'gemini-1.5-flash-001',
          'gemini-1.5-flash-002',
          'gemini-1.5-pro',
          'gemini-pro',
        ];

        for (final p in priorities) {
          if (usable.contains(p)) {
            _activeGeminiModel = p;
            return p;
          }
        }

        final anyFlash = usable.firstWhere(
          (m) => m.toLowerCase().contains('flash'),
          orElse: () => '',
        );
        if (anyFlash.isNotEmpty) {
          _activeGeminiModel = anyFlash;
          return anyFlash;
        }

        if (usable.isNotEmpty) {
          _activeGeminiModel = usable.first;
          return usable.first;
        }
      }
    } catch (_) {}

    return 'gemini-2.0-flash';
  }

  /// Gửi câu hỏi kèm context dữ liệu thực tế tới Google Gemini LLM API (AI Thật)
  static Future<String> askGeminiAi({
    required String apiKey,
    required String prompt,
    required AiAttendanceReport report,
    required List<Student> students,
    ClassSchedule? schedule,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return answerAiQuestion(prompt, report, students: students, schedule: schedule);
    }

    try {
      final studentSummary = students.map((s) {
        final status = s.trainingStatusLabel;
        return '- MSSV: ${s.member}, Họ tên: ${s.fullName} (Code: ${s.code}), Vắng: ${s.absentSlots}/${s.totalSlots} (${s.absentRate.toStringAsFixed(1)}%) -> $status';
      }).join('\n');

      final historyStatusText = report.hasHistory && report.worstSlot.totalCount > 0
          ? '- Slot vắng nhiều nhất: Slot ${report.worstSlot.slot} (${report.worstSlot.slotTime}) với ${report.worstSlot.absentCount} lượt vắng (${report.worstSlot.absentRate.toStringAsFixed(1)}%)\n'
              '- Thứ vắng nhiều nhất trong tuần: ${report.worstDay.dayName} với ${report.worstDay.absentCount} lượt vắng (${report.worstDay.absentRate.toStringAsFixed(1)}%)'
          : '- Phân tích theo Slot & Thứ: Chưa đủ dữ liệu thống kê lịch sử để xác định xu hướng.';

      final scheduleSection = schedule != null
          ? '- Môn học: ${schedule.subjectCode}\n'
            '- Phòng học: ${schedule.room}\n'
            '- Lịch học: ${schedule.daysOfWeek} (Slot ${schedule.slot}: ${schedule.slotTime})\n'
            '- Tiến độ buổi học: Buổi ${schedule.currentSession}/${schedule.totalSessions}\n'
          : '';

      final contextText = '''
Dữ liệu điểm danh thực tế lớp học:
- Trạng thái dữ liệu lịch sử: ${report.hasHistory ? "Đã nạp từ database Google Sheets" : "Chưa đủ dữ liệu thống kê lịch sử"}
- Tỷ lệ chuyên cần trung bình toàn lớp: ${report.overallAttendanceRate.toStringAsFixed(1)}%
$scheduleSection$historyStatusText
- Số sinh viên bị cấm thi (>20%): ${report.failedStudents.length} sinh viên
- Số sinh viên cảnh báo (15-20%): ${report.warningStudents.length} sinh viên

Danh sách sinh viên:
$studentSummary
''';

      final systemInstruction = '''
Bạn là trợ lý AI chuyên môn cao cấp của hệ thống Quản lý Điểm danh FAP tại Đại học FPT.
Bạn đang trò chuyện và hỗ trợ trực tiếp giảng viên.
Quy tắc trả lời bắt buộc:
1. Nếu giảng viên chào hỏi (xin chào, hello...), hãy chào lại một cách lịch sự, thân thiện, xưng "em" gọi "Thầy/Cô", tóm tắt 1 câu hiện trạng chuyên cần của lớp và hỏi xem Thầy/Cô cần hỗ trợ phân tích điều gì.
2. Nếu giảng viên hỏi bạn là ai, hãy giới thiệu bạn là Trợ lý AI FAP Attendance Assistant hỗ trợ điểm danh & phân tích chuyên cần ĐH FPT.
3. Khi trả lời về dữ liệu điểm danh, TUYỆT ĐỐI chỉ dùng số liệu thực tế được cung cấp trong context. Nghiêm cấm bịa đặt, giả định, hoặc suy diễn thêm bất kỳ số liệu định lượng nào ngoài nguồn dữ liệu.
4. Nếu context ghi "Chưa đủ dữ liệu thống kê lịch sử", hãy thông báo trung thực rằng chưa có đủ dữ liệu lịch sử để phân tích xu hướng vắng theo buổi/thứ, không tự ý đưa ra phán đoán về slot hay ngày nghỉ.
5. Khi tư vấn giải pháp, hãy đưa ra các lời khuyên sư phạm thực tế, đúng quy chế đào tạo ĐH FPT (vắng > 20% tổng số buổi sẽ bị cấm thi / fail attendance).
6. Trình bày đẹp mắt, tự nhiên bằng định dạng Markdown (in đậm, bullet points).
''';

      final discoveredModel = await _resolveAvailableGeminiModel(cleanKey);
      final candidateModels = <String>{
        discoveredModel,
        'gemini-2.0-flash',
        'gemini-2.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-pro',
      }.toList();

      int lastStatusCode = 0;
      String lastErrorMessage = 'Lỗi kết nối';

      for (final modelName in candidateModels) {
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$cleanKey');
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text': '$systemInstruction\n\nDỮ LIỆU ĐIỂM DANH THỰC TẾ:\n$contextText\n\nCÂU HỎI CỦA GIẢNG VIÊN:\n"$prompt"'
                    }
                  ]
                }
              ]
            }),
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null && text.toString().trim().isNotEmpty) {
              _activeGeminiModel = modelName;
              return text.toString().trim();
            }
          } else {
            lastStatusCode = response.statusCode;
            try {
              final errData = jsonDecode(response.body);
              lastErrorMessage = errData['error']?['message'] ?? 'Mã lỗi: ${response.statusCode}';
            } catch (_) {
              lastErrorMessage = 'Mã phản hồi: ${response.statusCode}';
            }
            if (response.statusCode == 404) {
              continue; // Model not supported, try next model
            } else {
              break; // Auth error or quota error
            }
          }
        } catch (e) {
          lastErrorMessage = e.toString();
        }
      }

      final localResp = answerAiQuestion(prompt, report, students: students);
      return '⚠️ **Lỗi gọi Google Gemini API ($lastStatusCode):** $lastErrorMessage\n\n'
          '💡 *Hệ thống tự động chuyển sang phân tích nội bộ bên dưới:*\n\n$localResp';
    } catch (e) {
      final localResp = answerAiQuestion(prompt, report, students: students);
      return '⚠️ **Lỗi kết nối mạng tới Gemini:** $e\n\n'
          '💡 *Hệ thống tự động chuyển sang phân tích nội bộ bên dưới:*\n\n$localResp';
    }
  }

  static String _generateNaturalLanguageSummary({
    required SlotStat worstSlot,
    required DayStat worstDay,
    required int failedCount,
    required int warningCount,
    required double overallRate,
  }) {
    return 'Dựa trên phân tích dữ liệu điểm danh, lớp học hiện đạt tỷ lệ chuyên cần trung bình ${overallRate.toStringAsFixed(1)}%. '
        'Điểm đáng chú ý là sinh viên có xu hướng nghỉ nhiều nhất vào Slot ${worstSlot.slot} (${worstSlot.slotTime}) '
        'với tỷ lệ vắng lên tới ${worstSlot.absentRate.toStringAsFixed(1)}%, và ngày vắng cao điểm là ${worstDay.dayName}. '
        'Về tình trạng học vụ, hệ thống phát hiện $failedCount sinh viên đã bị Fail Attendance (Cấm thi > 20%) '
        'và $warningCount sinh viên đang nằm trong danh sách nguy cơ cao cần được nhắc nhở.';
  }
}
