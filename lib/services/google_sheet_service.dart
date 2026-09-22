import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance_record.dart';

enum GoogleSheetErrorType {
  unconfigured,
  network,
  httpError,
  invalidJson,
  invalidSchema,
  apiError,
}

class GoogleSheetException implements Exception {
  final GoogleSheetErrorType type;
  final String message;
  final int? statusCode;
  final dynamic details;

  const GoogleSheetException({
    required this.type,
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}

class GoogleSheetService {
  /// Chuẩn hóa việc phân tích phản hồi từ Google Apps Script
  static Map<String, dynamic> _parseApiResponse(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 302) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.httpError,
        statusCode: response.statusCode,
        message: 'Lỗi máy chủ Google Apps Script: HTTP ${response.statusCode}',
      );
    }

    dynamic decoded;
    try {
      final text = response.bodyBytes.isNotEmpty
          ? utf8.decode(response.bodyBytes, allowMalformed: true)
          : response.body;
      decoded = jsonDecode(text);
    } catch (_) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidJson,
        message: 'Phản hồi từ Google Apps Script không đúng định dạng JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'Dữ liệu phản hồi không đúng định dạng JSON object.',
      );
    }

    final isError = decoded['status'] == 'error' || decoded['success'] == false;
    if (isError) {
      final msg = (decoded['error'] ?? decoded['message'] ?? 'Lỗi từ Google Apps Script').toString();
      throw GoogleSheetException(
        type: GoogleSheetErrorType.apiError,
        message: msg,
        details: decoded,
      );
    }

    final isSuccess = decoded['status'] == 'success' || decoded['success'] == true;
    if (!isSuccess) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'Cấu trúc dữ liệu phản hồi từ Google Apps Script không hợp lệ.',
      );
    }

    return decoded;
  }

  /// Test connection to Google Apps Script Web App
  static Future<Map<String, dynamic>> testConnection(String webAppUrl, {http.Client? client}) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      return {'success': false, 'message': 'Chưa cấu hình URL Google Sheet Web App!'};
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return {'success': false, 'message': 'URL Google Sheet không hợp lệ!'};
    }

    final httpClient = client ?? http.Client();
    try {
      final testUri = uri.replace(queryParameters: {...uri.queryParameters, 'action': 'test'});
      final response = await httpClient.get(testUri).timeout(const Duration(seconds: 10));
      final decoded = _parseApiResponse(response);

      return {
        'success': true,
        'message': decoded['message'] ?? 'Kết nối thành công đến Google Sheet Database!',
        'data': decoded,
      };
    } catch (e) {
      final msg = e is GoogleSheetException ? e.message : 'Không thể kết nối đến Google Sheet: $e';
      return {
        'success': false,
        'message': msg,
      };
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Lấy danh sách lớp hợp lệ từ Google Sheet
  static Future<List<String>> fetchClasses(
    String webAppUrl, {
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.unconfigured,
        message: 'Chưa cấu hình URL Google Sheet trong Cài đặt.',
      );
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'URL Google Sheet không hợp lệ.',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getClasses',
      });
      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 12));
      final decoded = _parseApiResponse(response);

      final rawData = decoded['data'];
      if (rawData is! List) {
        throw const GoogleSheetException(
          type: GoogleSheetErrorType.invalidSchema,
          message: 'Dữ liệu danh sách lớp trả về không phải là danh sách.',
        );
      }

      final classes = rawData
          .map((item) => item?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return classes;
    } on GoogleSheetException {
      rethrow;
    } on SocketException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Không thể kết nối đến Google Sheet. Vui lòng kiểm tra lại mạng internet.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Hết thời gian chờ phản hồi từ Google Sheet (timeout).',
        details: e,
      );
    } catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Lỗi khi tải danh sách lớp: $e',
        details: e,
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Lấy danh sách sinh viên theo lớp từ Google Sheet
  static Future<List<Student>> fetchStudents(
    String webAppUrl,
    String className, {
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.unconfigured,
        message: 'Chưa cấu hình URL Google Sheet trong Cài đặt.',
      );
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'URL Google Sheet không hợp lệ.',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getStudents',
        'className': className,
      });
      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 12));
      final decoded = _parseApiResponse(response);

      final rawData = decoded['data'];
      if (rawData is! List) {
        throw const GoogleSheetException(
          type: GoogleSheetErrorType.invalidSchema,
          message: 'Dữ liệu sinh viên trả về không phải là danh sách.',
        );
      }

      return rawData.map((item) {
        if (item is Map<String, dynamic>) {
          return Student.fromJson(item);
        }
        return Student.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } on GoogleSheetException {
      rethrow;
    } on SocketException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Không thể kết nối đến Google Sheet. Vui lòng kiểm tra lại mạng internet.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Hết thời gian chờ phản hồi từ Google Sheet (timeout).',
        details: e,
      );
    } catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Lỗi khi tải danh sách sinh viên: $e',
        details: e,
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Lấy dữ liệu điểm danh theo lớp, ngày, slot từ Google Sheet
  static Future<List<AttendanceRecord>> fetchAttendance(
    String webAppUrl,
    String className,
    String date,
    int slot, {
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.unconfigured,
        message: 'Chưa cấu hình URL Google Sheet trong Cài đặt.',
      );
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'URL Google Sheet không hợp lệ.',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getAttendance',
        'className': className,
        'date': date,
        'slot': slot.toString(),
      });
      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 12));
      final decoded = _parseApiResponse(response);

      final rawData = decoded['data'];
      if (rawData is! List) {
        throw const GoogleSheetException(
          type: GoogleSheetErrorType.invalidSchema,
          message: 'Dữ liệu điểm danh trả về không phải là danh sách.',
        );
      }

      return rawData.map((item) {
        if (item is Map<String, dynamic>) {
          return AttendanceRecord.fromJson(item);
        }
        return AttendanceRecord.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } on GoogleSheetException {
      rethrow;
    } on SocketException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Không thể kết nối đến Google Sheet. Vui lòng kiểm tra lại mạng internet.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Hết thời gian chờ phản hồi từ Google Sheet (timeout).',
        details: e,
      );
    } catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Lỗi khi tải dữ liệu điểm danh: $e',
        details: e,
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Ghi dữ liệu điểm danh lên Google Sheet
  static Future<Map<String, dynamic>> saveAttendance({
    required String webAppUrl,
    required String className,
    required String date,
    required int slot,
    required List<AttendanceRecord> records,
    int? sessionNumber,
    bool bypassDateLock = false,
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      return {
        'success': false,
        'message': 'Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt trước khi lưu!',
      };
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return {
        'success': false,
        'message': 'URL Google Sheet không hợp lệ!',
      };
    }

    final httpClient = client ?? http.Client();
    try {
      final payloadMap = <String, dynamic>{
        'action': 'saveAttendance',
        'className': className,
        'date': date,
        'slot': slot,
        'records': records.map((r) => r.toJson()).toList(),
      };
      if (sessionNumber != null) {
        payloadMap['sessionNumber'] = sessionNumber;
      }
      if (bypassDateLock) {
        payloadMap['bypassDateLock'] = true;
      }
      final payload = jsonEncode(payloadMap);

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      final decoded = _parseApiResponse(response);

      return {
        'success': true,
        'message': decoded['message'] ?? 'Đã lưu điểm danh thành công vào Google Sheet!',
        'data': decoded,
      };
    } catch (e) {
      final msg = e is GoogleSheetException ? e.message : 'Lỗi lưu điểm danh lên Google Sheet: $e';
      return {
        'success': false,
        'message': msg,
      };
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Đồng bộ danh sách sinh viên lớp lên Google Sheet
  static Future<Map<String, dynamic>> syncStudents({
    required String webAppUrl,
    required String className,
    required List<Student> students,
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      return {
        'success': false,
        'message': 'Chưa cấu hình URL Google Sheet Web App!',
      };
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return {
        'success': false,
        'message': 'URL Google Sheet không hợp lệ!',
      };
    }

    final httpClient = client ?? http.Client();
    try {
      final payload = jsonEncode({
        'action': 'syncStudents',
        'className': className,
        'students': students.map((s) => s.toJson()).toList(),
      });

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      final decoded = _parseApiResponse(response);

      return {
        'success': true,
        'message': decoded['message'] ?? 'Đã đồng bộ ${students.length} sinh viên lên Google Sheet thành công!',
        'data': decoded,
      };
    } catch (e) {
      final msg = e is GoogleSheetException ? e.message : 'Lỗi đồng bộ sinh viên: $e';
      return {
        'success': false,
        'message': msg,
      };
    } finally {
      if (client == null) {
        httpClient.close();
      }
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

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'URL Google Sheet không hợp lệ.',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getAnalyticsData',
        'className': className,
      });
      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 12));
      final decoded = _parseApiResponse(response);

      final rawLogs = decoded['logs'] ?? decoded['data'];
      if (rawLogs is List) {
        return List<Map<String, dynamic>>.from(rawLogs);
      }
      throw const GoogleSheetException(
        type: GoogleSheetErrorType.invalidSchema,
        message: 'Dữ liệu lịch sử phân tích không phải là danh sách.',
      );
    } on GoogleSheetException {
      rethrow;
    } on SocketException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Không thể kết nối đến Google Sheet. Vui lòng kiểm tra lại mạng internet.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Hết thời gian chờ phản hồi từ Google Sheet (timeout).',
        details: e,
      );
    } catch (e) {
      throw GoogleSheetException(
        type: GoogleSheetErrorType.network,
        message: 'Lỗi tải dữ liệu lịch sử phân tích: $e',
        details: e,
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Lấy danh sách tiết học có lịch trong ngày hôm nay theo quy tắc FPT
  static Future<List<Map<String, dynamic>>> fetchTodayClasses(
    String webAppUrl, {
    DateTime? date,
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) {
      return [];
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return [];
    }

    final targetDate = date ?? DateTime.now();
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getTodayClasses',
        'date': dateStr,
      });

      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 10));
      final decoded = _parseApiResponse(response);
      final rawData = decoded['data'];
      if (rawData is List) {
        return List<Map<String, dynamic>>.from(
          rawData.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Lấy danh sách email sinh viên đã quét QR check-in thành công
  static Future<List<String>> fetchQrCheckedInEmails(
    String webAppUrl, {
    required String className,
    required int slot,
    DateTime? date,
    http.Client? client,
  }) async {
    final cleanUrl = webAppUrl.trim();
    if (cleanUrl.isEmpty) return [];

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) return [];

    final targetDate = date ?? DateTime.now();
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    final httpClient = client ?? http.Client();
    try {
      final requestUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'action': 'getQrStatus',
        'className': className,
        'slot': slot.toString(),
        'date': dateStr,
      });

      final response = await httpClient.get(requestUri).timeout(const Duration(seconds: 6));
      final decoded = _parseApiResponse(response);
      final rawData = decoded['data'];
      if (rawData is List) {
        return rawData
            .map((item) => (item is Map ? item['email'] : item)?.toString().trim().toLowerCase() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Danh sách mẫu sinh viên FPT phục vụ mục đích kiểm thử độc lập
  static List<Student> getSampleStudentsForTesting([String className = 'SE1801']) {
    return [
      Student(
        member: 'CE190585',
        code: 'CE190585',
        surname: 'Lâm',
        middleName: 'Quốc',
        givenName: 'Minh',
        email: 'minhlqce190585@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        member: 'SE170123',
        code: 'SE170123',
        surname: 'Nguyễn',
        middleName: 'Văn',
        givenName: 'An',
        email: 'annvse170123@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 2,
      ),
      Student(
        member: 'SE170456',
        code: 'SE170456',
        surname: 'Trần',
        middleName: 'Thị',
        givenName: 'Bình',
        email: 'binhttse170456@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        member: 'SE170789',
        code: 'SE170789',
        surname: 'Lê',
        middleName: 'Hoàng',
        givenName: 'Cường',
        email: 'cuonglhse170789@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 3,
      ),
      Student(
        member: 'SE171012',
        code: 'SE171012',
        surname: 'Phạm',
        middleName: 'Minh',
        givenName: 'Đức',
        email: 'ducpmse171012@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 5, // 25% -> FAIL ATTENDANCE (CẤM THI)
      ),
      Student(
        member: 'SE171345',
        code: 'SE171345',
        surname: 'Vũ',
        middleName: 'Hải',
        givenName: 'Đăng',
        email: 'dangvhse171345@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 4, // 20% -> FAIL ATTENDANCE (CẤM THI)
      ),
      Student(
        member: 'HE160234',
        code: 'HE160234',
        surname: 'Đỗ',
        middleName: 'Thùy',
        givenName: 'Linh',
        email: 'linhdthe160234@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 0,
      ),
      Student(
        member: 'HE160567',
        code: 'HE160567',
        surname: 'Ngô',
        middleName: 'Quốc',
        givenName: 'Nam',
        email: 'namnqhe160567@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 1,
      ),
      Student(
        member: 'IA160890',
        code: 'IA160890',
        surname: 'Hoàng',
        middleName: 'Mai',
        givenName: 'Phương',
        email: 'phuonghmia160890@fpt.edu.vn',
        className: className,
        totalSlots: 20,
        absentSlots: 6, // 30% -> FAIL ATTENDANCE
      ),
    ];
  }
}
