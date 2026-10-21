import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final played = bookings.length + 11;
    final checkIn = bookings.where((b) => b.checkedIn).length + 9;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: kScreenPad,
        children: [
          const Text('Profil', style: T.h1),
          const SizedBox(height: 2),
          const Text('Rekam jejak main dan reputasimu.', style: T.small),
          const SizedBox(height: 16),
          _ProfileHero(played: played, checkIn: checkIn),
          const SizedBox(height: 14),
          _ScoreChartCard(),
          const SizedBox(height: 22),
          const SectionHeader('Riwayat skor'),
          const SizedBox(height: 10),
          const _ScoreEvent(
            delta: 2,
            reason: 'Check-in sukses',
            detail: 'Badminton Jumat Malam',
            when: '12 Okt',
          ),
          const _ScoreEvent(
            delta: -10,
            reason: 'Batal < 6 jam',
            detail: 'Futsal Rabu Malam',
            when: '2 Okt',
          ),
          const _ScoreEvent(
            delta: 2,
            reason: 'Check-in sukses',
            detail: 'Voli Sore Santai',
            when: '28 Sep',
          ),
          const _ScoreEvent(
            delta: -25,
            reason: 'Tidak datang',
            detail: 'Mini Soccer Subuh',
            when: '14 Sep',
          ),
          const SizedBox(height: 8),
          SurfaceCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode akun venue', style: T.h3),
                const SizedBox(height: 4),
                const Text(
                  'Kelola jadwal, scan tiket, analytics, dan pencairan '
                  'dari akun terpisah.',
                  style: T.small,
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: 'Masuk akun venue',
                  icon: Icons.storefront_outlined,
                  height: 46,
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: const Column(
              children: [
                _MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat booking',
                ),
                Divider(),
                _MenuRow(icon: Icons.help_outline, label: 'Pusat bantuan'),
                Divider(),
                _MenuRow(icon: Icons.logout, label: 'Keluar', danger: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.played, required this.checkIn});

  final int played;
  final int checkIn;

  @override
  Widget build(BuildContext context) {
    return SportPanel(
      background: C.surface,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: C.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.pinkSoft, width: 4),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'R',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raka Pratama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.h3,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'raka@sebar.app · Bandung',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.small,
                    ),
                  ],
                ),
              ),
              const Pill(
                'Terpercaya',
                color: C.tealDeep,
                background: C.tealSoft,
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              StatCircle(
                value: '$played',
                label: 'Main',
                icon: Icons.sports_soccer,
                color: C.teal,
                background: C.tealSoft,
              ),
              const Spacer(),
              StatCircle(
                value: '$checkIn',
                label: 'Check-in',
                icon: Icons.qr_code_scanner,
                color: C.purple,
                background: C.purpleSoft,
              ),
              const Spacer(),
              StatCircle(
                value: '1',
                label: 'No-show',
                icon: Icons.block,
                color: C.coral,
                background: C.pinkSoft,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${me.score}%', style: T.metric),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    'skor reputasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.small,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: me.score / 100,
              minHeight: 8,
              backgroundColor: C.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(C.teal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu tren skor ala referensi: garis pink, isian lembut, label bulan.
class _ScoreChartCard extends StatelessWidget {
  const _ScoreChartCard();

  static const _values = [70.0, 74.0, 68.0, 82.0, 88.0, 92.0];
  static const _months = ['Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt'];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Perkembangan skor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.h3,
                ),
              ),
              const SizedBox(width: 8),
              const Pill(
                '+22 poin',
                color: C.green,
                background: C.tealSoft,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 104,
            width: double.infinity,
            child: CustomPaint(painter: _ScorePainter(values: _values)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final m in _months) Text(m, style: T.caption)],
          ),
        ],
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final dx = size.width / (values.length - 1);
    Offset point(int i) => Offset(
      dx * i,
      size.height - 8 - (values[i] / 100) * (size.height - 18),
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
          colors: [C.pink.withValues(alpha: 0.2), C.pink.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = C.pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 4.4, Paint()..color = C.surface);
      canvas.drawCircle(
        p,
        2.8,
        Paint()..color = i == values.length - 1 ? C.pink : C.teal,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) => old.values != values;
}

class _ScoreEvent extends StatelessWidget {
  const _ScoreEvent({
    required this.delta,
    required this.reason,
    required this.detail,
    required this.when,
  });

  final int delta;
  final String reason;
  final String detail;
  final String when;

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = positive ? C.green : C.coral;
    final bg = positive ? C.tealSoft : C.pinkSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                '${positive ? '+' : ''}$delta',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(when, style: T.caption),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: danger ? C.coral : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: danger ? C.coral : C.ink,
              ),
            ),
          ),
          if (!danger)
            const Icon(Icons.chevron_right, size: 20, color: C.muted),
        ],
      ),
    );
  }
}
