import 'package:flutter/material.dart';

/// Token warna SEBAR — mengikuti bahasa visual referensi:
/// latar nyaris hitam, kartu berwarna jenuh, aksen pink.
class C {
  static const bg = Color(0xFF0A0A0D);
  static const surface = Color(0xFF141419);
  static const surfaceAlt = Color(0xFF1E1E26);
  static const line = Color(0xFF26262E);

  static const pink = Color(0xFFFF5F7E);
  static const pinkDeep = Color(0xFFE8436A);
  static const purple = Color(0xFF8A7BF7);
  static const green = Color(0xFF2FD08A);
  static const greenDeep = Color(0xFF7CE0B0);
  static const orange = Color(0xFFF2A25C);
  static const amber = Color(0xFFF2A25C);
  static const coral = Color(0xFFFF5F7E);
  static const cream = Color(0xFFF7F3EA);

  // Tint gelap untuk tile ikon / panel kecil.
  static const mint = Color(0xFF16302A);
  static const butter = Color(0xFF2E2618);
  static const lilac = Color(0xFF231F3D);

  static const ink = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9A9AA8);
  static const faint = Color(0xFF6B6B78);
}

class T {
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    height: 1.04,
    color: C.ink,
  );
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.14,
    color: C.ink,
  );
  static const h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
    color: C.ink,
  );
  static const h3 = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: C.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: C.muted,
  );
  static const small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: C.muted,
  );
  static const label = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: C.muted,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: C.pink,
    onPrimary: Colors.white,
    secondary: C.purple,
    onSecondary: Colors.white,
    surface: C.surface,
    onSurface: C.ink,
    error: C.pink,
    onError: Colors.white,
    outline: C.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: C.ink, displayColor: C.ink)
        .copyWith(
          displaySmall: T.display,
          headlineSmall: T.h1,
          titleMedium: T.h2,
          bodyMedium: T.body,
          labelSmall: T.small,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: T.h2,
      iconTheme: IconThemeData(color: C.ink),
    ),
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surfaceAlt,
      contentTextStyle: const TextStyle(
        color: C.ink,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surfaceAlt,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      activeTrackColor: C.pink,
      inactiveTrackColor: C.surfaceAlt,
      thumbColor: Colors.white,
      overlayColor: C.pink.withValues(alpha: 0.14),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.pink : Colors.transparent,
      ),
      side: const BorderSide(color: C.faint, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.pink,
      linearTrackColor: C.surfaceAlt,
    ),
  );
}
