import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/storage_service.dart';
import '../services/google_sheet_service.dart';
import '../services/ai_analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/birdle_components.dart';
import 'dashboard_view.dart';
import 'attendance_view.dart';
import 'students_view.dart';
import 'reports_view.dart';
import 'ai_insights_view.dart';
import 'fap_sync_view.dart';
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
  int _dataRequestId = 0;
  String? _dataError;
  bool _isReloadError = false;

  List<Student> _students = [];
  List<AttendanceRecord> _records = [];
  List<Map<String, dynamic>> _historyLogs = [];
  AnalyticsDataStatus _analyticsStatus = AnalyticsDataStatus.unconfigured;
  String? _analyticsError;
  bool _isLoadingAnalytics = false;
  int _analyticsRequestId = 0;

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
    } else {
      _isSheetConnected = false;
    }

    await _loadStudentsAndAttendance(isClassChange: true);
    _loadAnalyticsLogs();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAnalyticsLogs([String? targetClass]) async {
    final className = targetClass ?? _currentClass;
    if (_sheetUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _analyticsStatus = AnalyticsDataStatus.unconfigured;
          _historyLogs = [];
          _analyticsError = null;
          _isLoadingAnalytics = false;
        });
      }
      return;
    }

    final currentRequestId = ++_analyticsRequestId;
    setState(() {
      _isLoadingAnalytics = true;
      _analyticsError = null;
    });

    try {
      final logs = await GoogleSheetService.fetchAnalyticsLogs(_sheetUrl, className);
      if (!mounted || currentRequestId != _analyticsRequestId) return;

      setState(() {
        _historyLogs = logs;
        _isLoadingAnalytics = false;
        _analyticsStatus = logs.isEmpty ? AnalyticsDataStatus.empty : AnalyticsDataStatus.loaded;
        _analyticsError = null;
      });
    } catch (e) {
      if (!mounted || currentRequestId != _analyticsRequestId) return;
      setState(() {
        _historyLogs = [];
        _isLoadingAnalytics = false;
        _analyticsStatus = AnalyticsDataStatus.error;
        _analyticsError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadStudentsAndAttendance({bool isClassChange = false}) async {
    final cleanUrl = _sheetUrl.trim();
    if (cleanUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _students = [];
          _records = [];
          _isLoading = false;
          _dataError = null;
          _isReloadError = false;
        });
      }
      return;
    }

    final requestId = ++_dataRequestId;
    setState(() {
      _isLoading = true;
      if (isClassChange) {
        _students = [];
        _records = [];
        _dataError = null;
        _isReloadError = false;
      }
    });

    try {
      final students = await GoogleSheetService.fetchStudents(cleanUrl, _currentClass);
      final dateStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';

      List<AttendanceRecord> existingRecords = [];
      try {
        existingRecords = await GoogleSheetService.fetchAttendance(
          cleanUrl,
          _currentClass,
          dateStr,
          _currentSlot,
        );
      } catch (_) {
        // Attendance logs may not exist yet for this class/slot
      }

      if (!mounted || requestId != _dataRequestId) return;

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
        _dataError = null;
        _isReloadError = false;
      });
    } catch (e) {
      if (!mounted || requestId != _dataRequestId) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();

      setState(() {
        _isLoading = false;
        _dataError = errorMsg;
        if (isClassChange || _students.isEmpty) {
          _students = [];
          _records = [];
          _isReloadError = false;
        } else {
          _isReloadError = true;
        }
      });

      if (_isReloadError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lại dữ liệu: $errorMsg'),
            backgroundColor: BirdleColors.danger,
          ),
        );
      }
    }
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
          content: Text('⚠️ Vui lòng cấu hình URL Google Apps Script Web App trong Cài đặt trước!'),
          backgroundColor: BirdleColors.warning,
        ),
      );
      setState(() => _selectedIndex = 6);
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

    if (result['success'] == true) {
      _loadAnalyticsLogs();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: result['success'] ? BirdleColors.brand : BirdleColors.danger,
        ),
      );
    }
  }

  Future<void> _syncStudentsToSheet() async {
    if (_sheetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng cấu hình URL Google Sheet trong mục Cài đặt!'),
          backgroundColor: BirdleColors.warning,
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
          backgroundColor: res['success'] ? BirdleColors.brand : BirdleColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BirdleColors.appBackground,
      body: Row(
        children: [
          // Sidebar (Section 9.1 design.md)
          _buildSidebar(),

          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      // 0: Dashboard
                      DashboardView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        currentSlot: _currentSlot,
                        currentDate: _currentDate,
                        isSheetConnected: _isSheetConnected,
                        onGoToAttendance: () => setState(() => _selectedIndex = 1),
                        onGoToFapSync: () => setState(() => _selectedIndex = 5),
                        onGoToSettings: () => setState(() => _selectedIndex = 6),
                      ),
                      // 1: Attendance
                      AttendanceView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        currentSlot: _currentSlot,
                        currentDate: _currentDate,
                        isLoading: _isLoading,
                        errorMessage: _dataError,
                        isSheetConfigured: _sheetUrl.isNotEmpty,
                        onGoToSettings: () => setState(() => _selectedIndex = 6),
                        onClassChanged: (val) {
                          setState(() {
                            _currentClass = val;
                            _students = [];
                            _records = [];
                            _dataError = null;
                            _isReloadError = false;
                          });
                          StorageService.setSelectedClass(val);
                          _loadStudentsAndAttendance(isClassChange: true);
                          _loadAnalyticsLogs(val);
                        },
                        onSlotChanged: (val) {
                          setState(() => _currentSlot = val);
                          _loadStudentsAndAttendance(isClassChange: false);
                        },
                        onDateChanged: (val) {
                          setState(() => _currentDate = val);
                          _loadStudentsAndAttendance(isClassChange: false);
                        },
                        onStatusChanged: _onStatusChanged,
                        onNoteChanged: _onNoteChanged,
                        onMarkAllPresent: _markAllPresent,
                        onMarkAllAbsent: _markAllAbsent,
                        onSaveToSheet: _saveToGoogleSheet,
                        onReloadFromSheet: () {
                          _loadStudentsAndAttendance(isClassChange: false);
                          _loadAnalyticsLogs();
                        },
                        onGoToFapSync: () => setState(() => _selectedIndex = 5),
                        onImportStudents: (newStudents) {
                          setState(() {
                            _students = newStudents;
                            _dataError = null;
                            _isReloadError = false;
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
                      // 2: Students
                      StudentsView(
                        students: _students,
                        currentClass: _currentClass,
                        isLoading: _isLoading,
                        errorMessage: _dataError,
                        isSheetConfigured: _sheetUrl.isNotEmpty,
                        onReload: () => _loadStudentsAndAttendance(isClassChange: false),
                        onGoToSettings: () => setState(() => _selectedIndex = 6),
                        onUpdateStudents: (updated) {
                          setState(() => _students = updated);
                        },
                        onClassChanged: (val) {
                          setState(() {
                            _currentClass = val;
                            _students = [];
                            _records = [];
                            _dataError = null;
                            _isReloadError = false;
                          });
                          StorageService.setSelectedClass(val);
                          _loadStudentsAndAttendance(isClassChange: true);
                          _loadAnalyticsLogs(val);
                        },
                        onSyncToSheet: _syncStudentsToSheet,
                        onGoToImport: () => setState(() => _selectedIndex = 5),
                      ),
                      // 3: Reports
                      ReportsView(
                        students: _students,
                        currentClass: _currentClass,
                        googleSheetUrl: _sheetUrl,
                      ),
                      // 4: AI Insights
                      AiInsightsView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        historyLogs: _historyLogs,
                        analyticsStatus: _analyticsStatus,
                        analyticsError: _analyticsError,
                        isLoadingAnalytics: _isLoadingAnalytics,
                        onRetryLoadAnalytics: () => _loadAnalyticsLogs(),
                        onConfigureByok: () => setState(() => _selectedIndex = 6),
                      ),
                      // 5: FAP Sync & Import Center
                      FapSyncView(
                        students: _students,
                        records: _records,
                        currentClass: _currentClass,
                        currentSlot: _currentSlot,
                        onImportStudents: (newStudents) {
                          setState(() {
                            _students = newStudents;
                            _dataError = null;
                            _isReloadError = false;
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
                        onSaveToSheet: _saveToGoogleSheet,
                      ),
                      // 6: Settings
                      SettingsView(
                        initialSheetUrl: _sheetUrl,
                        onSaveSheetUrl: (url) {
                          setState(() {
                            _sheetUrl = url;
                            _isSheetConnected = url.isNotEmpty;
                          });
                          StorageService.setGoogleSheetUrl(url);
                          _loadStudentsAndAttendance(isClassChange: true);
                          _loadAnalyticsLogs();
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
      width: 236,
      decoration: const BoxDecoration(
        color: BirdleColors.surface,
        border: Border(right: BorderSide(color: BirdleColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Logo & App Identity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: BirdleColors.brand,
                    borderRadius: BirdleRadius.smBorder,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: BirdleTypography.fontFamily,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BIRDLE',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: BirdleColors.textPrimary,
                          fontFamily: BirdleTypography.fontFamily,
                        ),
                      ),
                      Text(
                        'Attendance Workspace',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: BirdleColors.textSecondary,
                          fontFamily: BirdleTypography.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Nav Sections (Section 9.1 design.md)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildSectionHeader('OVERVIEW'),
                _buildNavItem(0, 'Dashboard', Icons.space_dashboard_outlined),

                const SizedBox(height: 16),
                _buildSectionHeader('ATTENDANCE'),
                _buildNavItem(1, 'Attendance', Icons.fact_check_outlined),
                _buildNavItem(2, 'Students', Icons.people_outline),
                _buildNavItem(3, 'Reports', Icons.insert_chart_outlined),

                const SizedBox(height: 16),
                _buildSectionHeader('INTELLIGENCE'),
                _buildNavItem(4, 'AI Insights', Icons.insights_outlined),

                const SizedBox(height: 16),
                _buildSectionHeader('INTEGRATION'),
                _buildNavItem(5, 'FAP Sync', Icons.sync),

                const SizedBox(height: 16),
                _buildSectionHeader('SYSTEM'),
                _buildNavItem(6, 'Settings', Icons.settings_outlined),
              ],
            ),
          ),

          // Bottom Connection Status (Section 9.1 design.md)
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionRow('Google Sheets', _isSheetConnected ? 'Connected' : 'Not configured', _isSheetConnected),
                const SizedBox(height: 8),
                _buildConnectionRow('FAP Portal', 'Ready', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: BirdleColors.textMuted,
          letterSpacing: 0.8,
          fontFamily: BirdleTypography.fontFamily,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BirdleRadius.smBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
          decoration: BoxDecoration(
            color: isSelected ? BirdleColors.brandLight : Colors.transparent,
            borderRadius: BirdleRadius.smBorder,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? BirdleColors.brand : BirdleColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? BirdleColors.brand : BirdleColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                  fontFamily: BirdleTypography.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionRow(String title, String status, bool isConnected) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isConnected ? BirdleColors.brand : BirdleColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BirdleColors.textPrimary),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            color: isConnected ? BirdleColors.brand : BirdleColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: BirdleColors.surface,
        border: Border(bottom: BorderSide(color: BirdleColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Title / Breadcrumb
          Text(
            _getScreenTitle(),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: BirdleColors.textPrimary,
              fontFamily: BirdleTypography.fontFamily,
            ),
          ),
          const Spacer(),

          // Status Badges
          ConnectionStatusChip(
            label: _isSheetConnected ? 'Sheets: Connected' : 'Sheets: Unlinked',
            isConnected: _isSheetConnected,
          ),
          const SizedBox(width: 8),
          const ConnectionStatusChip(label: 'FAP: Ready', isConnected: true),
          const SizedBox(width: 14),

          // Quick Links
          BirdleSecondaryButton(
            icon: Icons.open_in_browser,
            label: 'FAP',
            height: 32,
            onPressed: () => StorageService.openBrowser('https://fap.fpt.edu.vn'),
          ),
          if (_sheetUrl.isNotEmpty) ...[
            const SizedBox(width: 8),
            BirdleSecondaryButton(
              icon: Icons.table_chart_outlined,
              label: 'Sheet',
              height: 32,
              iconColor: BirdleColors.brand,
              onPressed: () => StorageService.openBrowser(_sheetUrl),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: BirdleColors.textSecondary),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              _loadStudentsAndAttendance(isClassChange: false);
              _loadAnalyticsLogs();
            },
          ),
        ],
      ),
    );
  }

  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Overview / Dashboard';
      case 1:
        return 'Attendance / Workspace';
      case 2:
        return 'Attendance / Students';
      case 3:
        return 'Attendance / Reports';
      case 4:
        return 'Intelligence / AI Insights';
      case 5:
        return 'Integration / FAP Sync & Import';
      case 6:
        return 'System / Settings';
      default:
        return 'Birdle';
    }
  }
}
