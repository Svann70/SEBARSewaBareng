import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// Kartu utama bergaya referensi: sudut besar, bidang organik tipis,
/// dan cincin dekoratif di sisi kanan.
class SportPanel extends StatelessWidget {
  const SportPanel({
    super.key,
    required this.child,
    this.gradient,
    this.background = C.surface,
    this.padding = const EdgeInsets.all(18),
    this.height,
    this.onTap,
    this.diagonal = true,
    this.radius = 28,
    this.accent = Colors.white,
    this.shadow = true,
  });

  final Widget child;
  final List<Color>? gradient;
  final Color background;
  final EdgeInsets padding;
  final double? height;
  final VoidCallback? onTap;
  final bool diagonal;
  final double radius;
  final Color accent;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      height: height,
      child: Stack(
        children: [
          if (diagonal)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PanelPainter(
                      accent: accent.withValues(
                        alpha: gradient == null ? 0.1 : 0.16,
                      ),
                      line: accent.withValues(
                        alpha: gradient == null ? 0.1 : 0.24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient == null
            ? null
            : LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? C.cardShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: onTap == null
            ? body
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: body),
              ),
      ),
    );
  }
}

/// Bidang organik + cincin tipis, bahasa visual dari referensi.
class _PanelPainter extends CustomPainter {
  _PanelPainter({required this.accent, required this.line});

  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final blob = Path()
      ..moveTo(size.width * 0.58, 0)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.08,
        size.width * 0.94,
        size.height * 0.28,
        size.width,
        size.height * 0.34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.72,
        size.width * 0.44,
        size.height * 0.4,
        size.width * 0.58,
        0,
      )
      ..close();
    canvas.drawPath(blob, Paint()..color = accent);

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.12),
      size.height * 0.5,
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.98, size.height * 0.86),
      size.height * 0.22,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) =>
      old.accent != accent || old.line != line;
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = C.ink,
    this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? C.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          Expanded(child: Text(title, style: T.h2)),
          if (action != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SebarButton extends StatelessWidget {
  const SebarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = C.primary,
    this.foreground = Colors.white,
    this.icon,
    this.busy = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.22)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 18, color: foreground),
                  if (busy || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = C.ink,
    this.height = 50,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 24,
    this.color,
    this.border = false,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? C.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: C.line) : null,
        boxShadow: shadow ? C.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Dock bawah mengambang: kapsul krem, dua tujuan di kiri, dua di kanan,
/// aksi utama pink di tengah.
class DockNav extends StatelessWidget {
  const DockNav({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onCreate,
    this.items = playerDock,
    this.centerIcon = Icons.add,
    this.centerLabel,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final List<(IconData, IconData, String)> items;
  final IconData centerIcon;
  final String? centerLabel;

  static const playerDock = [
    (Icons.explore_outlined, Icons.explore, 'Cari'),
    (Icons.confirmation_number_outlined, Icons.confirmation_number, 'Tiket'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Dompet',
    ),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  static const venueDock = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Beranda'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Jadwal'),
    (Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, 'Scan'),
    (Icons.storefront_outlined, Icons.storefront, 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.bg.withValues(alpha: 0), C.bg],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 68,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: C.cardShadow,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: _DockItem(
                          item: items[i],
                          active: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                    const SizedBox(width: 140),
                    for (var i = 2; i < 4; i++)
                      Expanded(
                        child: _DockItem(
                          item: items[i],
                          active: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -18,
                child: _CenterAction(
                  icon: centerIcon,
                  label: centerLabel ?? 'Buat room',
                  onTap: onCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final (IconData, IconData, String) item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? C.primaryDeep : C.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? C.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(active ? item.$2 : item.$1, size: 21, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              item.$3,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({
    required this.onTap,
    required this.label,
    this.icon = Icons.add,
  });

  final VoidCallback onTap;

  /// Teks pendamping ikon supaya aksi utama langsung terbaca.
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [C.primary, C.primaryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: C.surface, width: 4),
            boxShadow: [
              BoxShadow(
                color: C.primary.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: C.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: C.primary, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title, style: T.h3, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center, style: T.small),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboard,
    this.prefixIcon,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: C.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 19, color: C.muted),
          ),
        ),
      ],
    );
  }
}

/// Kolom pencarian krem dengan ikon dan tombol bersihkan.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = 'Cari lapangan, venue, atau kota',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: C.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search, size: 21, color: C.muted),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: C.muted),
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                    ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lingkaran statistik: cincin progres + angka besar + label + keterangan.
/// Angka dibaca dulu, label menempel, cincin menunjukkan proporsinya.
class StatRing extends StatelessWidget {
  const StatRing({
    super.key,
    required this.value,
    required this.label,
    required this.caption,
    required this.icon,
    required this.progress,
    this.color = C.primary,
    this.size = 96,
  });

  final String value;
  final String label;
  final String caption;
  final IconData icon;

  /// 0..1 — bagian cincin yang terisi.
  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(progress: progress, color: color),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: T.caption,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.065;
    final center = (Offset.zero & size).center;
    final radius = (size.width - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.16),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Progress kuota: cincin tipis + angka.
class QuotaRing extends StatelessWidget {
  const QuotaRing({
    super.key,
    required this.joined,
    required this.quota,
    this.size = 64,
    this.color = Colors.white,
    this.foreground = Colors.white,
    this.track = Colors.white24,
  });

  final int joined;
  final int quota;
  final double size;
  final Color color;
  final Color foreground;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final pct = quota == 0 ? 0.0 : joined / quota;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: size * 0.09,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$joined',
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                  color: foreground,
                ),
              ),
              Text(
                'dari $quota',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w600,
                  color: foreground.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet dengan sudut atas membulat.
class SheetWrap extends StatelessWidget {
  const SheetWrap({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: C.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: T.h2),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

String formatDate(DateTime d) {
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

String formatLongDate(DateTime d) {
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatCountdown(Duration d) {
  if (d.isNegative) return 'Ditutup';
  return '${d.inHours}j ${d.inMinutes % 60}m';
}

// ─── Bahasa visual referensi ────────────────────────────────────────────────

/// Pil gelap pekat dengan label putih — aksi sekunder di dalam blok warna
/// (gaya tombol "Request Demo" pada referensi).
class DarkPillButton extends StatelessWidget {
  const DarkPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = C.ink,
    this.foreground = Colors.white,
    this.height = 42,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sakelar dua/tiga segmen dalam kapsul (gaya Weekly/Month).
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelOf,
    this.background = C.surface,
    this.selectedBackground = C.ink,
    this.selectedForeground = Colors.white,
    this.foreground = C.muted,
    this.height = 42,
  });

  final List<V> options;
  final V value;
  final ValueChanged<V> onChanged;
  final String Function(V)? labelOf;
  final Color background;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == value ? selectedBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labelOf?.call(o) ?? '$o',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: o == value ? selectedForeground : foreground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu hitung gaya referensi: badge ikon bulat di atas, angka besar,
/// label kecil di bawah.
class CountCard extends StatelessWidget {
  const CountCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = C.primary,
    this.tint = C.primarySoft,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1,
            color: C.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: T.caption,
        ),
      ],
    );
  }
}

/// Baris peringkat/blok berwarna: ikon atau nomor di kiri, judul, pil nilai,
/// lalu tumpukan avatar di kanan (gaya Leaderboard).
class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required this.rank,
    required this.title,
    this.subtitle,
    this.value,
    this.background = C.surface,
    this.foreground = C.ink,
    this.avatars = const [],
    this.onTap,
  });

  final int rank;
  final String title;
  final String? subtitle;
  final String? value;
  final Color background;
  final Color foreground;
  final List<String> avatars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: foreground.withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: C.line),
                  ),
                  child: Text(
                    value!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: C.ink,
                    ),
                  ),
                ),
              ],
              if (avatars.isNotEmpty) ...[
                const SizedBox(width: 8),
                AvatarStack(names: avatars),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tumpukan avatar inisial yang saling menumpuk.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.size = 30,
    this.max = 3,
    this.colors = const [C.primary, C.primaryDeep, C.amberDeep],
  });

  final List<String> names;
  final double size;
  final int max;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final overlap = size * 0.34;
    return SizedBox(
      width: size + (shown.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: C.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  shown[i].isEmpty ? '?' : shown[i][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu grafik tren dengan lencana nilai mengambang (gaya referensi).
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headline,
    required this.badge,
    required this.values,
    required this.labels,
    this.lineColor = C.primaryFill,
  });

  final String title;
  final String subtitle;
  final String headline;
  final String badge;
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.h3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                  color: C.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 122,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: TrendChartPainter(
                      values: values,
                      color: lineColor,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: C.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in labels)
                Flexible(
                  child: Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  TrendChartPainter({required this.values, this.color = C.primaryFill});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    final dx = size.width / (values.length - 1);

    Offset point(int i) => Offset(
      dx * i,
      size.height - 10 - ((values[i] - minV) / range) * (size.height - 30),
    );

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p0 = point(i);
      final p1 = point(i + 1);
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = C.line
        ..strokeWidth = 1,
    );

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 4.4, Paint()..color = C.surface);
      canvas.drawCircle(
        p,
        2.8,
        Paint()..color = i == values.length - 1 ? C.ink : color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter old) =>
      old.values != values || old.color != color;
}

/// Foto lapangan dipakai lintas layar (detail room, detail slot, buat room).
///
/// Venue bisa mengganti foto per lapangan; semua layar membaca kunci yang
/// sama ([courtPhotoKey]) sehingga foto baru langsung tampil di room yang
/// memakai lapangan itu. ponytail: foto masih berupa URL (prasetel atau
/// tempel manual); ganti ke unggahan galeri begitu API media tersedia.
class CourtPhotoNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void setPhoto(String key, String url) => state = {...state, key: url};
}

final courtPhotosProvider =
    NotifierProvider<CourtPhotoNotifier, Map<String, String>>(
      CourtPhotoNotifier.new,
    );

/// Kunci foto: venue + lapangan, huruf kecil.
String courtPhotoKey(String venue, String court) =>
    '${venue.trim().toLowerCase()}|${court.trim().toLowerCase()}';

class CourtPhoto extends ConsumerWidget {
  const CourtPhoto({
    super.key,
    required this.venue,
    required this.court,
    this.height = 170,
    this.radius = 20,
    this.scrim = false,
  });

  final String venue;
  final String court;
  final double height;
  final double radius;

  /// Lapisan gelap pengaman agar teks putih di atas foto tetap ≥ 4,5:1.
  final bool scrim;

  String get photoKey => courtPhotoKey(venue, court);

  /// Foto bawaan kalau venue belum memilih sendiri.
  static String defaultUrl(String key) =>
      'https://picsum.photos/seed/sebar-${_hash(key)}/800/450';

  /// Pilihan foto bawaan untuk pemilih foto di sisi venue.
  static List<String> presets(String key) => [
    for (var i = 1; i <= 6; i++)
      'https://picsum.photos/seed/sebar-${_hash(key)}-$i/800/450',
  ];

  static int _hash(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) % 9973;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url =
        ref.watch(courtPhotosProvider)[photoKey] ?? defaultUrl(photoKey);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _PhotoFallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _PhotoFallback(),
            ),
            if (scrim)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: C.primaryPanel,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.stadium_outlined, size: 30, color: Colors.white70),
      ),
    );
  }
}
