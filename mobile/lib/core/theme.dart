import 'package:flutter/material.dart';

/// Token warna SEBAR — palet "Hijau" dari DesignReference.
///
/// Sumber: `DesignReference/SEBAR Mobile — Hijau.html` (halaman
/// "Palet & komponen"). Lima warna acuan dipakai apa adanya:
///
/// - Latar `#FDFDFC`, kanvas luar `#FAF9F5`
/// - Garis/panel `#D9E0E2`
/// - Header/terisi `#3EC381`
/// - Tombol utama `#04BF62`
/// - Centang/grafik `#0CA458`
/// - Tinta `#10231A`, teks hijau `#087A41`
/// - Terpilih `#E3F6EC`, denda `#8A5300`, bahaya `#B3261E`
///
/// Aturan kontras (dari halaman palet): hijau terang tidak pernah dipakai
/// untuk teks kecil putih (2:1). Teks di atas hijau selalu tinta gelap
/// (6,6–7:1). Teks hijau kecil di latar putih memakai [primary] `#087A41`
/// (5,4:1). Kuning/merah hanya untuk status uang: denda dan no-show.
class C {
  // ── Kanvas & permukaan ──────────────────────────────────────────────────
  static const bg = Color(0xFFFAF9F5);
  static const bgDeep = Color(0xFFF0F1EE);
  static const surface = Color(0xFFFDFDFC);
  static const surfaceAlt = Color(0xFFF2F4F3);
  static const line = Color(0xFFD9E0E2);
  static const shadow = Color(0x0F10231A);

  // ── Teks ─────────────────────────────────────────────────────────────────
  static const ink = Color(0xFF10231A);
  static const muted = Color(0xFF4A5A52);
  static const faint = Color(0xFF5E6B65);
  static const placeholder = Color(0xFFB6C2C5);

  // ── Hijau ────────────────────────────────────────────────────────────────
  /// Teks/aksi hijau di atas putih: 5,4:1.
  static const primary = Color(0xFF087A41);

  /// Isian tombol utama & header terisi. Pasangan teks selalu [ink].
  static const primaryFill = Color(0xFF04BF62);

  /// Header/terisi terang.
  static const primaryHeader = Color(0xFF3EC381);

  /// Centang, grafik, progres.
  static const primaryCheck = Color(0xFF0CA458);

  static const primaryDeep = Color(0xFF055C30);
  static const primarySoft = Color(0xFFE3F6EC);

  // ── Dana & status ────────────────────────────────────────────────────────
  /// Denda / kurang dari 6 jam (teks di latar [amberSoft]).
  static const amber = Color(0xFF8A5300);
  static const amberFill = Color(0xFFF1C338);
  static const amberDeep = Color(0xFF5A4206);
  static const amberSoft = Color(0xFFFFF1D6);

  /// Bahaya / no-show.
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFCE8E6);

  static const cream = Color(0xFFFDFDFC);

  // Alias lama supaya layar lain tetap kompatibel.
  static const orange = amber;
  static const butter = amberSoft;
  static const mint = primarySoft;
  static const blush = primarySoft;
  static const lilac = primarySoft;

  // ── Panel ────────────────────────────────────────────────────────────────
  /// Bidang hijau: teks di atasnya [ink], bukan putih.
  static const primaryPanel = [Color(0xFF3EC381), Color(0xFF04BF62)];

  static const inkPanel = [Color(0xFF10231A), Color(0xFF10231A)];

  static const amberPanel = [Color(0xFFFFF1D6), Color(0xFFFFF1D6)];

  /// Desain baru nyaris tanpa bayangan: satu lapis tipis untuk kedalaman.
  static const cardShadow = [
    BoxShadow(color: shadow, blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Skala tipografi "Hijau": 12 label, 13 small, 14 body, 16 h2, 24 h1,
/// 28 display. Angka uang memakai [numberLg] 28.
class T {
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.15,
    color: C.ink,
  );
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: C.ink,
  );
  static const h2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
    color: C.ink,
  );
  static const h3 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: C.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: C.muted,
  );
  static const small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: C.muted,
  );
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.3,
    color: C.muted,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: C.faint,
  );
  static const metric = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1,
    color: C.ink,
  );

  /// Angka di dalam kartu/panel. Warnanya diatur pemanggil.
  static const numberSm = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
    color: C.ink,
  );
  static const numberMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: C.ink,
  );
  static const numberLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.05,
    color: C.ink,
  );
}

/// Padding standar layar. Bawah 112 memberi ruang untuk dock + FAB.
const kScreenPad = EdgeInsets.fromLTRB(16, 12, 16, 112);
const kScreenPadTop = EdgeInsets.fromLTRB(16, 12, 16, 0);

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: C.primary,
    onPrimary: Colors.white,
    primaryContainer: C.primarySoft,
    onPrimaryContainer: C.primaryDeep,
    secondary: C.amber,
    onSecondary: Colors.white,
    secondaryContainer: C.amberSoft,
    onSecondaryContainer: C.amberDeep,
    tertiary: C.primaryCheck,
    onTertiary: C.ink,
    surface: C.surface,
    onSurface: C.ink,
    surfaceContainerHighest: C.surfaceAlt,
    error: C.danger,
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
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: C.placeholder,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.danger, width: 1.2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      contentTextStyle: const TextStyle(
        color: C.surface,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      activeTrackColor: C.primary,
      inactiveTrackColor: C.surfaceAlt,
      thumbColor: C.primary,
      overlayColor: C.primary.withValues(alpha: 0.12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.primaryFill : null,
      ),
      checkColor: const WidgetStatePropertyAll(C.ink),
      side: const BorderSide(color: C.line, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.primaryCheck,
      linearTrackColor: C.surfaceAlt,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      headerBackgroundColor: C.primaryFill,
      headerForegroundColor: C.ink,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      dialBackgroundColor: C.surfaceAlt,
      dialHandColor: C.primaryCheck,
    ),
  );
}
