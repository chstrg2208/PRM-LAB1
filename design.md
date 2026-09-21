Birdle — UI/UX Design Specification

Design reference for the Birdle Flutter Desktop attendance application.

Product goal: Desktop attendance connected to FAP + Google Sheets as DB + BYOK AI.

1. Product Overview

Birdle is a Flutter Desktop application designed for FPT University attendance management.

Core workflow:

FAP
  ↓
FAP Integration / Import
  ↓
Birdle Desktop
  ↓
Review & Validate Attendance
  ↓
Google Sheets
  ↓
Reports & Analytics
  ↓
AI Insights (BYOK)

Birdle is an attendance workspace, not a generic school administration system.

The UI should prioritize:

Fast attendance management

FAP integration

File import/export

Google Sheets synchronization

Clear attendance reporting

AI-assisted analytics

Desktop productivity

2. Design Principles

2.1 Desktop First

Birdle is primarily a Windows Flutter Desktop application.

Design around a desktop workspace instead of a mobile/tablet layout.

Primary target:

1440 × 900

Minimum practical width: ~1100px

Persistent sidebar

Wide data tables

Keyboard-friendly interactions

Multi-panel layouts where useful

Do not design the application as a mobile app stretched onto desktop.

2.2 Professional Productivity Tool

The visual language should feel closer to:

Linear

Notion

Raycast

Modern developer tools

Modern education SaaS

Do not directly copy these products.

Birdle should feel:

Clean

Calm

Precise

Reliable

Academic

Professional

Data-focused

Avoid the typical "admin dashboard template" appearance.

2.3 AI Is a Supporting Layer

AI should not visually dominate the product.

Birdle's source of truth is attendance data.

Deterministic application logic calculates:

Total students

Present

Absent

Late

Pending

Attendance percentage

Attendance trends

Warning conditions

AI can:

Summarize attendance

Explain patterns

Highlight unusual trends

Answer questions about attendance data

Provide recommendations based on existing data

AI must never invent attendance numbers.

3. Visual Direction

3.1 Overall Style

Use:

Light theme

Warm neutral background

White surfaces

Charcoal text

Emerald/teal accent

Thin borders

Subtle shadows

Moderate corner radius

Strong typography hierarchy

Compact data presentation

Avoid:

Excessive gradients

Purple AI gradients

Glassmorphism

Neon colors

Excessive shadows

Giant rounded cards

Excessive empty space

Decorative illustrations everywhere

Excessive emoji usage

Generic "AI dashboard" aesthetics

4. Color System

Use a restrained color palette.

Background

App Background:       #F7F8FA
Surface:              #FFFFFF
Surface Secondary:    #F2F4F7
Hover:                #F5F7F9

Text

Primary:              #17191C
Secondary:            #5F6670
Muted:                #8B929C
Disabled:             #B5BAC1

Border

Default Border:       #E5E7EB
Strong Border:        #D9DDE3

Brand

Primary Birdle accent:

Emerald:              #16A67A
Emerald Dark:         #10845F
Emerald Light:        #E8F7F1

Use the brand color selectively for:

Primary actions

Active navigation

Connected states

Present status

Important highlights

Do not color everything green.

Semantic Colors

Success:

#16A67A

Warning:

#D99100

Danger:

#D94A4A

Info:

#4F7CAC

Semantic colors should primarily appear in:

Status badges

Icons

Small indicators

Alerts

Charts

5. Typography

Preferred font:

Inter

Alternative:

Geist

Hierarchy:

Page Title       26–30px / Semibold
Section Title    18–20px / Semibold
Card Title       15–16px / Semibold
Body             14px / Regular
Metadata         12–13px / Regular
Caption          11–12px / Regular

Use typography hierarchy instead of excessive containers.

Avoid very large marketing-style headings.

6. Spacing System

Use an 8px-based spacing system.

4px   Micro
8px   Small
12px  Compact
16px  Default
24px  Section
32px  Large
40px  Major
48px  Page

Desktop content should generally use:

Page horizontal padding: 28–32px
Section gap:             24–32px
Card internal padding:   16–20px
Table row height:        48–56px

7. Border Radius

Use moderate rounding.

Small controls:     8px
Inputs:             8px
Buttons:            8px
Cards:              12px
Large containers:   14–16px

Do not make every element pill-shaped.

Pills should be reserved for:

Status

Tags

Filters

Small indicators

8. Shadows

Use shadows sparingly.

Preferred:

0 1px 2px rgba(...)

or a very subtle elevation.

Most containers should rely on:

background + border

rather than heavy shadows.

9. Application Shell

9.1 Sidebar

Width:

220–240px

Structure:

BIRDLE
Attendance Workspace

────────────────

OVERVIEW

Dashboard

ATTENDANCE

Attendance
Students
Reports

INTELLIGENCE

AI Insights

INTEGRATION

FAP Sync

SYSTEM

Settings

────────────────

● Google Sheets
  Connected

● FAP
  Connected

Sidebar requirements:

Persistent

Compact

Clean

Clear active state

Monochrome line icons

Small section labels

Connection status at bottom

Active item:

Tinted background
+
Brand-colored icon
+
Brand-colored text

Avoid huge active navigation blocks.

10. Top Header

Header height:

60–68px

Left:

Page title
Optional breadcrumb

Right:

Search
FAP status
Google Sheets status
Notifications
Profile

Example:

Attendance

                         Search...
                         ● FAP
                         ● Sheets
                         Bell
                         Profile

Keep the header visually quiet.

11. Dashboard

Purpose

The dashboard should answer:

"What do I need to do today?"

It should not become a wall of KPI cards.

Layout

Header

Good morning

Attendance workspace
Saturday, September 20, 2026

Primary action:

[ Open Today's Attendance ]

Secondary:

[ Import from FAP ]

Today's Attendance

Example:

PRM393 · Slot 3

32 Students

28 Present
3 Absent
1 Pending

Attendance Rate
87.5%

Use one strong summary block.

Recent Activity

Examples:

Imported attendance from FAP
Today · 09:42

Attendance synced to Google Sheets
Today · 09:47

AI analysis generated
Today · 09:49

Attendance Trend

Simple line chart.

Do not overuse charts.

Students Requiring Attention

Compact table/list:

Student ID
Student
Attendance Rate
Status

12. Attendance Screen

This is the primary screen.

Header

Attendance

PRM393 · Slot 3
September 20, 2026

Actions:

[ Import from FAP ]
[ Import File ]
[ Save Attendance ]

Summary

32 Students
28 Present
3 Absent
1 Pending

Toolbar

Search students

Status ▼
Attendance ▼
Sort ▼

Table

Columns:

#
Student ID
Student
Status
Last Activity
Attendance Rate
Actions

Status:

● Present
● Absent
◐ Pending
⚠ Late

The table should be the dominant component.

Do not convert each student into a large card.

13. Students

Header

Students

32 students

Actions:

[ Import ]
[ Export ]

Search:

Search student...

Table:

Student ID
Student Name
Attendance Rate
Present
Absent
Last Attendance
Status

Student Detail

Show:

Student Name
Student ID

Attendance Rate

Attendance Statistics

Attendance History

Recent Sessions

AI Insight

AI insight should be compact and contextual.

14. Reports

Title:

Attendance Reports

Filters:

Class
Semester
Date Range

Primary content:

Attendance Rate

Visualizations:

Attendance trend

Weekly attendance

Absence distribution

Students requiring attention

Actions:

[ Export CSV ]
[ Export Report ]

Reports should remain operational and understandable.

Avoid turning this into a complicated BI platform.

15. Import Center

File handling is an important part of the LAB requirement.

Main Screen

Import Center

Bring attendance data into Birdle.

Large drop zone:

Drop files here

or

[ Choose File ]

CSV
XLSX
JSON

Separate FAP action:

Import from FAP
Retrieve attendance data directly from FAP.

Import Pipeline

Visualize:

1. Select
   ↓
2. Parse
   ↓
3. Preview
   ↓
4. Validate
   ↓
5. Import
   ↓
6. Sync

Do not hide the workflow behind a single loading spinner.

16. Import Preview

After selecting a file:

Import Preview

32 students detected
30 valid records
2 records require attention

Table:

Student
Status
Validation

Example:

Nguyen Van A     ✓ Valid
Tran Van B      ✓ Valid
Le Van C        ⚠ Missing student ID

Actions:

[ Cancel ]
[ Import Records ]

After success:

Successfully imported 30 records.

[ Sync to Google Sheets ]

17. FAP Sync

Title:

FAP Integration

Connection panel:

● Connected

Last synchronization
Today · 09:42

Current class
PRM393

32 students

Primary action:

[ Sync from FAP ]

Sync Progress

Use a timeline:

✓ Connecting to FAP

✓ Reading class

● Reading attendance

○ Validating records

○ Preparing import

Do not use only a spinner.

Sync History

Table:

Time
Class
Records
Result

Example:

09:42
PRM393
32
✓ Successful

18. AI Insights

AI should feel like an analytics layer.

Title:

AI Insights

Understand attendance patterns using your data.

Attendance Health

Example:

91.4%

Stable

Key Observations

Examples:

Attendance improved by 3.1%
compared with the previous period.

4 students are approaching
the attendance warning threshold.

Monday morning sessions show
higher absence frequency.

These values must come from actual application data.

Students Requiring Attention

Compact list.

Ask About Your Data

Input:

Ask about this attendance data...

Suggested questions:

Which students have the highest absence rate?

What attendance trend changed this month?

Summarize the current attendance situation.

AI UI should remain restrained.

No giant chatbot interface.

No AI avatar.

No excessive sparkles.

19. BYOK Settings

Title:

AI Provider

Fields:

Provider
Gemini

API Key
••••••••••••••••

[ Test Connection ]

Status:

● Connected

Supporting text:

Your API key is provided by you.

Birdle does not use a shared developer API key.

No key:

AI Insights unavailable

Add your own API key to enable
AI-powered attendance analysis.

[ Configure BYOK ]

The UI should communicate trust and transparency.

Never expose API keys.

20. Settings

Organize settings into sections.

General

Appearance

Language

Notifications

Data

Google Sheets

Import / Export

Synchronization

AI

Provider

BYOK API Key

Connection

Google Sheets section:

● Connected

Spreadsheet:
Birdle Attendance 2026

Last sync:
2 minutes ago

[ Test Connection ]

[ Sync Now ]

21. Component System

Create reusable components.

Buttons

Types:

Primary
Secondary
Ghost
Destructive

Primary should be visually strongest.

Do not use multiple primary buttons competing in one area.

Inputs

States:

Default
Focus
Filled
Error
Disabled

Use clear labels.

Do not rely only on placeholder text.

Status Badge

Examples:

Present
Absent
Late
Pending

Connected
Disconnected
Syncing
Error

Use small badges.

Cards

Cards should group meaningful information.

Good:

Today's Attendance

Bad:

One card for every tiny statistic

Tables

Tables should support:

Search

Sort

Filter

Selection where necessary

Clear row states

Comfortable density

Use subtle row separators.

Toasts

Success:

Attendance saved successfully.

Error:

Unable to sync with Google Sheets.

Warning:

2 records require review.

22. Empty States

Every major screen needs a useful empty state.

Example:

No attendance records yet.

Import attendance from FAP
or choose a file to get started.

[ Import from FAP ]
[ Import File ]

Avoid decorative empty-state illustrations unless they genuinely improve usability.

23. Loading States

Prefer skeletons for major content.

For synchronization:

Connecting...
Reading...
Validating...
Saving...

For AI:

Analyzing attendance data...

Do not show indefinite spinners without context.

24. Error States

Errors should explain:

What happened

Why it may have happened

What the user can do

Example:

Unable to connect to Google Sheets.

Check your connection and try again.

[ Retry ]

25. Responsive Behavior

Primary target is desktop.

At smaller desktop widths:

Sidebar may become narrower

Tables may reduce secondary columns

Panels may collapse

Content should remain usable

Do not prioritize mobile UI.

26. Motion

Motion should be subtle.

Use:

150–200ms transitions

Hover feedback

Button press feedback

Sidebar transitions

Modal transitions

Table state transitions

Sync progress animation

Avoid:

Large page animations

Excessive bouncing

Decorative motion

Long transitions

Motion should communicate state, not decoration.

27. Accessibility

Ensure:

Strong text contrast

Clear focus states

Keyboard navigation

Tooltips for icon-only actions

Status is not communicated by color alone

Buttons have clear labels

Tables remain readable

28. Core User Journey

The main demo journey should be:

1. Open Birdle

2. See Dashboard

3. Open Attendance

4. Import from FAP

5. Review attendance records

6. Validate / edit records

7. Save attendance

8. Sync to Google Sheets

9. Open Reports

10. Open AI Insights

11. Ask AI about attendance patterns

Secondary journey:

Import File
↓
Preview
↓
Validate
↓
Import
↓
Sync Google Sheets

29. Visual Priority

The product should visually prioritize:

Attendance
████████████████████

FAP / File Import
████████████

Google Sheets
████████

Reports
██████

AI Insights
████

AI should enhance the application rather than become the application.

30. What NOT to Change

The UI redesign must not change the core architecture.

Do not replace:

Google Sheets

Google Apps Script

FAP integration

BYOK model

Do not introduce:

Firebase

Supabase

PostgreSQL

MySQL

MongoDB

BLoC

Riverpod

GetIt

CQRS

Microservices

Unnecessary repository abstractions

unless explicitly requested.

The design layer must work with the existing lightweight architecture.

31. UI Implementation Philosophy

When implementing this design:

Reuse existing functionality.
Preserve existing data flows.
Preserve FAP integration.
Preserve Google Sheets integration.
Preserve BYOK.
Avoid unnecessary rewrites.

For UI changes:

Design System
    ↓
App Shell
    ↓
Dashboard
    ↓
Attendance
    ↓
Import / FAP
    ↓
Students
    ↓
Reports
    ↓
AI Insights
    ↓
Settings

Build reusable UI components instead of duplicating styles.

32. Final Product Identity

Birdle should ultimately look like:

A polished desktop attendance workspace for university staff and teaching assistants.

It should communicate:

FAP Integration
        +
Attendance Management
        +
File Handling
        +
Google Sheets
        +
AI Analytics

The final UI should be:

Clean + Professional + Desktop-first + Data-focused + Human + Reliable

Not:

Generic Admin Dashboard + AI Chatbot + Decorative Cards

33. Design Success Criteria

The UI is successful when a user can immediately understand:

What is this?

A desktop attendance management tool.

Where does data come from?

FAP or imported files.

Where is data stored?

Google Sheets.

What can I do?

Review, edit, save, sync, report, analyze.

What does AI do?

Analyze attendance data using the user's own API key.

What is the primary action?

Manage today's attendance.

34. Stitch Design Instruction

When generating screens in Google Stitch, maintain this design system across every screen.

Do not redesign the navigation, typography, colors, spacing, button styles, table styles, or status badges independently for each screen.

The application must feel like one coherent desktop product.

Start with:

App Shell

Dashboard

Attendance

Import Center

FAP Sync

Students

Reports

AI Insights

Settings

Use the same design language throughout.