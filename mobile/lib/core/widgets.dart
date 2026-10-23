import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// Kartu/panel: satu garis tipis tanpa bayangan.
///
/// Panel bergradien tetap memakai blob diagonal tipis dari versi lama
/// sebagai aksen, kartu datar tidak — supaya layar tidak ramai.
class SportPanel extends StatelessWidget {
  const SportPanel({
    super.key,
    required this.child,
    this.gradient,
    this.background = C.surface,
    this.padding = const EdgeInsets.all(16),
    this.height,
    this.onTap,
    this.diagonal = true,
    this.radius = 12,
    this.accent = Colors.white,
    this.shadow = false,
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
      child: Padding(padding: padding, child: child),
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
        border: gradient == null ? Border.all(color: C.line) : null,
        boxShadow: shadow || gradient != null ? C.cardShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (gradient != null && diagonal)
              Positioned.fill(
                child: CustomPaint(painter: _PanelPainter(accent)),
              ),
            onTap == null
                ? body
                : Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: onTap, child: body),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Lengkung diagonal di pojok kanan atas panel, ciri versi sebelumnya.
class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: 0.14);
    final path = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.35,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PanelPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = C.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? C.primarySoft,
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
                fontWeight: FontWeight.w600,
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
    this.color = C.primaryFill,
    this.foreground = C.ink,
    this.icon,
    this.busy = false,
    this.height = 52,
    this.radius = 12,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final IconData? icon;
  final bool busy;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
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
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.radius = 12,
    this.color,
    this.border = true,
    this.shadow = false,
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
    (Icons.storefront_outlined, Icons.storefront, 'Lapangan'),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SafeArea(
        top: false,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.line),
            boxShadow: C.cardShadow,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      child: _DockItem(
                        item: items[i],
                        active: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  const SizedBox(width: 72),
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
              Positioned(
                top: -12,
                child: _CenterAction(
                  icon: centerIcon,
                  tooltip: centerLabel ?? 'Buat room',
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
    final color = active ? C.primary : C.faint;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.1 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Icon(active ? item.$2 : item.$1, size: 21, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              item.$3,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
    required this.tooltip,
    this.icon = Icons.add,
  });

  final VoidCallback onTap;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.primaryFill,
              border: Border.all(color: C.surface, width: 3),
              boxShadow: C.cardShadow,
            ),
            child: Icon(icon, color: C.ink, size: 26),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.surface,
              shape: BoxShape.circle,
              border: Border.all(color: C.line),
            ),
            child: Icon(icon, color: C.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: T.h2, textAlign: TextAlign.center),
          const SizedBox(height: 4),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: C.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search, size: 19, color: C.faint),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 17, color: C.faint),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: C.line)),
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
    this.selectedBackground = C.primaryFill,
    this.selectedForeground = C.ink,
    this.foreground = C.faint,
    this.height = 40,
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
              cacheWidth: 720,
              filterQuality: FilterQuality.medium,
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
        child: Icon(Icons.stadium_outlined, size: 30, color: C.ink),
      ),
    );
  }
}

// ─── Komponen khas desain "Hijau" ───────────────────────────────────────────

/// Garis putus-putus: penanda baris absen yang belum terisi.
class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.color = C.line});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedPainter(color)),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}

/// Kartu room gaya "absen patungan": label olahraga, judul, jadwal,
/// harga per orang, lalu tumpukan peserta + sisa slot.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.sport,
    required this.title,
    required this.when,
    required this.place,
    required this.pricePerPerson,
    required this.members,
    required this.joined,
    required this.quota,
    this.access = 'PUBLIK',
    this.onTap,
  });

  final String sport;
  final String title;
  final String when;
  final String place;
  final int pricePerPerson;
  final List<String> members;
  final int joined;
  final int quota;
  final String access;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = quota - joined;
    final icon = switch (sport.toLowerCase()) {
      'badminton' => Icons.sports_tennis,
      'futsal' || 'mini soccer' || 'sepak bola' => Icons.sports_soccer,
      'voli' || 'volleyball' => Icons.sports_volleyball,
      'basket' || 'basketball' => Icons.sports_basketball,
      _ => Icons.sports,
    };
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: C.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: C.primary),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '${sport.toUpperCase()} · $access',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: C.faint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: T.h2,
          ),
          const SizedBox(height: 4),
          Text(when, style: T.small),
          Text(place, style: T.caption),
          const SizedBox(height: 10),
          Row(
            children: [
              AvatarStack(names: members, max: 4, size: 26),
              const SizedBox(width: 8),
              Text(
                '$joined/$quota',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.ink,
                ),
              ),
              const Spacer(),
              Pill(
                remaining <= 0 ? 'Penuh' : '$remaining slot lagi',
                color: remaining <= 0 ? C.danger : C.primary,
                background: remaining <= 0 ? C.dangerSoft : C.primarySoft,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: quota == 0 ? 0.0 : (joined / quota).clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 5,
                backgroundColor: C.surfaceAlt,
                color: remaining <= 0 ? C.danger : C.primaryFill,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupiahLabel(pricePerPerson),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: C.ink,
                ),
              ),
              const SizedBox(width: 5),
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('per orang', style: T.caption),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris absen: nomor, nama, keterangan (host/kamu), harga yang dikunci.
class AttendRow extends StatelessWidget {
  const AttendRow({
    super.key,
    required this.number,
    this.name,
    this.tag,
    this.trailing,
    this.pending = false,
  });

  final int number;
  final String? name;
  final String? tag;
  final String? trailing;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$number.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.faint,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: pending
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: pending ? C.faint : C.ink,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 5),
                      Text('· $tag', style: T.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pending ? C.faint : C.primary,
                ),
              ),
            ],
          ),
          if (pending) ...[const SizedBox(height: 7), const DashedLine()],
        ],
      ),
    );
  }
}

/// Tiket ringkas: blok tanggal di kiri, judul + jadwal di kanan.
class TicketTile extends StatelessWidget {
  const TicketTile({
    super.key,
    required this.day,
    required this.date,
    required this.month,
    required this.title,
    required this.when,
    required this.place,
    this.note,
    this.onTap,
  });

  final String day;
  final String date;
  final String month;
  final String title;
  final String when;
  final String place;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: C.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  day.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: C.primary,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: C.ink,
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: C.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
                Text(when, style: T.small),
                Text(place, style: T.caption),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(note!, style: T.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: C.faint),
        ],
      ),
    );
  }
}

/// Muncul dengan fade + naik halus sekali saat dipasang. [index] memberi
/// jeda bertingkat antar kartu. Tidak berulang supaya tidak mengganggu.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 45;
    const total = 320;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total + delay),
      curve: Interval(delay / (total + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Angka rupiah yang menghitung naik saat pertama tampil atau berubah.
class AnimatedRupiah extends StatelessWidget {
  const AnimatedRupiah(
    this.value, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, shown, _) => Text(rupiahLabel(shown.round()), style: style),
    );
  }
}

/// Format rupiah ringkas untuk komponen yang tidak mengimpor core/money.
String rupiahLabel(int amount) {
  final text = amount.toString();
  final buffer = StringBuffer('Rp');
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
