import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/google_sheet_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';
import '../widgets/status_badge.dart';

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
  late TextEditingController _geminiKeyController;
  bool _isTestingSheet = false;
  String? _sheetTestResult;
  bool _isSheetSuccess = false;

  bool _isTestingGemini = false;
  String? _geminiTestResult;
  bool _isGeminiSuccess = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialSheetUrl);
    _geminiKeyController = TextEditingController(text: StorageService.getGeminiApiKey());
    _isSheetSuccess = widget.initialSheetUrl.isNotEmpty;
    _isGeminiSuccess = StorageService.getGeminiApiKey().isNotEmpty;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testSheetConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _sheetTestResult = 'Vui lòng nhập URL Google Apps Script Web App!';
        _isSheetSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingSheet = true;
      _sheetTestResult = null;
    });

    final res = await GoogleSheetService.testConnection(url);
    setState(() {
      _isTestingSheet = false;
      _isSheetSuccess = res['success'] == true;
      _sheetTestResult = res['message'];
    });

    if (_isSheetSuccess) {
      widget.onSaveSheetUrl(url);
    }
  }

  Future<void> _saveGeminiKey() async {
    final key = _geminiKeyController.text.trim();
    setState(() => _isTestingGemini = true);

    await StorageService.setGeminiApiKey(key);
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _isTestingGemini = false;
      _isGeminiSuccess = key.isNotEmpty;
      _geminiTestResult = key.isNotEmpty ? 'Đã lưu Google Gemini API Key thành công!' : 'Đã xóa API Key (Chuyển sang chế độ Offline).';
    });
  }

  static const String sampleScript = '''
// === GOOGLE APPS SCRIPT FOR BIRDLE ATTENDANCE DB ===
// Hướng dẫn triển khai (1 phút):
// 1. Mở https://sheet.new > Extensions > Apps Script
// 2. Dán toàn bộ mã này vào > Bấm Deploy > New deployment
// 3. Type: Web app > Execute as: Me > Who has access: Anyone
// 4. Copy Web app URL và dán vào ô bên dưới!

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
          member: data[i][0],
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

  return ContentService.createTextOutput(JSON.stringify({status: 'unknown'})).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  var data = JSON.parse(e.postData.contents);
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var logSheet = ss.getSheetByName('Attendance_Logs');
  if (!logSheet) {
    logSheet = ss.insertSheet('Attendance_Logs');
    logSheet.appendRow(['Timestamp', 'Class', 'Date', 'Slot', 'RollNumber', 'Status', 'Note']);
  }

  if (data.action === 'saveAttendance') {
    var records = data.records || [];
    records.forEach(function(r) {
      logSheet.appendRow([new Date(), data.className, data.date, data.slot, r.rollNumber, r.status, r.note || '']);
    });

    return ContentService.createTextOutput(JSON.stringify({status: 'success'})).setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService.createTextOutput(JSON.stringify({status: 'unknown'})).setMimeType(ContentService.MimeType.JSON);
}
''';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Section 20 design.md)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: BirdleTypography.pageTitle),
              SizedBox(height: 4),
              Text(
                'Quản lý kết nối Google Sheet DB, API Nhà cung cấp AI (BYOK) và hệ thống',
                style: BirdleTypography.metadata,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 1: Data & Google Sheets (Section 20 design.md)
          BirdleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: BirdleColors.brandLight,
                        borderRadius: BirdleRadius.smBorder,
                      ),
                      child: const Icon(Icons.table_chart_outlined, color: BirdleColors.brand, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Google Sheets Database', style: BirdleTypography.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          'Kết nối miễn phí thông qua Google Apps Script Web App REST API',
                          style: BirdleTypography.metadata,
                        ),
                      ],
                    ),
                    const Spacer(),
                    ConnectionStatusChip(
                      label: _isSheetSuccess ? 'Connected' : 'Disconnected',
                      isConnected: _isSheetSuccess,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 18),

                const Text('Web App URL (Google Apps Script)', style: BirdleTypography.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 13, fontFamily: 'Consolas, monospace'),
                        decoration: const InputDecoration(
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          prefixIcon: Icon(Icons.link, size: 18, color: BirdleColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BirdlePrimaryButton(
                      label: 'Test & Save Connection',
                      isLoading: _isTestingSheet,
                      onPressed: _testSheetConnection,
                    ),
                  ],
                ),

                if (_sheetTestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isSheetSuccess ? BirdleColors.successLight : BirdleColors.dangerLight,
                      borderRadius: BirdleRadius.smBorder,
                      border: Border.all(
                        color: _isSheetSuccess ? BirdleColors.success.withValues(alpha: 0.2) : BirdleColors.danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSheetSuccess ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: _isSheetSuccess ? BirdleColors.success : BirdleColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sheetTestResult!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _isSheetSuccess ? BirdleColors.success : BirdleColors.danger,
                              fontWeight: FontWeight.w500,
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
          const SizedBox(height: 24),

          // Section 2: AI Provider - BYOK (Section 19 design.md)
          BirdleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: BirdleColors.surfaceSecondary,
                        borderRadius: BirdleRadius.smBorder,
                      ),
                      child: const Icon(Icons.key_outlined, color: BirdleColors.textPrimary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Provider (Bring Your Own Key - BYOK)', style: BirdleTypography.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          'Your API key is provided by you. Birdle does not use a shared developer API key.',
                          style: BirdleTypography.metadata,
                        ),
                      ],
                    ),
                    const Spacer(),
                    ConnectionStatusChip(
                      label: _isGeminiSuccess ? 'BYOK Active' : 'Offline Mode',
                      isConnected: _isGeminiSuccess,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 18),

                Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Provider', style: BirdleTypography.bodyMedium),
                          SizedBox(height: 8),
                          Text('Google Gemini', style: TextStyle(fontSize: 13, color: BirdleColors.textSecondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Google Gemini API Key', style: BirdleTypography.bodyMedium),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _geminiKeyController,
                            obscureText: _obscureKey,
                            style: const TextStyle(fontSize: 13, fontFamily: 'Consolas, monospace'),
                            decoration: InputDecoration(
                              hintText: 'AIzaSy...',
                              prefixIcon: const Icon(Icons.password, size: 18, color: BirdleColors.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 16, color: BirdleColors.textMuted),
                                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: BirdlePrimaryButton(
                        label: 'Save Key',
                        isLoading: _isTestingGemini,
                        onPressed: _saveGeminiKey,
                      ),
                    ),
                  ],
                ),

                if (_geminiTestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isGeminiSuccess ? BirdleColors.successLight : BirdleColors.surfaceSecondary,
                      borderRadius: BirdleRadius.smBorder,
                      border: Border.all(color: BirdleColors.border),
                    ),
                    child: Text(
                      _geminiTestResult!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _isGeminiSuccess ? BirdleColors.success : BirdleColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Google Apps Script Backend Code & Instructions (Section 20 design.md)
          BirdleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Mã Nguồn Backend Google Apps Script (Code.gs)', style: BirdleTypography.cardTitle),
                    const Spacer(),
                    BirdleSecondaryButton(
                      icon: Icons.copy,
                      label: 'Sao chép mã',
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: sampleScript));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Đã sao chép toàn bộ mã nguồn Google Apps Script!'),
                            backgroundColor: BirdleColors.brand,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BirdleColors.surfaceSecondary,
                    borderRadius: BirdleRadius.smBorder,
                    border: Border.all(color: BirdleColors.border),
                  ),
                  child: const SingleChildScrollView(
                    child: Text(
                      sampleScript,
                      style: TextStyle(fontSize: 11.5, fontFamily: 'Consolas, monospace', color: BirdleColors.textPrimary, height: 1.4),
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
