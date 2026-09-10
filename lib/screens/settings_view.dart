import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/google_sheet_service.dart';

class SettingsView extends StatefulWidget {
  final String initialSheetUrl;
  final Function(String) onSaveSheetUrl;

  const SettingsView({
    super.key,
    required this.initialSheetUrl,
    required this.onSaveSheetUrl,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialSheetUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = 'Vui lòng nhập URL Google Apps Script Web App!';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await GoogleSheetService.testConnection(url);
    setState(() {
      _isTesting = false;
      _isSuccess = res['success'] == true;
      _testResult = res['message'];
    });

    if (_isSuccess) {
      widget.onSaveSheetUrl(url);
    }
  }

  static const String sampleScript = '''
// === GOOGLE APPS SCRIPT FOR PRM FAP ATTENDANCE DB ===
// Hướng dẫn: Mở Google Sheet > Tiện ích mở rộng (Extensions) > Apps Script
// Dán toàn bộ mã này vào > Bấm Triển khai (Deploy) > Tùy chọn triển khai mới (New deployment)
// Chọn loại: Ứng dụng web (Web app) > Quyền truy cập: Bất kỳ ai (Anyone) > Bấm Triển khai và copy URL!

function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'test';
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  if (action === 'test') {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'Kết nối thành công đến Google Sheet Database!'
    })).setMimeType(ContentService.MimeType.JSON);
  }

  if (action === 'getStudents') {
    var className = e.parameter.className || 'SE1801';
    var sheet = ss.getSheetByName(className) || ss.getActiveSheet();
    var data = sheet.getDataRange().getValues();
    var students = [];

    for (var i = 1; i < data.length; i++) {
      if (data[i][0]) {
        students.push({
          rollNumber: data[i][0],
          fullName: data[i][1] || '',
          email: data[i][2] || '',
          className: className,
          totalSlots: 20,
          absentSlots: 0
        });
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      data: students
    })).setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService.createTextOutput(JSON.stringify({ status: 'unknown_action' }))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var action = body.action;
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    if (action === 'saveAttendance') {
      var className = body.className || 'SE1801';
      var logSheet = ss.getSheetByName('Attendance_Logs');
      if (!logSheet) {
        logSheet = ss.insertSheet('Attendance_Logs');
        logSheet.appendRow(['Thời gian ghi', 'Lớp', 'Ngày học', 'Slot', 'Mã SV', 'Trạng thái', 'Ghi chú']);
        logSheet.getRange(1, 1, 1, 7).setBackground('#F36F21').setFontColor('#FFFFFF').setFontWeight('bold');
      }

      var records = body.records || [];
      var timestamp = new Date();
      for (var j = 0; j < records.length; j++) {
        var r = records[j];
        logSheet.appendRow([timestamp, className, body.date, body.slot, r.rollNumber, r.status, r.note || '']);
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã lưu ' + records.length + ' bản ghi điểm danh!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    if (action === 'syncStudents') {
      var cName = body.className || 'SE1801';
      var stdSheet = ss.getSheetByName(cName) || ss.insertSheet(cName);
      stdSheet.clear();
      stdSheet.appendRow(['Mã SV', 'Họ và tên', 'Email', 'Lớp']);
      stdSheet.getRange(1, 1, 1, 4).setBackground('#2563EB').setFontColor('#FFFFFF').setFontWeight('bold');

      var stds = body.students || [];
      for (var k = 0; k < stds.length; k++) {
        var s = stds[k];
        stdSheet.appendRow([s.rollNumber, s.fullName, s.email, cName]);
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã đồng bộ ' + stds.length + ' sinh viên vào sheet ' + cName
      })).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: 'error', message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
''';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Color(0xFF059669), size: 28),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cấu Hình Kết Nối Google Sheet Database',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sử dụng Google Apps Script Web App làm REST API để đọc/ghi trực tiếp vào Google Sheet',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // URL Configuration Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'URL Google Apps Script Web App (API Endpoint):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isTesting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('Kiểm tra & Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isTesting ? null : _testConnection,
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tutorial & Code Snippet
          Container(
            padding: const EdgeInsets.all(24),
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
                    const Text(
                      'Mã Nguồn Google Apps Script (Backend Database):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF36F21),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Sao chép mã Apps Script'),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: sampleScript));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã sao chép mã Google Apps Script!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '3 bước thiết lập trong 1 phút:\n'
                  '1. Mở Google Sheet mới tại sheet.new > Bấm Tiện ích mở rộng (Extensions) > Apps Script.\n'
                  '2. Xóa code cũ, dán đoạn code bên dưới vào và bấm Ctrl+S.\n'
                  '3. Bấm Triển khai (Deploy) > Tùy chọn triển khai mới > Chọn Ứng dụng web > Bất kỳ ai (Anyone) > Triển khai và copy URL vào ô trên.',
                  style: TextStyle(color: Colors.black87, height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 200,
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SingleChildScrollView(
                    child: SelectableText(
                      sampleScript,
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontFamily: 'Consolas, monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
