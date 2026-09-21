import 'package:flutter/material.dart';

class BirdleColors {
  // Background
  static const Color appBackground = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF2F4F7);
  static const Color hover = Color(0xFFF5F7F9);

  // Text
  static const Color textPrimary = Color(0xFF17191C);
  static const Color textSecondary = Color(0xFF5F6670);
  static const Color textMuted = Color(0xFF8B929C);
  static const Color textDisabled = Color(0xFFB5BAC1);

  // Border
  static const Color border = Color(0xFFE5E7EB);
  static const Color strongBorder = Color(0xFFD9DDE3);

  // Brand (Emerald Accent)
  static const Color brand = Color(0xFF16A67A);
  static const Color brandDark = Color(0xFF10845F);
  static const Color brandLight = Color(0xFFE8F7F1);

  // Semantic
  static const Color success = Color(0xFF16A67A);
  static const Color successLight = Color(0xFFE8F7F1);

  static const Color warning = Color(0xFFD99100);
  static const Color warningLight = Color(0xFFFEF7E6);

  static const Color danger = Color(0xFFD94A4A);
  static const Color dangerLight = Color(0xFFFDF2F2);

  static const Color info = Color(0xFF4F7CAC);
  static const Color infoLight = Color(0xFFEFF4F9);

  static const Color pending = Color(0xFF8B929C);
  static const Color pendingLight = Color(0xFFF2F4F7);
}

class BirdleRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double pill = 999.0;

  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

class BirdleTypography {
  static const String fontFamily = 'Segoe UI';

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: BirdleColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: BirdleColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: BirdleColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: BirdleColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: BirdleColors.textPrimary,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: BirdleColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: BirdleColors.textMuted,
    letterSpacing: 0.2,
  );
}

class BirdleTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: BirdleTypography.fontFamily,
      scaffoldBackgroundColor: BirdleColors.appBackground,
      colorScheme: const ColorScheme.light(
        primary: BirdleColors.brand,
        onPrimary: Colors.white,
        surface: BirdleColors.surface,
        onSurface: BirdleColors.textPrimary,
        outline: BirdleColors.border,
      ),
      dividerTheme: const DividerThemeData(
        color: BirdleColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: BirdleColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BirdleRadius.mdBorder,
          side: const BorderSide(color: BirdleColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BirdleColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        hintStyle: const TextStyle(color: BirdleColors.textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: BirdleColors.textSecondary, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BirdleRadius.smBorder,
          borderSide: const BorderSide(color: BirdleColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BirdleRadius.smBorder,
          borderSide: const BorderSide(color: BirdleColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BirdleRadius.smBorder,
          borderSide: const BorderSide(color: BirdleColors.danger, width: 1),
        ),
      ),
    );
  }
}
