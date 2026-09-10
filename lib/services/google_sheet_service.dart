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

  /// Danh sách mẫu chuẩn sinh viên FPT nếu chưa cấu hình Google Sheet
  static List<Student> _getDefaultSampleStudents(String className) {
    return [
      Student(
        rollNumber: 'SE170123',
        fullName: 'Nguyễn Văn An',
        email: 'annvse170123@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        rollNumber: 'SE170456',
        fullName: 'Trần Thị Bình',
        email: 'binhttse170456@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        rollNumber: 'SE170789',
        fullName: 'Lê Hoàng Cường',
        email: 'cuonglhse170789@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 3,
      ),
      Student(
        rollNumber: 'SE171012',
        fullName: 'Phạm Minh Đức',
        email: 'ducpmse171012@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 4, // 20% -> Banned warning
      ),
      Student(
        rollNumber: 'SE171345',
        fullName: 'Vũ Hải Đăng',
        email: 'dangvhse171345@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 2,
      ),
      Student(
        rollNumber: 'HE160234',
        fullName: 'Đỗ Thùy Linh',
        email: 'linhdthe160234@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        rollNumber: 'HE160567',
        fullName: 'Ngô Quốc Nam',
        email: 'namnqhe160567@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        rollNumber: 'IA160890',
        fullName: 'Hoàng Mai Phương',
        email: 'phuonghmia160890@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 5, // >20% Banned!
      ),
    ];
  }
}
