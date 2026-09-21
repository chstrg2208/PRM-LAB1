import 'package:flutter/material.dart';
import 'screens/main_desktop_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FapAttendanceDesktopApp());
}

class FapAttendanceDesktopApp extends StatelessWidget {
  const FapAttendanceDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle — Attendance Workspace',
      debugShowCheckedModeBanner: false,
      theme: BirdleTheme.lightTheme,
      home: const MainDesktopScreen(),
    );
  }
}
