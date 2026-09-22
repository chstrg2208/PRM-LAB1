import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../state/attendance_session_manager.dart';
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
  final AttendanceSessionManager? sessionManager;

  const MainDesktopScreen({super.key, this.sessionManager});

  @override
  State<MainDesktopScreen> createState() => _MainDesktopScreenState();
}

class _MainDesktopScreenState extends State<MainDesktopScreen> {
  int _selectedIndex = 0;
  AttendanceSessionManager? _internalManager;

  AttendanceSessionManager get _sessionManager => widget.sessionManager ?? _internalManager!;

  @override
  void initState() {
    super.initState();
    if (widget.sessionManager == null) {
      _internalManager = AttendanceSessionManager();
      _internalManager!.initialize();
    }
  }

  @override
  void dispose() {
    _internalManager?.dispose();
    super.dispose();
  }

  Future<void> _saveToGoogleSheet() async {
    final result = await _sessionManager.saveAttendance();
    if (!mounted) return;

    if (result.requiresConfiguration) {
      setState(() => _selectedIndex = 6);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.requiresConfiguration
            ? BirdleColors.warning
            : (result.success ? BirdleColors.brand : BirdleColors.danger),
      ),
    );
  }

  Future<void> _syncStudentsToSheet() async {
    final result = await _sessionManager.syncStudents();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.requiresConfiguration
            ? BirdleColors.warning
            : (result.success ? BirdleColors.brand : BirdleColors.danger),
      ),
    );
  }

  Future<void> _reloadFromSheet() async {
    final err = await _sessionManager.reload();
    if (err != null && _sessionManager.isReloadError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải lại dữ liệu: $err'),
          backgroundColor: BirdleColors.danger,
        ),
      );
    }
  }

  Future<void> _exportReportCsv() async {
    final result = await _sessionManager.exportCurrentReportCsv();
    if (!mounted) return;

    final message = result.success && result.filePath != null
        ? '${result.message} (${result.filePath})'
        : result.message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.success ? BirdleColors.brand : BirdleColors.danger,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionManager,
      builder: (context, _) {
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
                            students: _sessionManager.students,
                            records: _sessionManager.records,
                            currentClass: _sessionManager.currentClass,
                            currentSlot: _sessionManager.currentSlot,
                            currentDate: _sessionManager.currentDate,
                            isSheetConnected: _sessionManager.isSheetConnected,
                            todayClasses: _sessionManager.todayClasses,
                            onSelectClassAndSlot: (cName, slot) {
                              _sessionManager.selectClass(cName);
                              _sessionManager.selectSlot(slot);
                            },
                            onGoToAttendance: () => setState(() => _selectedIndex = 1),
                            onGoToFapSync: () => setState(() => _selectedIndex = 5),
                            onGoToSettings: () => setState(() => _selectedIndex = 6),
                          ),
                          // 1: Attendance
                          AttendanceView(
                            students: _sessionManager.students,
                            records: _sessionManager.records,
                            currentClass: _sessionManager.currentClass,
                            availableClasses: _sessionManager.availableClasses,
                            isLoadingClasses: _sessionManager.isLoadingClasses,
                            classesError: _sessionManager.classesError,
                            onRetryLoadClasses: () => _sessionManager.loadClasses(),
                            currentSlot: _sessionManager.currentSlot,
                            currentDate: _sessionManager.currentDate,
                            isDateLocked: _sessionManager.isSessionDateLocked,
                            isLoading: _sessionManager.isLoading,
                            errorMessage: _sessionManager.dataError,
                            isSheetConfigured: _sessionManager.isSheetConfigured,
                            onGoToSettings: () => setState(() => _selectedIndex = 6),
                            onClassChanged: _sessionManager.selectClass,
                            onSlotChanged: _sessionManager.selectSlot,
                            onDateChanged: _sessionManager.selectDate,
                            onStatusChanged: _sessionManager.updateAttendanceStatus,
                            onNoteChanged: _sessionManager.updateNote,
                            onMarkAllPresent: _sessionManager.markAllPresent,
                            onMarkAllAbsent: _sessionManager.markAllAbsent,
                            currentSessionNumber: _sessionManager.currentSessionNumber,
                            onStartQrAttendance: () => _sessionManager.startQrAttendanceSession(),
                            onFinishQrAttendance: () => _sessionManager.finishQrAttendance(),
                            onCancelQrAttendance: () => _sessionManager.cancelQrAttendance(),
                            onPollQrStatus: () => _sessionManager.pollQrCheckIns(),
                            isQrAttendanceLocked: _sessionManager.isQrAttendanceLocked,
                            isSessionCompleted: _sessionManager.isSessionCompleted,
                            onReopenQrAttendance: () => _sessionManager.reopenQrAttendanceSession(),
                            onSaveToSheet: _saveToGoogleSheet,
                            onReloadFromSheet: _reloadFromSheet,
                            onGoToFapSync: () => setState(() => _selectedIndex = 5),
                            onImportStudents: _sessionManager.importStudents,
                          ),
                          // 2: Students
                          StudentsView(
                            students: _sessionManager.students,
                            currentClass: _sessionManager.currentClass,
                            availableClasses: _sessionManager.availableClasses,
                            isLoadingClasses: _sessionManager.isLoadingClasses,
                            classesError: _sessionManager.classesError,
                            onRetryLoadClasses: () => _sessionManager.loadClasses(),
                            isLoading: _sessionManager.isLoading,
                            errorMessage: _sessionManager.dataError,
                            isSheetConfigured: _sessionManager.isSheetConfigured,
                            onReload: _reloadFromSheet,
                            onGoToSettings: () => setState(() => _selectedIndex = 6),
                            onUpdateStudents: _sessionManager.updateStudents,
                            onClassChanged: _sessionManager.selectClass,
                            onSyncToSheet: _syncStudentsToSheet,
                            onGoToImport: () => setState(() => _selectedIndex = 5),
                          ),
                          // 3: Reports
                          ReportsView(
                            students: _sessionManager.students,
                            currentClass: _sessionManager.currentClass,
                            googleSheetUrl: _sessionManager.sheetUrl,
                            onExportCsv: _exportReportCsv,
                            isExporting: _sessionManager.isExporting,
                            schedule: _sessionManager.currentSchedule,
                            availableClasses: _sessionManager.availableClasses,
                            records: _sessionManager.records,
                            historyLogs: _sessionManager.historyLogs,
                            onClassChanged: _sessionManager.selectClass,
                            currentSlot: _sessionManager.currentSlot,
                            currentDate: _sessionManager.currentDate,
                          ),
                          // 4: AI Insights
                          AiInsightsView(
                            students: _sessionManager.students,
                            records: _sessionManager.records,
                            currentClass: _sessionManager.currentClass,
                            historyLogs: _sessionManager.historyLogs,
                            analyticsStatus: _sessionManager.analyticsStatus,
                            analyticsError: _sessionManager.analyticsError,
                            isLoadingAnalytics: _sessionManager.isLoadingAnalytics,
                            onRetryLoadAnalytics: () => _sessionManager.loadAnalyticsLogs(),
                            onConfigureByok: () => setState(() => _selectedIndex = 6),
                            schedule: _sessionManager.currentSchedule,
                          ),
                          // 5: FAP Sync & Import Center
                          FapSyncView(
                            students: _sessionManager.students,
                            records: _sessionManager.records,
                            currentClass: _sessionManager.currentClass,
                            currentSlot: _sessionManager.currentSlot,
                            onImportStudents: _sessionManager.importStudents,
                            onSaveToSheet: _saveToGoogleSheet,
                          ),
                          // 6: Settings
                          SettingsView(
                            initialSheetUrl: _sessionManager.sheetUrl,
                            onSaveSheetUrl: _sessionManager.setSheetUrl,
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
      },
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
                _buildConnectionRow(
                  'Google Sheets',
                  _sessionManager.isSheetConnected ? 'Connected' : 'Not configured',
                  _sessionManager.isSheetConnected,
                ),
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
            label: _sessionManager.isSheetConnected ? 'Sheets: Connected' : 'Sheets: Unlinked',
            isConnected: _sessionManager.isSheetConnected,
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
          if (_sessionManager.sheetUrl.isNotEmpty) ...[
            const SizedBox(width: 8),
            BirdleSecondaryButton(
              icon: Icons.table_chart_outlined,
              label: 'Sheet',
              height: 32,
              iconColor: BirdleColors.brand,
              onPressed: () => StorageService.openBrowser(_sessionManager.sheetUrl),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: BirdleColors.textSecondary),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _reloadFromSheet,
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
