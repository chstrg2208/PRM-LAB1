# AGENTS.md

# PRM-LAB1

## Project Mission

Birdle is a **Flutter Desktop attendance management application** for FPT University.

The primary purpose of this project is:

> **Desktop attendance management connected to FAP, using Google Sheets as the database, with BYOK AI support.**

The project must remain focused on this requirement.

---

# 1. Non-Negotiable Requirements

The following requirements are mandatory.

## 1.1 Flutter Desktop

The primary application is:

```text
Flutter Desktop
Windows
```

Do not change the project into a web-first, mobile-first, or browser-only application.

Desktop UX and desktop workflows must remain the priority.

---

## 1.2 FAP Integration

FAP is the primary external source for attendance/student information.

The intended flow is:

```text
FAP
 ↓
FAP Parser / Chrome Extension
 ↓
Flutter Desktop
 ↓
Attendance Management
 ↓
Google Sheets
```

FAP integration must remain a first-class feature.

Do not remove FAP integration or replace it with manually entered data as the primary workflow.

---

## 1.3 Google Sheets as Database

Google Sheets is the project's primary database.

Architecture:

```text
Flutter Desktop
       ↓
Google Apps Script API
       ↓
Google Sheets
```

Google Apps Script acts as the backend/API layer.

Do NOT replace Google Sheets with:

* Firebase
* Supabase
* PostgreSQL
* MySQL
* MongoDB
* SQL Server
* another external database

unless explicitly requested.

Local storage may be used for:

* application settings
* cached data
* user preferences
* temporary offline information

but it must not replace Google Sheets as the primary database.

---

# 2. BYOK Requirement

AI functionality follows:

> **BYOK — Bring Your Own Key**

The application must allow the user to provide their own AI provider API key.

The application must NOT use a developer-owned shared API key.

Never:

* hard-code API keys
* commit API keys
* expose API keys in Git
* put API keys directly in source code
* use a shared secret for all users

The user's API key should be treated as a secret.

---

# 3. AI Responsibility

AI is an assistance/analytics layer.

AI is NOT the source of truth for attendance data.

Deterministic application logic must calculate:

* total sessions
* attended sessions
* absent sessions
* attendance percentage
* attendance status
* warning thresholds

AI may:

* summarize attendance
* identify patterns
* generate insights
* explain trends
* provide recommendations based on calculated data

Example:

```text
Application calculation:

Attended = 8
Total = 10
Attendance = 80%

        ↓

AI:

"Attendance is currently 80%. The student has
missed two sessions."
```

The AI must not invent the numerical values.

---

# 4. System Boundaries

The system consists of three main components.

## Flutter Desktop

```text
lib/
```

Responsible for:

* UI
* attendance management
* student management
* reports
* settings
* AI insights
* communication with backend/API

````

## Google Apps Script

```text
google-apps-script/
````

Responsible for:

* Google Sheets API logic
* reading/writing data
* attendance persistence
* student persistence
* analytics data retrieval

````

## Chrome Extension

```text
fap-attendance-extension/
````

Responsible for:

* interacting with FAP
* extracting relevant FAP information
* assisting attendance synchronization
* providing FAP integration functionality

The Chrome Extension is a supporting integration component.

The Flutter Desktop application remains the primary product.

---

# 5. Primary Data Flow

The expected attendance flow is:

```text
FAP
 │
 │ attendance/student data
 ▼
Chrome Extension / FAP Parser
 │
 ▼
Flutter Desktop
 │
 │ user review / management
 ▼
Google Apps Script
 │
 ▼
Google Sheets
```

Reading existing data:

```text
Google Sheets
      ↓
Google Apps Script
      ↓
Flutter Desktop
      ↓
Dashboard / Attendance / Reports / AI
```

AI analytics:

```text
Google Sheets
      ↓
Flutter
      ↓
Deterministic calculations
      ↓
AI Analytics
      ↓
AI Insights UI
```

---

# 6. Architecture Philosophy

This is a university LAB project.

Keep the architecture:

* simple
* understandable
* maintainable
* easy to demonstrate
* easy to explain during presentation

Do not introduce unnecessary enterprise architecture.

Do not add:

* BLoC
* Riverpod
* Provider
* GetIt
* CQRS
* event sourcing
* microservices
* repository abstraction everywhere
* unnecessary dependency injection frameworks

unless explicitly requested.

Prefer the existing lightweight architecture:

```text
Models
   ↓
Services
   ↓
Screens / Widgets
   ↓
External APIs
```

---

# 7. Change Policy

Before modifying code:

1. Read `AGENTS.md`.
2. Inspect existing implementation.
3. Trace the affected data flow.
4. Search for existing functionality.
5. Reuse existing code where possible.
6. Make the smallest change that solves the task.

Never rewrite the entire project for a small feature.

Never change the database architecture without explicit approval.

Never change FAP integration behavior without checking existing parsing logic.

Never replace Google Sheets with another database.

Never remove BYOK.

---

# 8. Refactoring Policy

Refactoring is allowed, but behavior must remain unchanged unless explicitly requested.

When refactoring:

```text
Before:
Understand existing flow

During:
Move / extract / organize

After:
Run analyzer
Run tests
Verify affected flow
```

Do not combine:

```text
architecture rewrite
+
feature development
+
UI redesign
```

in one uncontrolled change.

---

# 9. UI Policy

The existing UI should be preserved unless the task explicitly requests UI changes.

Do not redesign the application while fixing:

* services
* API integration
* FAP parsing
* Google Sheets
* AI logic
* models

When UI changes are requested, preserve the application's existing visual language unless a redesign is explicitly requested.

---

# 10. Security

Never commit:

```text
API keys
Gemini keys
OAuth secrets
passwords
tokens
service-account credentials
```

Use BYOK for AI credentials.

Minimize Chrome Extension permissions.

Do not add broad permissions without a concrete requirement.

---

# 11. Definition of Done

A feature is complete when:

* it satisfies the requested LAB requirement
* existing attendance flow still works
* FAP integration still works
* Google Sheets remains the primary database
* BYOK remains respected
* no secrets are committed
* no unrelated architecture changes were introduced
* relevant tests pass
* `flutter analyze` passes or existing issues are documented

---

# 12. Golden Rule

When uncertain:

> **Preserve the existing FAP → Flutter Desktop → Google Sheets workflow and make the smallest safe change.**

Do not optimize for architectural complexity.

Optimize for:

```text
Correctness
+
Reliability
+
Demoability
+
Maintainability
```
