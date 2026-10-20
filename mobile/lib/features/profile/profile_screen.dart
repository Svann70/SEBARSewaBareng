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

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: C.ink,
            ),
          ),
          const SizedBox(height: 14),
          SportPanel(
            gradient: [Color(0xFF9B8CFF), Color(0xFF6A5AE0)],
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: C.butter,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'R',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: C.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'raka@sebar.app · Bandung',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${me.score}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                        height: 1,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'skor reputasi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: Colors.white70),
                        ),
                      ),
                    ),
                    const Pill(
                      'Terpercaya',
                      color: Colors.white,
                      background: Colors.white24,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: me.score / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Main',
                  value: '${bookings.length + 11}',
                  icon: Icons.sports_soccer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Check-in',
                  value: '${bookings.where((b) => b.checkedIn).length + 9}',
                  icon: Icons.qr_code_scanner,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'No-show',
                  value: '1',
                  icon: Icons.block,
                  danger: true,
                ),
              ),
            ],
          ),
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
            reason: 'No-show',
            detail: 'Mini Soccer Subuh',
            when: '14 Sep',
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode akun venue', style: T.h3),
                const SizedBox(height: 3),
                const Text(
                  'Akun terpisah: jadwal, scan tiket, analytics, pencairan.',
                  style: T.small,
                ),
                const SizedBox(height: 10),
                GhostButton(
                  label: 'Masuk akun venue',
                  icon: Icons.storefront_outlined,
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: const [
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.danger = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: danger ? C.coral : C.green),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: C.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: C.muted),
          ),
        ],
      ),
    );
  }
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
    final color = positive ? C.greenDeep : C.coral;
    final bg = positive ? C.mint : C.pink.withValues(alpha: 0.16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                '${positive ? '+' : ''}$delta',
                style: TextStyle(
                  fontSize: 12.5,
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: C.ink,
                    ),
                  ),
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              when,
              style: const TextStyle(fontSize: 10.5, color: C.muted),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 17, color: danger ? C.coral : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: danger ? C.coral : C.ink,
              ),
            ),
          ),
          if (!danger)
            const Icon(Icons.chevron_right, size: 18, color: C.muted),
        ],
      ),
    );
  }
}
