import 'package:flutter/material.dart';

/// Token warna SEBAR — mengikuti design referensi:
/// kanvas krem hangat, blok warna pink / teal / amber, kartu krem,
/// pil gelap, dan angka besar.
///
/// Aturan kontras:
/// - blok pekat (`*Panel`) untuk teks putih (rasio ≥ 4,5:1),
/// - blok terang (`*Fill`) untuk teks [ink] (≥ 4,5:1),
/// - teks aksen di atas krem memakai varian gelap (`*Deep`).
class C {
  // ── Kanvas & permukaan ──────────────────────────────────────────────────
  static const bg = Color(0xFFF6EFE7);
  static const bgDeep = Color(0xFFEDE2D6);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceAlt = Color(0xFFF4EADF);
  static const line = Color(0xFFE7D9CB);
  static const shadow = Color(0x1A2A2320);

  // ── Teks ─────────────────────────────────────────────────────────────────
  static const ink = Color(0xFF1C2B29);
  static const muted = Color(0xFF5A6862);
  static const faint = Color(0xFF6E7A73);

  // ── Aksen ────────────────────────────────────────────────────────────────
  static const pink = Color(0xFFC93F62);
  static const pinkFill = Color(0xFFEE5A7E);
  static const pinkDeep = Color(0xFF9E2A47);
  static const pinkSoft = Color(0xFFFAD9E3);
  static const coral = Color(0xFFB3263F);

  static const teal = Color(0xFF2E7D70);
  static const tealFill = Color(0xFF349585);
  static const tealDeep = Color(0xFF1E5A50);
  static const tealSoft = Color(0xFFD9EEE7);
  static const green = Color(0xFF1E7A5F);
  static const greenDeep = Color(0xFF14513F);

  static const amber = Color(0xFFA9660F);
  static const amberDeep = Color(0xFF7A4708);
  static const amberSoft = Color(0xFFFBE7C2);
  static const amberFill = Color(0xFFEFA53A);
  static const purple = Color(0xFF6B58B8);
  static const purpleSoft = Color(0xFFEDE8FB);

  static const cream = Color(0xFFFFFCF6);

  // Alias lama supaya layar lain tetap kompatibel.
  static const orange = amber;
  static const mint = tealSoft;
  static const butter = amberSoft;
  static const lilac = purpleSoft;
  static const blush = pinkSoft;

  // ── Panel pekat (teks putih aman) ────────────────────────────────────────
  static const pinkPanel = [Color(0xFFC93F62), Color(0xFF9E2A47)];
  static const tealPanel = [Color(0xFF2E7D70), Color(0xFF1E5A50)];
  static const purplePanel = [Color(0xFF6B58B8), Color(0xFF4A3C8C)];
  static const amberPanel = [Color(0xFFA9660F), Color(0xFF7A4708)];

  static const cardShadow = [
    BoxShadow(color: shadow, blurRadius: 26, offset: Offset(0, 12)),
  ];
}

/// Skala tipografi: satu set ukuran saja, tidak ada nilai di bawah 12px.
///
/// Ukuran resmi (jangan tambah nilai baru di luar daftar ini):
/// 12 label/caption · 13 small · 15 body · 15.5 h3/button · 18 h2 ·
/// 20 angka kecil · 24 angka sedang · 26 h1 · 32 angka besar · 34 display ·
/// 40 metric.
class T {
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.06,
    color: C.ink,
  );
  static const h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.12,
    color: C.ink,
  );
  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: C.ink,
  );
  static const h3 = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
    color: C.ink,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: C.muted,
  );
  static const small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: C.muted,
  );
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.3,
    color: C.muted,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: C.faint,
  );
  static const metric = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    height: 1,
    color: C.ink,
  );

  /// Angka di dalam kartu/panel. Warnanya diatur pemanggil
  /// (putih di panel pekat, [C.ink] di kartu krem).
  static const numberSm = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.1,
    color: C.ink,
  );
  static const numberMd = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.05,
    color: C.ink,
  );
  static const numberLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    height: 1,
    color: C.ink,
  );
}

/// Padding standar layar. Bawah 112 memberi ruang untuk dock + FAB
/// sehingga baris terakhir tidak tertutup.
const kScreenPad = EdgeInsets.fromLTRB(20, 12, 20, 112);
const kScreenPadTop = EdgeInsets.fromLTRB(20, 12, 20, 0);

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: C.pink,
    onPrimary: Colors.white,
    primaryContainer: C.pinkSoft,
    onPrimaryContainer: C.pinkDeep,
    secondary: C.teal,
    onSecondary: Colors.white,
    secondaryContainer: C.tealSoft,
    onSecondaryContainer: C.tealDeep,
    tertiary: C.amber,
    onTertiary: Colors.white,
    surface: C.surface,
    onSurface: C.ink,
    surfaceContainerHighest: C.surfaceAlt,
    error: C.coral,
    onError: Colors.white,
    outline: C.line,
    outlineVariant: C.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: C.ink, displayColor: C.ink)
        .copyWith(
          displaySmall: T.display,
          headlineSmall: T.h1,
          headlineMedium: T.h2,
          titleMedium: T.h3,
          bodyMedium: T.body,
          bodySmall: T.small,
          labelSmall: T.label,
          labelLarge: T.h3,
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      hintStyle: T.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: C.pink, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: C.coral, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      contentTextStyle: const TextStyle(
        color: C.cream,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 6,
      activeTrackColor: C.pink,
      inactiveTrackColor: C.surfaceAlt,
      thumbColor: C.pink,
      overlayColor: C.pink.withValues(alpha: 0.12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.pink : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: C.faint, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.pink,
      linearTrackColor: C.surfaceAlt,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.pink,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      headerBackgroundColor: C.tealDeep,
      headerForegroundColor: C.cream,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      hourMinuteColor: WidgetStateColor.resolveWith((s) => C.surfaceAlt),
      dialBackgroundColor: C.surfaceAlt,
      dialHandColor: C.pink,
      entryModeIconColor: C.muted,
    ),
  );
}
