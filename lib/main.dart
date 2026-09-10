import 'package:flutter/material.dart';
import 'screens/main_desktop_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FapAttendanceDesktopApp());
}

class FapAttendanceDesktopApp extends StatelessWidget {
  const FapAttendanceDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAP Attendance Assistant - PRM Lab 1 Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF36F21), // FPT Orange
          primary: const Color(0xFFF36F21),
          secondary: const Color(0xFF1E293B),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
        ),
      ),
      home: const MainDesktopScreen(),
    );
  }
}
