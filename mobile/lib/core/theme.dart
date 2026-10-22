import 'package:flutter/material.dart';

/// Token warna SEBAR.
///
/// Palet acuan: hijau `#00A27D`, krem `#EDE8D0`, amber `#F1C338` — satu
/// warna utama, satu aksen, sisanya netral. Merah/ungu lama dihapus supaya
/// mata tidak lelah dan layar tidak ramai.
///
/// Aturan pakai (jangan dilanggar tanpa alasan):
/// 1. Bidang berwarna besar maksimal satu per layar; sisanya kartu krem.
/// 2. Hijau = aksi, uang, status positif. Amber = peringatan, denda, hal
///    yang perlu ditunda.
/// 3. Warna terang (`primaryFill` #00A27D, `amberFill` #F1C338) hanya untuk
///    bidang non-teks (ikon, grafik, chip) atau bersama teks [ink] —
///    teks putih di atasnya gagal kontras. Teks hijau di krem pakai
///    [primary]/[primaryDeep], teks amber pakai [amber].
/// 4. Panel pekat (`*Panel`) untuk teks putih (rasio ≥ 4,5:1).
/// 5. Merah ([danger]) hanya untuk aksi merusak, teks kecil saja.
class C {
  // ── Kanvas & permukaan ──────────────────────────────────────────────────
  static const bg = Color(0xFFEDE8D0);
  static const bgDeep = Color(0xFFE2DCC0);
  static const surface = Color(0xFFFAF7EA);
  static const surfaceAlt = Color(0xFFE7E1C8);
  static const line = Color(0xFFD8D1B4);
  static const shadow = Color(0x14202B23);

  // ── Teks ─────────────────────────────────────────────────────────────────
  static const ink = Color(0xFF1B2B26);
  static const muted = Color(0xFF55604F);
  static const faint = Color(0xFF66705F);

  // ── Hijau (#00A27D) ─────────────────────────────────────────────────────
  /// Teks/aksi hijau di atas krem: kontras 5,7:1.
  static const primary = Color(0xFF00664F);

  /// Bidang terang: isian, ikon, grafik. Jangan dipakai untuk teks kecil.
  static const primaryFill = Color(0xFF00A27D);

  static const primaryDeep = Color(0xFF00412F);
  static const primarySoft = Color(0xFFD6EFE6);

  // ── Amber (#F1C338) ─────────────────────────────────────────────────────
  /// Teks amber di atas krem: kontras 5,2:1.
  static const amber = Color(0xFF7A5A0A);

  /// Bidang terang: isian, ikon peringatan. Pasangan teks [ink].
  static const amberFill = Color(0xFFF1C338);

  static const amberDeep = Color(0xFF5A4206);
  static const amberSoft = Color(0xFFF8EDC6);

  /// Hanya untuk aksi merusak (hapus/batalkan). Bukan warna brand.
  static const danger = Color(0xFFA5243C);
  static const dangerSoft = Color(0xFFF6E0E4);

  static const cream = Color(0xFFFAF7EA);

  // Alias lama supaya layar lain tetap kompatibel.
  static const orange = amber;
  static const butter = amberSoft;
  static const mint = primarySoft;
  static const blush = primarySoft;
  static const lilac = primarySoft;

  // ── Panel pekat (teks putih aman) ────────────────────────────────────────
  /// Hijau pekat: panel uang/CTA (teks putih 5,3:1).
  static const primaryPanel = [Color(0xFF007A5E), Color(0xFF00412F)];

  /// Netral pekat: header informasi tanpa beban warna.
  static const inkPanel = [Color(0xFF26332F), Color(0xFF16211E)];

  /// Amber pekat: konteks denda/peringatan.
  static const amberPanel = [Color(0xFF7A5A0A), Color(0xFF5A4206)];

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
    primary: C.primary,
    onPrimary: Colors.white,
    primaryContainer: C.primarySoft,
    onPrimaryContainer: C.primaryDeep,
    secondary: C.amber,
    onSecondary: Colors.white,
    secondaryContainer: C.amberSoft,
    onSecondaryContainer: C.amberDeep,
    tertiary: C.amber,
    onTertiary: Colors.white,
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
        borderSide: const BorderSide(color: C.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: C.danger, width: 1.4),
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
      activeTrackColor: C.primary,
      inactiveTrackColor: C.surfaceAlt,
      thumbColor: C.primary,
      overlayColor: C.primary.withValues(alpha: 0.12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? C.primary : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: C.faint, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.primary,
      linearTrackColor: C.surfaceAlt,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      headerBackgroundColor: C.primaryDeep,
      headerForegroundColor: C.cream,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      hourMinuteColor: WidgetStateColor.resolveWith((s) => C.surfaceAlt),
      dialBackgroundColor: C.surfaceAlt,
      dialHandColor: C.primary,
      entryModeIconColor: C.muted,
    ),
  );
}
