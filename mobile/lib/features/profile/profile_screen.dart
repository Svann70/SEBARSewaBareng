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
          const Text('Rekam jejak main kamu.', style: T.small),
          const SizedBox(height: 16),
          _ProfileHero(played: played, checkIn: checkIn),
          const SizedBox(height: 22),
          const SectionHeader('Riwayat main'),
          const SizedBox(height: 10),
          if (bookings.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'Belum ada riwayat',
              message: 'Main pertama kamu akan muncul di sini.',
            )
          else
            for (final b in bookings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlayRow(booking: b),
              ),
          const SizedBox(height: 12),
          SurfaceCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode mitra', style: T.h3),
                const SizedBox(height: 4),
                const Text(
                  'Kelola jadwal lapangan, scan tiket, dan pencairan lewat '
                  'akun mitra venue.',
                  style: T.small,
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: 'Masuk sebagai mitra',
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
                  label: 'Riwayat pembayaran',
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
                  color: C.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.primarySoft, width: 4),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raka Pratama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.h3,
                    ),
                    SizedBox(height: 1),
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
                'Aktif',
                color: C.primaryDeep,
                background: C.primarySoft,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatRing(
                  value: '$played',
                  label: 'Main',
                  caption: 'sesi selesai',
                  icon: Icons.sports_soccer,
                  progress: played / 40,
                  color: C.primary,
                ),
              ),
              Expanded(
                child: StatRing(
                  value: '$checkIn',
                  label: 'Check-in',
                  caption: 'tepat waktu',
                  icon: Icons.qr_code_scanner,
                  progress: played == 0 ? 0 : checkIn / played,
                  color: C.primaryFill,
                ),
              ),
              Expanded(
                child: StatRing(
                  value: '1',
                  label: 'No-show',
                  caption: 'dari 12 sesi',
                  icon: Icons.block,
                  progress: 1 / 12,
                  color: C.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayRow extends StatelessWidget {
  const _PlayRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: booking.checkedIn ? C.primarySoft : C.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              booking.sport.icon,
              size: 19,
              color: booking.checkedIn ? C.primary : C.muted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                Text(
                  '${booking.venue} · ${formatDate(booking.start)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(
            booking.checkedIn ? 'Hadir' : 'Terjadwal',
            color: booking.checkedIn ? C.primaryDeep : C.muted,
            background: booking.checkedIn ? C.primarySoft : C.surfaceAlt,
          ),
        ],
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
          Icon(icon, size: 19, color: danger ? C.danger : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: danger ? C.danger : C.ink,
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
