import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance_record.dart';

class GoogleSheetService {
  /// Test connection to Google Apps Script Web App
  static Future<Map<String, dynamic>> testConnection(String webAppUrl) async {
    if (webAppUrl.trim().isEmpty) {
      return {'success': false, 'message': 'Chưa cấu hình URL Google Sheet Web App!'};
    }

    try {
      final uri = Uri.parse('$webAppUrl?action=test');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 302) {
        // In Google Apps Script, redirects are common
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Kết nối thành công đến Google Sheet!',
            'data': data,
          };
        } catch (_) {
          return {'success': true, 'message': 'Kết nối thành công đến Google Sheet Web App!'};
        }
      } else {
        return {
          'success': false,
          'message': 'Lỗi máy chủ Google: Mã phản hồi HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến Google Sheet. Kiểm tra lại URL hoặc mạng internet: $e',
      };
    }
  }

  /// Lấy danh sách sinh viên theo lớp từ Google Sheet
  static Future<List<Student>> fetchStudents(String webAppUrl, String className) async {
    if (webAppUrl.trim().isEmpty) {
      return _getDefaultSampleStudents(className);
    }

    try {
      final uri = Uri.parse('$webAppUrl?action=getStudents&className=$className');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final List<dynamic> list = decoded['data'];
          return list.map((item) => Student.fromJson(item)).toList();
        }
      }
    } catch (e) {
      // Fallback on failure
    }

    return _getDefaultSampleStudents(className);
  }

  /// Lấy dữ liệu điểm danh theo lớp, ngày, slot từ Google Sheet
  static Future<List<AttendanceRecord>> fetchAttendance(
    String webAppUrl,
    String className,
    String date,
    int slot,
  ) async {
    if (webAppUrl.trim().isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse(
        '$webAppUrl?action=getAttendance&className=$className&date=$date&slot=$slot',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final List<dynamic> list = decoded['data'];
          return list.map((item) => AttendanceRecord.fromJson(item)).toList();
        }
      }
    } catch (e) {
      // Error handling
    }

    return [];
  }

  /// Ghi dữ liệu điểm danh lên Google Sheet
  static Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
  }) async {
    if (webAppUrl.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt trước khi lưu!',
      };
    }

    try {
      final payload = jsonEncode({
        'action': 'saveAttendance',
        'className': className,
        'date': date,
        'slot': slot,
        'records': records.map((r) => r.toJson()).toList(),
      });

      final response = await http.post(
        Uri.parse(webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        return {
          'success': true,
          'message': 'Đã lưu điểm danh thành công vào Google Sheet!',
        };
      } else {
        return {
          'success': false,
          'message': 'Lỗi phản hồi HTTP: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi lưu điểm danh lên Google Sheet: $e',
      };
    }
  }

  /// Đồng bộ danh sách sinh viên lớp lên Google Sheet
  static Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
  }) async {
    if (webAppUrl.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Chưa cấu hình URL Google Sheet Web App!',
      };
    }

    try {
      final payload = jsonEncode({
        'action': 'syncStudents',
        'className': className,
        'students': students.map((s) => s.toJson()).toList(),
      });

      final response = await http.post(
        Uri.parse(webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        return {
          'success': true,
          'message': 'Đã đồng bộ ${students.length} sinh viên lên Google Sheet thành công!',
        };
      } else {
        return {
          'success': false,
          'message': 'Lỗi phản hồi: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi đồng bộ sinh viên: $e',
      };
    }
  }

  /// Lấy toàn bộ lịch sử điểm danh để phục vụ AI phân tích (thực tế từ Google Sheet)
  static Future<List<Map<String, dynamic>>> fetchAnalyticsLogs(
    String webAppUrl,
    String className, {
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) return [];

    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('$cleanUrl?action=getAnalyticsData&className=$className');
      final response = await httpClient.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final isSuccess = decoded['status'] == 'success' || decoded['success'] == true;
          final rawLogs = decoded['logs'] ?? decoded['data'];
          if (isSuccess && rawLogs != null) {
            return List<Map<String, dynamic>>.from(rawLogs);
          }
          final msg = decoded['message'] ?? decoded['error'];
          throw Exception(msg ?? 'Dữ liệu trả về từ Google Apps Script không hợp lệ');
        }
        throw Exception('Dữ liệu phản hồi không đúng định dạng JSON object');
      } else {
        throw Exception('Lỗi máy chủ Google Apps Script: HTTP ${response.statusCode}');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Danh sách mẫu chuẩn sinh viên FPT (Bao gồm CE190585 Lâm Quốc Minh từ ảnh yêu cầu)
  static List<Student> _getDefaultSampleStudents(String className) {
    return [
      Student(
        member: 'CE190585',
        code: 'Lâm',
        surname: 'Quốc',
        middleName: 'Minh',
        email: 'minhlqce190585@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        member: 'SE170123',
        code: 'Nguyễn',
        surname: 'Văn',
        middleName: 'An',
        email: 'annvse170123@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 2,
      ),
      Student(
        member: 'SE170456',
        code: 'Trần',
        surname: 'Thị',
        middleName: 'Bình',
        email: 'binhttse170456@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        member: 'SE170789',
        code: 'Lê',
        surname: 'Hoàng',
        middleName: 'Cường',
        email: 'cuonglhse170789@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 3,
      ),
      Student(
        member: 'SE171012',
        code: 'Phạm',
        surname: 'Minh',
        middleName: 'Đức',
        email: 'ducpmse171012@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 5, // 25% -> FAIL ATTENDANCE (CẤM THI)
      ),
      Student(
        member: 'SE171345',
        code: 'Vũ',
        surname: 'Hải',
        middleName: 'Đăng',
        email: 'dangvhse171345@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 4, // 20% -> FAIL ATTENDANCE (CẤM THI)
      ),
      Student(
        member: 'HE160234',
        code: 'Đỗ',
        surname: 'Thùy',
        middleName: 'Linh',
        email: 'linhdthe160234@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        member: 'HE160567',
        code: 'Ngô',
        surname: 'Quốc',
        middleName: 'Nam',
        email: 'namnqhe160567@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        member: 'IA160890',
        code: 'Hoàng',
        surname: 'Mai',
        middleName: 'Phương',
        email: 'phuonghmia160890@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 6, // 30% -> FAIL ATTENDANCE
      ),
    ];
  }
}
