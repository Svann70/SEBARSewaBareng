import 'package:flutter/material.dart';

import 'theme.dart';

/// Kartu utama bergaya referensi: sudut besar, isian gradien,
/// potongan diagonal di sisi kanan, dan garis orbit tipis.
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
    this.radius = 26,
    this.accent = Colors.white,
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
                    painter: _DiagonalPainter(
                      accent: accent.withValues(alpha: 0.16),
                      line: accent.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    return DecoratedBox(
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

class _DiagonalPainter extends CustomPainter {
  _DiagonalPainter({required this.accent, required this.line});

  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    // Potongan diagonal: satu bidang miring dari sudut kanan atas.
    final band = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.3, size.height)
      ..close();
    canvas.drawPath(band, Paint()..color = accent);

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.5),
      size.height * 0.46,
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height),
      Offset(size.width * 0.72, 0),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalPainter old) =>
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
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
      height: 26,
      child: Row(
        children: [
          Expanded(child: Text(title, style: T.h2)),
          if (action != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: C.muted,
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
    this.color = C.pink,
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
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.28)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(999),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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
    this.height = 48,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
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
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 22,
    this.color,
    this.border = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? C.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: C.line) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dock bawah: dua tujuan di kiri, dua di kanan, aksi utama di tengah.
/// Aksi tengah tidak punya label supaya tidak menutupi ikon lain.
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
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Dompet'),
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
      color: C.bg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
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
                  const SizedBox(width: 78),
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
                top: -22,
                child: _CenterAction(icon: centerIcon, onTap: onCreate),
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
    final color = active ? C.ink : C.faint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(active ? item.$2 : item.$1, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            item.$3,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.onTap, this.icon = Icons.add});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6E8C), C.pinkDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: C.bg, width: 5),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
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
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: C.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: C.muted, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: T.h3),
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
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  final IconData? prefixIcon;

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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: C.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: C.faint, fontSize: 13),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: C.faint),
            filled: true,
            fillColor: C.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: C.pink, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.score, {super.key, this.compact = false});

  final int score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? C.green
        : score >= 60
        ? C.orange
        : C.pink;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: compact ? 11 : 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress kuota: cincin tipis + angka.
class QuotaRing extends StatelessWidget {
  const QuotaRing({
    super.key,
    required this.joined,
    required this.quota,
    this.size = 64,
    this.color = Colors.white,
  });

  final int joined;
  final int quota;
  final double size;
  final Color color;

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
              backgroundColor: Colors.white.withValues(alpha: 0.22),
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
                  color: Colors.white,
                ),
              ),
              Text(
                'dari $quota',
                style: TextStyle(
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: C.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: T.h2),
          const SizedBox(height: 12),
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

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatCountdown(Duration d) {
  if (d.isNegative) return 'Ditutup';
  return '${d.inHours}j ${d.inMinutes % 60}m';
}
