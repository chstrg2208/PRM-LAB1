# AGENTS.md

# PRM-LAB1 — Birdle Attendance Workspace

## 1. Project Overview
Birdle is a dedicated attendance management workspace designed for FPT University lecturers and academic staff (serving PRM393 Lab 1). It bridges the gap between FPT's training portal (FAP) and Google Sheets, providing fast attendance taking, dynamic QR code check-ins, automated attendance rule enforcement (attendance warning & exam disqualification / cấm thi thresholds), report exports, and BYOK AI-powered attendance insights.

---

## 2. Project Mission
> **"Desktop attendance management connected to FAP, using Google Sheets as the database, with BYOK AI support."**

The project must strictly remain focused on this mission. Desktop productivity and lecturer workflows remain the top priority.

---

## 3. Tech Stack
* **Desktop Platform:** Flutter 3.x (Dart SDK `^3.13.2`) targeting Windows Desktop.
* **Database & Serverless API:** Google Sheets via Google Apps Script (JavaScript REST API).
* **Integration Layer:** Google Chrome Extension (Manifest V3, HTML/CSS/JS).
* **AI Provider:** Google Gemini API (`gemini-2.0-flash`, `gemini-1.5-flash`) via BYOK.
* **Core Dependencies:**
  * `http: ^1.2.1` — Network requests to Google Apps Script and Gemini APIs.
  * `intl: ^0.19.0` — Date/time parsing and formatting.
  * `qr_flutter: ^4.1.0` — Rendering dynamic QR codes.

---

## 4. Architecture
* **Simple Layered Architecture (University LAB standard):**
  $$\text{Models} \longrightarrow \text{Services / State} \longrightarrow \text{Screens / Widgets} \longrightarrow \text{External APIs}$$
* **State Management:** Lightweight `ChangeNotifier` pattern via [`AttendanceSessionManager`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/state/attendance_session_manager.dart).
* **Primary Data Flow:**
  1. **Attendance Collection:**
     $$\text{FAP} \xrightarrow{\text{Extension / Parser}} \text{Flutter Desktop} \xrightarrow{\text{GAS REST API}} \text{Google Sheets}$$
  2. **Attendance Inspection & Reports:**
     $$\text{Google Sheets} \xrightarrow{\text{GAS REST API}} \text{Flutter Desktop} \longrightarrow \text{Reports / Dashboard}$$
  3. **AI Analytics:**
     $$\text{Google Sheets} \longrightarrow \text{Flutter Desktop} \xrightarrow{\text{Deterministic Calculations}} \text{AI Insights (BYOK)}$$

---

## 5. Project Structure
* [`lib/models/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models): Data structures:
  * [`Student`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/student.dart) — Student info, slots20 history, attendance % and warning logic.
  * [`AttendanceRecord`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/attendance_record.dart) — Individual attendance item (`AttendanceStatus`: Present, Absent, Not Yet) and notes.
  * [`ClassSession`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/class_session.dart) — Slot definitions (Slots 1–6) and session schedule metadata.
  * [`ClassOverviewItem`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/class_overview_item.dart) — Overview item for class hubs (`AttendanceOverview`).
  * [`QrAttendanceSession`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/qr_attendance_session.dart) — Realtime QR token session with 30s expiration.
* [`lib/services/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services): Network & platform services:
  * [`GoogleSheetService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/google_sheet_service.dart) — REST calls to Google Apps Script.
  * [`FapService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/fap_service.dart) — FAP HTML/text scraping and auto-fill script generation.
  * [`AiAnalyticsService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/ai_analytics_service.dart) — Deterministic statistical analysis and Gemini BYOK client.
  * [`CsvExportService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/csv_export_service.dart) — Desktop CSV export with delimiter selection.
  * [`StorageService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/storage_service.dart) — Local persistence for URLs, settings, and BYOK keys.
* [`lib/state/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/state):
  * [`AttendanceSessionManager`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/state/attendance_session_manager.dart) — Centralized state and event controller.
* [`lib/screens/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens):
  * [`MainDesktopScreen`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/main_desktop_screen.dart) — Root layout with persistent desktop sidebar.
  * [`AttendanceOverviewView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/attendance_overview_view.dart) — Attendance Hub showing today's vs other classes.
  * [`AttendanceView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/attendance_view.dart) — Student attendance table, slot/date pickers, QR triggers.
  * [`ReportsView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/reports_view.dart) — Attendance matrix, absence stats, CSV export.
  * [`AiInsightsView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/ai_insights_view.dart) — Analytical dashboard and BYOK conversational interface.
  * [`FapSyncView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/fap_sync_view.dart) — FAP HTML importer & bridge script generator.
  * [`SettingsView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/screens/settings_view.dart) — Database URL configuration & BYOK key management.
* [`lib/widgets/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/widgets): Reusable desktop components ([`StatusBadge`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/widgets/status_badge.dart), [`AttendanceMatrixView`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/widgets/attendance_matrix_view.dart), [`QrAttendanceDialog`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/widgets/qr_attendance_dialog.dart), [`ReportSummaryPreviewDialog`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/widgets/report_preview_dialog.dart)).
* [`google-apps-script/Code.gs`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/google-apps-script/Code.gs): Backend script running on Google Sheets.
* [`fap-attendance-extension/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/fap-attendance-extension): Supporting Chrome extension.
* [`test/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/test): Unit, widget, and regression test suites.

---

## 6. Core Features
1. **Attendance Hub & Session Management:** Class filtering (today vs other), Slot (1–6), Session (1–20), and date management.
2. **Tri-State Attendance & Note Taking:** Present, Absent, and Not Yet states, bulk marking actions, and debounced auto-saving notes.
3. **Dynamic QR Code Attendance:** 30-second token rotation, web check-in form for students, realtime polling, and session lock/reopen.
4. **Date Lock Policy:** Warning and locking controls preventing unauthorized back-dated or premature attendance changes.
5. **FPT Attendance Rule Engine:** Deterministic calculation of absence rates, early intervention warning (15%–20%), and exam disqualification ($\ge$20% / cấm thi).
6. **20-Slot Attendance Matrix & CSV Export:** Full semester overview with preview dialog and customizable delimiters.
7. **BYOK AI Analytics:** Automatic identification of worst attendance slots and weekdays, coupled with conversational analysis via Google Gemini.
8. **FAP Sync & Auto-Fill Bridge:** Extraction of student roster from FAP and one-click JavaScript generation for auto-marking in FAP.
9. **Offline Mode:** Local cache fallback ensuring full offline demonstration and resilience against network drops.

---

## 7. Coding Rules
* Write clean, idiomatic Dart adhering to Effective Dart and `flutter_lints`.
* Always use design tokens from [`BirdleColors`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/theme/app_theme.dart), [`BirdleSpacing`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/theme/app_theme.dart), and [`BirdleTypography`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/theme/app_theme.dart). Never hardcode ad-hoc colors or padding.
* Functions and methods must be focused, single-purpose, and small.
* Preserve all existing comments, docstrings, and tests when making changes.

---

## 8. Architecture Rules
* **No Unnecessary Enterprise Over-Engineering:** Do NOT introduce BLoC, Riverpod, Provider, GetIt, CQRS, event sourcing, or microservices.
* **Deterministic Single Source of Truth:** Application logic calculates all statistics (attendance %, total sessions, warnings). AI is strictly an interpretive advisory layer and MUST NEVER invent numbers.
* Respect layer separation: UI (`screens/`, `widgets/`) $\rightarrow$ State ([`AttendanceSessionManager`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/state/attendance_session_manager.dart)) $\rightarrow$ Data/Services (`services/`).

---

## 9. Naming Conventions
* **Files & Directories:** `snake_case` (e.g. `attendance_session_manager.dart`, `class_session.dart`).
* **Classes, Enums, Typedefs:** `PascalCase` (e.g. [`Student`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/student.dart), [`AttendanceRecord`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/models/attendance_record.dart), [`GoogleSheetException`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/google_sheet_service.dart#L18)).
* **Functions & Variables:** `camelCase` (e.g. `saveAttendance`, `worstSlot`, `absentCount`).
* **Constants:** `camelCase` for const values; `screaming_snake_case` only for system/environment constants.

---

## 10. UI/UX Guidelines
* **Desktop-First UX:** Tailored for 1440x900 (min 1100px); not a stretched mobile app.
* **Persistent Sidebar:** Unobtrusive navigation with clear section headers (`ATTENDANCE`, `INTELLIGENCE`, `INTEGRATION`, `SYSTEM`).
* **FPT Visual Identity:** Primary brand color `#F36F21` (FPT Orange), surface `#0F172A` (Navy/Slate), and warm neutral background `#F8FAFC`.
* **State Feedback:** Provide skeleton loaders, empty state placeholders, and actionable error banners with retry buttons.

---

## 11. Data & Database Rules
* **Google Sheets is the primary database.**
* DO NOT replace Google Sheets with Firebase, Supabase, Postgres, MySQL, MongoDB, or SQLite.
* Local storage ([`StorageService`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/storage_service.dart)) is strictly for configuration, cache, and BYOK credentials.
* Google Sheets structure must support 4-row metadata blocks and dynamic column mapping (MEMBER, CODE, SURNAME, MIDDLE NAME, GIVEN NAME, ROLLNUMBER).

---

## 12. API / Integration Rules
* Google Apps Script communicates via REST HTTP GET / POST with standard JSON response wrapping.
* Network calls must have timeouts (10–15s) and catch network/socket exceptions gracefully via [`_parseApiResponse`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/google_sheet_service.dart#L40).
* FAP integration remains a first-class feature; manual input is only a fallback.

---

## 13. Security Rules
* **BYOK (Bring Your Own Key):** Users supply their own Gemini API key; no developer-shared keys.
* **Zero Secret Commitment:** Never commit API keys, tokens, or credentials into Git.
* Chrome Extension permissions must remain minimal (`activeTab`, `storage`, `sidePanel`).

---

## 14. Error Handling & Logging
* Use typed domain exceptions: [`GoogleSheetException`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/google_sheet_service.dart#L18) with [`GoogleSheetErrorType`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/services/google_sheet_service.dart#L9).
* Present human-readable messages in SnackBars or dialogs; avoid exposing raw stack traces in the UI.
* Fail gracefully to local cache or offline mode when remote services are unreachable.

---

## 15. Testing
* Business logic and critical UI flows must have automated tests using `package:flutter_test`.
* Use the [`AttendanceApiClient`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/lib/state/attendance_session_manager.dart#L38) abstraction for deterministic dependency injection in tests without hitting real network endpoints.
* Maintain 100% passing tests (all 182 tests currently passing).

---

## 16. Git & Commit Rules
* Follow Conventional Commits format (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
* Keep commits atomic and focused. Do not mix unrelated refactors with feature work.
* Verify `.gitignore` excludes `build/`, `.dart_tool/`, and temporary local files.

---

## 17. Development Workflow
1. Read `AGENTS.md` and check current implementation.
2. Trace affected data flows.
3. Make the smallest safe change that solves the requirement.
4. Run `flutter analyze` and `flutter test` before completing any task.

---

## 18. Build / Run / Deploy
* **Run Desktop:**
  ```powershell
  flutter run -d windows
  ```
* **Static Analysis:**
  ```powershell
  flutter analyze
  ```
* **Run Tests:**
  ```powershell
  flutter test
  ```
* **Deploy Backend:** Copy [`google-apps-script/Code.gs`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/google-apps-script/Code.gs) into Apps Script on Google Sheet $\rightarrow$ Deploy as Web App (Execute as: Me, Access: Anyone).
* **Install Extension:** In Chrome, visit `chrome://extensions` $\rightarrow$ Enable Developer Mode $\rightarrow$ "Load unpacked" $\rightarrow$ Select [`fap-attendance-extension/`](file:///d:/KI%208/PRM393/Lab%201/PRM-LAB1/fap-attendance-extension).

---

## 19. Do / Don't
* **DO:**
  * Prioritize Windows Desktop workflows and productivity.
  * Maintain Google Sheets as the single source of truth database.
  * Strictly preserve BYOK for AI services.
  * Run and pass all automated tests before concluding work.
* **DON'T:**
  * Do NOT turn this into a web-only or mobile-first application.
  * Do NOT replace Google Sheets with other databases.
  * Do NOT hardcode API keys or secrets anywhere.
  * Do NOT introduce heavyweight state management libraries (BLoC, Riverpod, etc.).

---

## 20. Definition of Done
A feature or task is considered DONE only when:
1. It fulfills the specific PRM393 Lab 1 requirement.
2. The core attendance workflow (FAP $\rightarrow$ Desktop $\rightarrow$ Google Sheets) remains fully functional.
3. Google Sheets remains the primary database and BYOK is preserved.
4. No secrets or credentials are committed.
5. No unrelated architectural changes are introduced.
6. `flutter analyze` passes with 0 issues / 0 warnings.
7. All `flutter test` suites pass cleanly (182+ tests).
