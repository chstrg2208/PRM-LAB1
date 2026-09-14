import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/storage_service.dart';
import '../services/google_sheet_service.dart';
import 'dashboard_view.dart';
import 'attendance_view.dart';
import 'students_view.dart';
import 'reports_view.dart';
import 'ai_insights_view.dart';
import 'settings_view.dart';

class MainDesktopScreen extends StatefulWidget {
  const MainDesktopScreen({super.key});

  @override
  State<MainDesktopScreen> createState() => _MainDesktopScreenState();
}

class _MainDesktopScreenState extends State<MainDesktopScreen> {
  int _selectedIndex = 0;
  String _currentClass = 'SE1801';
  int _currentSlot = 1;
  DateTime _currentDate = DateTime.now();
  String _sheetUrl = '';
  bool _isSheetConnected = false;
  bool _isLoading = false;

  List<Student> _students = [];
  List<AttendanceRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await StorageService.init();
    final savedUrl = StorageService.getGoogleSheetUrl();
    final savedClass = StorageService.getSelectedClass();

    setState(() {
      _sheetUrl = savedUrl;
      _currentClass = savedClass;
      _isLoading = true;
    });

    if (_sheetUrl.isNotEmpty) {
      final res = await GoogleSheetService.testConnection(_sheetUrl);
      _isSheetConnected = res['success'] == true;
    }

    await _loadStudentsAndAttendance();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadStudentsAndAttendance() async {
    setState(() => _isLoading = true);

    // Fetch students
    final students = await GoogleSheetService.fetchStudents(_sheetUrl, _currentClass);

    // Fetch or init attendance records
    final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    final existingRecords = await GoogleSheetService.fetchAttendance(
      _sheetUrl,
      _currentClass,
      dateStr,
      _currentSlot,
    );

    final records = <AttendanceRecord>[];
    for (final s in students) {
      final found = existingRecords.where((r) => r.rollNumber == s.rollNumber).firstOrNull;
      if (found != null) {
        records.add(found);
      } else {
        records.add(
          AttendanceRecord(
            rollNumber: s.rollNumber,
            className: _currentClass,
            date: dateStr,
            slot: _currentSlot,
            status: AttendanceStatus.present,
          ),
        );
      }
    }

    setState(() {
      _students = students;
      _records = records;
      _isLoading = false;
    });
  }

  void _onStatusChanged(String rollNumber, AttendanceStatus newStatus) {
    setState(() {
      final rec = _records.where((r) => r.rollNumber == rollNumber).firstOrNull;
      if (rec != null) {
        rec.status = newStatus;
      }
    });
  }

  void _onNoteChanged(String rollNumber, String newNote) {
    setState(() {
      final rec = _records.where((r) => r.rollNumber == rollNumber).firstOrNull;
      if (rec != null) {
        rec.note = newNote;
      }
    });
  }

  void _markAllPresent() {
    setState(() {
      for (final r in _records) {
        r.status = AttendanceStatus.present;
      }
    });
  }

  void _markAllAbsent() {
    setState(() {
      for (final r in _records) {
        r.status = AttendanceStatus.absent;
      }
    });
  }

  Future<void> _saveToGoogleSheet() async {
    if (_sheetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng cài đặt URL Google Apps Script trong mục Cài đặt trước!'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _selectedIndex = 5);
      return;
    }

    setState(() => _isLoading = true);
    final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    final result = await GoogleSheetService.saveAttendance(
      webAppUrl: _sheetUrl,
      className: _currentClass,
      date: dateStr,
      slot: _currentSlot,
      records: _records,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: result['success'] ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _syncStudentsToSheet() async {
    if (_sheetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng cấu hình URL Google Sheet trong mục Cài đặt!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await GoogleSheetService.syncStudents(
      webAppUrl: _sheetUrl,
      className: _currentClass,
      students: _students,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? ''),
          backgroundColor: res['success'] ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Sidebar / Left Navigation Rail
          _buildSidebar(),

          // Main Screen Content
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      DashboardView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        currentSlot: _currentSlot,
                        currentDate: _currentDate,
                        isSheetConnected: _isSheetConnected,
                        onGoToAttendance: () => setState(() => _selectedIndex = 1),
                        onGoToSettings: () => setState(() => _selectedIndex = 5),
                      ),
                      AttendanceView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        currentSlot: _currentSlot,
                        currentDate: _currentDate,
                        isLoading: _isLoading,
                        onClassChanged: (val) {
                          setState(() => _currentClass = val);
                          StorageService.setSelectedClass(val);
                          _loadStudentsAndAttendance();
                        },
                        onSlotChanged: (val) {
                          setState(() => _currentSlot = val);
                          _loadStudentsAndAttendance();
                        },
                        onDateChanged: (val) {
                          setState(() => _currentDate = val);
                          _loadStudentsAndAttendance();
                        },
                        onStatusChanged: _onStatusChanged,
                        onNoteChanged: _onNoteChanged,
                        onMarkAllPresent: _markAllPresent,
                        onMarkAllAbsent: _markAllAbsent,
                        onSaveToSheet: _saveToGoogleSheet,
                        onReloadFromSheet: _loadStudentsAndAttendance,
                        onImportStudents: (newStudents) {
                          setState(() {
                            _students = newStudents;
                            _records = newStudents.map((s) {
                              return AttendanceRecord(
                                rollNumber: s.rollNumber,
                                className: _currentClass,
                                date: _currentDate.toIso8601String(),
                                slot: _currentSlot,
                                status: AttendanceStatus.present,
                              );
                            }).toList();
                          });
                        },
                      ),
                      StudentsView(
                        students: _students,
                        currentClass: _currentClass,
                        onUpdateStudents: (updated) {
                          setState(() => _students = updated);
                        },
                        onClassChanged: (val) {
                          setState(() => _currentClass = val);
                          StorageService.setSelectedClass(val);
                          _loadStudentsAndAttendance();
                        },
                        onSyncToSheet: _syncStudentsToSheet,
                      ),
                      ReportsView(
                        students: _students,
                        currentClass: _currentClass,
                        googleSheetUrl: _sheetUrl,
                      ),
                      AiInsightsView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                      ),
                      SettingsView(
                        initialSheetUrl: _sheetUrl,
                        onSaveSheetUrl: (url) {
                          setState(() {
                            _sheetUrl = url;
                            _isSheetConnected = true;
                          });
                          StorageService.setGoogleSheetUrl(url);
                        },
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

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Column(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF36F21),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAP Assistant',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'PRM Lab 1 Desktop',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 12),

          // Nav Items
          _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
          _buildNavItem(1, 'Điểm danh', Icons.checklist_rtl_outlined),
          _buildNavItem(2, 'Danh sách lớp', Icons.group_outlined),
          _buildNavItem(3, 'Báo cáo chuyên cần', Icons.analytics_outlined),
          _buildNavItem(4, 'Trợ lý AI Phân tích', Icons.auto_awesome_outlined),
          _buildNavItem(5, 'Cài đặt kết nối DB', Icons.settings_outlined),

          const Spacer(),

          // System Info Card at bottom of sidebar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_done, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Google Sheet DB',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isSheetConnected ? 'Trực tuyến (Connected)' : 'Chưa kết nối Web App',
                  style: TextStyle(
                    color: _isSheetConnected ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF36F21) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            _getScreenTitle(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const Spacer(),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            icon: const Icon(Icons.open_in_browser, size: 16, color: Color(0xFFF36F21)),
            label: const Text('Mở FAP', style: TextStyle(fontSize: 12, color: Colors.black87)),
            onPressed: () => StorageService.openBrowser('https://fap.fpt.edu.vn'),
          ),
          const SizedBox(width: 10),

          if (_sheetUrl.isNotEmpty) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              icon: const Icon(Icons.table_chart, size: 16, color: Color(0xFF059669)),
              label: const Text('Google Sheet', style: TextStyle(fontSize: 12, color: Colors.black87)),
              onPressed: () => StorageService.openBrowser(_sheetUrl),
            ),
            const SizedBox(width: 10),
          ],

          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadStudentsAndAttendance,
          ),
        ],
      ),
    );
  }

  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Bảng điều khiển Tổng quan (Dashboard)';
      case 1:
        return 'Điểm danh Sinh viên (Take Attendance)';
      case 2:
        return 'Quản lý Danh sách lớp & Sinh viên';
      case 3:
        return 'Báo cáo Chuyên cần Cả kỳ';
      case 4:
        return 'Trợ lý AI Phân tích Chuyên cần';
      case 5:
        return 'Cài đặt Kết nối Google Sheet DB';
      default:
        return '';
    }
  }
}
