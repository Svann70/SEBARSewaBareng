import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';
import 'venue_tabs.dart';

/// Shell akun venue: akun terpisah dari pemain, dock sendiri.
class VenueShell extends StatefulWidget {
  const VenueShell({super.key});

  @override
  State<VenueShell> createState() => _VenueShellState();
}

class _VenueShellState extends State<VenueShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _pages = [
    _VenueHome(),
    VenueScheduleTab(),
    VenueScanTab(),
    _VenueAccount(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _visited.contains(i)
                  ? RepaintBoundary(child: _pages[i])
                  : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: DockNav(
        index: _index,
        items: DockNav.venueDock,
        centerIcon: Icons.add,
        centerLabel: 'Buka slot',
        onSelect: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        onCreate: () => showAddSlotSheet(context),
      ),
    );
  }
}

class _VenueHome extends ConsumerStatefulWidget {
  const _VenueHome();

  @override
  ConsumerState<_VenueHome> createState() => _VenueHomeState();
}

class _VenueHomeState extends ConsumerState<_VenueHome> {
  String _period = 'Pekan';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(venueSlotsProvider);
    final today = slotsOn(all, DateTime.now());
    final booked = today
        .where(
          (s) => s.status == SlotStatus.booked || s.status == SlotStatus.lobby,
        )
        .length;
    final open = today.where((s) => s.status == SlotStatus.open).length;
    final courts = _courtStats(_period == 'Pekan' ? today : _rollup(all, 7));

    return ListView(
      padding: kScreenPad,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 20,
                color: C.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          venueProfile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: C.ink,
                          ),
                        ),
                      ),
                      if (venueProfile.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified, size: 14, color: C.primary),
                      ],
                    ],
                  ),
                  Text(
                    '${venueProfile.city} · ${venueProfile.courts} lapangan',
                    style: T.small,
                  ),
                ],
              ),
            ),
            const Pill(
              'Venue',
              background: C.primarySoft,
              color: C.primaryDeep,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SportPanel(
          gradient: C.primaryPanel,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill(
                'Pendapatan bulan ini',
                color: C.ink,
                background: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                rupiah(venueSummary.revenue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.h1,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _HeroMeta(
                    value: '${venueSummary.bookings}',
                    label: 'Booking',
                  ),
                  _HeroMeta(
                    value: '${(venueSummary.occupancy * 100).round()}%',
                    label: 'Okupansi',
                  ),
                  _HeroMeta(value: '${venueProfile.rating}', label: 'Rating'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.event_available,
                label: 'Buka slot',
                detail: '$open kosong hari ini',
                tint: C.primary,
                onTap: () => showAddSlotSheet(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.payments_outlined,
                label: 'Cairkan',
                detail: rupiah(venueProfile.payout),
                tint: C.primary,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pencairan H+1 setelah check-in.'),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader('Papan okupansi', action: _period, onTap: () {}),
        const SizedBox(height: 10),
        Segmented<String>(
          options: const ['Pekan', 'Bulan'],
          value: _period,
          onChanged: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: 12),
        if (courts.isEmpty)
          Text('Belum ada slot pada periode ini.', style: T.small)
        else
          for (var i = 0; i < courts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RankRow(
                rank: i + 1,
                title: 'Lapangan ${courts[i].court}',
                subtitle: '${courts[i].taken} dari ${courts[i].total} slot',
                value: '${courts[i].percent}%',
                background: switch (i % 4) {
                  0 => C.primarySoft,
                  2 => C.amberSoft,
                  3 => C.primarySoft,
                  _ => C.surface,
                },
                avatars: courts[i].guests,
              ),
            ),
        const SizedBox(height: 14),
        SectionHeader(
          'Jadwal hari ini',
          action: '$booked terisi',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        for (final s in today.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TodayRow(slot: s),
          ),
        if (today.isEmpty)
          Text(
            'Belum ada slot hari ini. Buka slot dari tombol +.',
            style: T.small,
          ),
        const SizedBox(height: 14),
        SurfaceCard(
          radius: 18,
          onTap: () => context.push('/venue/analytics'),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: C.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights, size: 18, color: C.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analytics venue', style: T.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Peak hours, tren pendapatan, okupansi.',
                      style: T.small,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: C.faint),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          radius: 18,
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 17, color: C.amber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Kuota penuh otomatis jadi booking. Tidak ada aksi manual.',
                  style: T.small,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourtStat {
  const _CourtStat({
    required this.court,
    required this.taken,
    required this.total,
    required this.guests,
  });

  final int court;
  final int taken;
  final int total;
  final List<String> guests;

  int get percent => total == 0 ? 0 : (taken / total * 100).round();
}

List<VenueSlot> _rollup(List<VenueSlot> all, int days) {
  final out = <VenueSlot>[];
  for (var i = 0; i < days; i++) {
    out.addAll(slotsOn(all, DateTime.now().add(Duration(days: i))));
  }
  return out;
}

List<_CourtStat> _courtStats(List<VenueSlot> slots) {
  final byCourt = <int, List<VenueSlot>>{};
  for (final s in slots) {
    byCourt.putIfAbsent(s.court, () => []).add(s);
  }
  final stats = [
    for (final entry in byCourt.entries)
      _CourtStat(
        court: entry.key,
        taken: entry.value
            .where(
              (s) =>
                  s.status == SlotStatus.booked || s.status == SlotStatus.lobby,
            )
            .length,
        total: entry.value.length,
        guests: [
          for (final s in entry.value)
            if (s.guest != null) s.guest!,
        ],
      ),
  ]..sort((a, b) => b.percent.compareTo(a.percent));
  return stats;
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.slot});

  final VenueSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTime(slot.start),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: C.ink,
                  ),
                ),
                Text(
                  formatTime(slot.end),
                  style: const TextStyle(fontSize: 12, color: C.faint),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 26, color: C.line),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lapangan ${slot.court}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                Text(
                  slot.guest ?? 'Belum terisi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Pill(
            slot.status.label,
            color: slot.status.color,
            background: slot.status.color.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: C.ink,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: C.ink,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: tint),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: C.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueAccount extends ConsumerWidget {
  const _VenueAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ikut berubah saat profil venue dimuat dari server.
    ref.watch(venueSlotsProvider);
    return ListView(
      padding: kScreenPad,
      children: [
        const Text('Akun venue', style: T.h1),
        const SizedBox(height: 4),
        Text('Terpisah dari akun pemain.', style: T.small),
        const SizedBox(height: 16),
        SportPanel(
          gradient: C.amberPanel,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill(
                'Saldo pencairan',
                color: C.amber,
                background: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 9),
              Text(
                rupiah(venueProfile.payout),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Dicairkan tiap Senin · fee 5%',
                style: TextStyle(fontSize: 12, color: C.amber),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          radius: 18,
          child: Column(
            children: [
              _AccountRow(
                icon: Icons.badge_outlined,
                label: 'Data venue',
                value: '${venueProfile.courts} lapangan',
              ),
              const _AccountRow(
                icon: Icons.schedule,
                label: 'Jam operasional',
                value: '06:00 – 22:00',
              ),
              const _AccountRow(
                icon: Icons.account_balance_outlined,
                label: 'Rekening pencairan',
                value: 'BCA ···4821',
              ),
              const _AccountRow(
                icon: Icons.percent,
                label: 'Fee platform',
                value: '5% per booking',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 18,
          onTap: () => context.push('/venue/analytics'),
          child: Row(
            children: [
              const Icon(Icons.insights, size: 17, color: C.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('Analytics venue', style: T.h3)),
              const Icon(Icons.chevron_right, size: 18, color: C.faint),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 18,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: C.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Akun venue tidak bisa join room. Kelola lapangan dari sini.',
                  style: T.small,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SebarButton(
          label: 'Keluar ke akun pemain',
          icon: Icons.swap_horiz,
          color: C.primary,
          onPressed: () async {
            await ref.read(authProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: C.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.ink,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: C.faint),
        ],
      ),
    );
  }
}
