import 'package:flutter/material.dart';

/// 主题 token。所有颜色只能从这里取（AGENTS.md 第 4 节第 6 条）。
class AppColors {
  const AppColors._();

  static const bg = Color(0xFF090A0D);
  static const card = Color(0xFF14161B);
  static const cardAlt = Color(0xFF191C22);
  static const cardHi = Color(0xFF262B33);
  static const track = Color(0xFF262A32);
  static const line = Color(0xFF23262E);

  static const text = Color(0xFFF1F3F7);
  static const muted = Color(0xFF8B93A1);
  static const dim = Color(0xFF5A6270);

  static const accent = Color(0xFFA3C644);
  static const teal = Color(0xFF4FB286);
  static const cyan = Color(0xFF38CFE0);
  static const danger = Color(0xFFF07167);

  static const palette = <Color>[
    Color(0xFF4FB286),
    Color(0xFFA3C644),
    Color(0xFF38CFE0),
    Color(0xFF5C93E8),
    Color(0xFFF2C14E),
    Color(0xFFE86FA0),
    Color(0xFFE8735A),
    Color(0xFF9B7BE0),
  ];
}

class AppRadius {
  const AppRadius._();
  static const card = 24.0;
  static const panel = 26.0;
  static const control = 16.0;
  static const chip = 999.0;
}

class AppSpace {
  const AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class AppDuration {
  const AppDuration._();
  static const panel = Duration(milliseconds: 320);
  static const progress = Duration(milliseconds: 450);
  static const pop = Duration(milliseconds: 420);
  static const undo = Duration(seconds: 3);
}

/// 按背景亮度决定文字用深色还是白色，阈值 0.62。
Color inkFor(Color background) =>
    background.computeLuminance() > 0.62 ? const Color(0xFF0B1206) : Colors.white;

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF0A1004),
      secondary: AppColors.teal,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerColor: AppColors.line,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1E222A),
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 13.5),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF181B21)),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x33A3C644),
    ),
  );
}
