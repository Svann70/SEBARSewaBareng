import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;

  Future<void> _logout() async {
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    final user = ref.watch(sessionProvider);
    final played = bookings.length;
    final checkIn = bookings.where((b) => b.checkedIn).length;
    final initial = (user?.fullName.trim().isEmpty ?? true)
        ? 'R'
        : user!.fullName.trim()[0].toUpperCase();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: kScreenPad,
        children: [
          const Text('Profil', style: T.h1),
          const SizedBox(height: 2),
          const Text('Rekam jejak main kamu.', style: T.small),
          const SizedBox(height: 16),
          _ProfileHero(
            name: user?.fullName ?? 'Raka',
            email: user?.email ?? 'raka@sebar.app',
            initial: initial,
            played: played,
            checkIn: checkIn,
          ),
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
            child: Column(
              children: [
                const _MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat pembayaran',
                ),
                const Divider(),
                const _MenuRow(
                  icon: Icons.help_outline,
                  label: 'Pusat bantuan',
                ),
                const Divider(),
                _MenuRow(
                  icon: Icons.logout,
                  label: 'Keluar',
                  danger: true,
                  onTap: _busy ? null : _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.initial,
    required this.played,
    required this.checkIn,
  });

  final String name;
  final String email;
  final String initial;
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
                  color: C.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.surface, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: C.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.h3,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      email,
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
            children: [
              Expanded(
                child: CountCard(
                  icon: Icons.sports_soccer,
                  value: '$played',
                  label: 'Main',
                ),
              ),
              Expanded(
                child: CountCard(
                  icon: Icons.check_circle_outline,
                  value: '$checkIn',
                  label: 'Hadir',
                  color: C.primaryCheck,
                ),
              ),
              Expanded(
                child: CountCard(
                  icon: Icons.event_busy,
                  value: '${(played - checkIn).clamp(0, played)}',
                  label: 'Tidak datang',
                  color: C.amber,
                  tint: C.amberSoft,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
      ),
    );
  }
}
