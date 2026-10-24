import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';
import 'venue_tabs.dart';

/// Shell akun venue: akun terpisah dari pemain, dock sendiri.
/// Pemilik menambah lapangan sekali; tab lain hanya untuk memantau.
class VenueShell extends StatefulWidget {
  const VenueShell({super.key});

  @override
  State<VenueShell> createState() => _VenueShellState();
}

class _VenueShellState extends State<VenueShell> {
  int _index = 0;

  static const _pages = [
    _VenueHome(),
    VenueScheduleTab(),
    VenueScanTab(),
    _VenueCourts(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Struktur anak tetap (bug Flutter 3.41 semantics parentDataDirty
            // saat tukar tipe/jumlah child runtime); toggle via Offstage.
            for (var i = 0; i < _pages.length; i++)
              Offstage(
                offstage: _index != i,
                child: RepaintBoundary(child: _pages[i]),
              ),
          ],
        ),
      ),
      bottomNavigationBar: DockNav(
        index: _index,
        items: DockNav.venueDock,
        centerIcon: Icons.add,
        centerLabel: 'Tambah lapangan',
        onSelect: (i) => setState(() => _index = i),
        onCreate: () => context.push('/venue/court/new'),
      ),
    );
  }
}

/// Header nama venue, dipakai beranda dan tab lapangan.
class _VenueTitle extends StatelessWidget {
  const _VenueTitle({required this.venue});

  final ApiVenue? venue;

  @override
  Widget build(BuildContext context) {
    final active = venue?.courts.where((c) => c.active).length ?? 0;
    return Row(
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
              Text(
                venue?.name ?? 'Venue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: C.ink,
                ),
              ),
              Text(
                '${venue?.city ?? ''} · $active lapangan aktif',
                style: T.small,
              ),
            ],
          ),
        ),
        const Pill('Venue', background: C.primarySoft, color: C.primaryDeep),
      ],
    );
  }
}

/// Ajakan untuk GOR yang belum punya lapangan aktif.
class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sports_score, size: 28, color: C.primary),
          const SizedBox(height: 10),
          const Text('Tambah lapangan dulu', style: T.h2),
          const SizedBox(height: 6),
          Text(
            'Isi sekali: olahraga, kapasitas, harga per jam, dan jam buka. '
            'Setelah itu pemain bisa langsung memesan, kamu tinggal memantau.',
            style: T.small,
          ),
          const SizedBox(height: 14),
          SebarButton(
            label: 'Tambah lapangan',
            icon: Icons.add,
            onPressed: () => context.push('/venue/court/new'),
          ),
        ],
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
  @override
  void initState() {
    super.initState();
    // Shell venue membangun semua tab sekaligus; kalau refresh awal saat
    // login gagal, beranda ikut memuat ulang dan memberi tahu pengguna.
    Future.microtask(() {
      final notifier = ref.read(venueSlotsProvider.notifier);
      if (!notifier.hasVenue) {
        notifier.refresh().then((error) {
          if (!mounted || error == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data venue gagal dimuat: $error')),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(venueSlotsProvider);
    final notifier = ref.read(venueSlotsProvider.notifier);
    final venue = notifier.venue;
    final hasActive = venue?.courts.any((c) => c.active) ?? false;
    final today = wibToday();
    final grid = ref.watch(venueDayProvider(today));
    final bookings = [
      for (final s in slotsOn(all, today))
        if (s.status == SlotStatus.lobby || s.status == SlotStatus.booked) s,
    ];

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPad,
        children: [
          _VenueTitle(venue: venue),
          const SizedBox(height: 16),
          if (notifier.isLoading && venue == null)
            const Center(child: CircularProgressIndicator())
          else if (venue == null && notifier.lastError != null)
            // Gagal muat bukan berarti belum punya lapangan.
            EmptyState(
              icon: Icons.cloud_off,
              title: 'Data venue gagal dimuat',
              message: notifier.lastError!,
              action: GhostButton(
                label: 'Muat ulang',
                icon: Icons.refresh,
                onPressed: notifier.refresh,
              ),
            )
          else if (!hasActive)
            const _SetupPrompt()
          else ...[
            grid.when(
              skipLoadingOnReload: true,
              data: (courts) => _TodaySummary(courts: courts),
              loading: () => const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(apiMessage(e), style: T.small),
            ),
            const SizedBox(height: 20),
            SectionHeader('Pemesanan hari ini', action: '${bookings.length}'),
            const SizedBox(height: 10),
            if (bookings.isEmpty)
              Text(
                'Belum ada pemesanan hari ini. Pemain bisa memesan jam yang '
                'masih kosong.',
                style: T.small,
              )
            else
              for (final s in bookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BookingRow(slot: s),
                ),
          ],
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.courts});

  final List<CourtDay> courts;

  @override
  Widget build(BuildContext context) {
    final open = courts.fold<int>(0, (n, c) => n + c.hours.length);
    final taken = courts.fold<int>(0, (n, c) => n + c.taken);
    final income = courts.fold<int>(0, (n, c) => n + c.taken * c.rate);
    return SportPanel(
      gradient: C.primaryPanel,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Pill(
            'Hari ini',
            color: C.ink,
            background: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text('$taken dari $open jam terisi', style: T.h1),
          const SizedBox(height: 6),
          Text(
            'Perkiraan pemasukan ${rupiah(income)}',
            style: const TextStyle(fontSize: 13, color: C.ink),
          ),
          const SizedBox(height: 10),
          for (final c in courts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.court.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: C.ink),
                    ),
                  ),
                  Text(
                    '${c.taken}/${c.hours.length} jam',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.slot});

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
                  formatTime(wib(slot.start)),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: C.ink,
                  ),
                ),
                Text(
                  formatTime(wib(slot.end)),
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
                  slot.courtName ?? 'Lapangan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                Text(
                  slot.guest ?? 'Room aktif',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Pill(
            slot.status == SlotStatus.booked ? 'Terbooking' : 'Room berjalan',
            color: slot.status.color,
            background: slot.status.color.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

/// Tab Lapangan: daftar lapangan; menu ⋮ tiap lapangan untuk on/off dan edit.
class _VenueCourts extends ConsumerWidget {
  const _VenueCourts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(venueSlotsProvider);
    final venue = ref.read(venueSlotsProvider.notifier).venue;
    final courts = venue?.courts ?? const <ApiCourt>[];
    return ListView(
      padding: kScreenPad,
      children: [
        _VenueTitle(venue: venue),
        if (venue != null && venue.address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(venue.address, style: T.small),
        ],
        const SizedBox(height: 16),
        if (courts.isEmpty)
          const _SetupPrompt()
        else ...[
          for (final c in courts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CourtSummary(court: c),
            ),
          const SizedBox(height: 4),
          GhostButton(
            label: 'Tambah lapangan',
            icon: Icons.add,
            onPressed: () => context.push('/venue/court/new'),
          ),
        ],
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 18,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: C.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Lapangan nonaktif tidak tampil ke pemain dan tidak bisa '
                  'dipesan. Akun venue tidak bisa join room.',
                  style: T.small,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GhostButton(
          label: 'Keluar',
          icon: Icons.logout,
          color: C.danger,
          onPressed: () async {
            await ref.read(authProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}

enum _CourtAction { toggle, edit }

class _CourtSummary extends ConsumerWidget {
  const _CourtSummary({required this.court});

  final ApiCourt court;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _CourtAction a,
  ) async {
    switch (a) {
      case _CourtAction.edit:
        context.push('/venue/court/${court.id}');
      case _CourtAction.toggle:
        final on = !court.active;
        final error = await ref
            .read(venueSlotsProvider.notifier)
            .setCourtActive(court, on);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ??
                  (on
                      ? '${court.name} aktif. Pemain bisa memesan.'
                      : '${court.name} nonaktif. Tidak tampil ke pemain.'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String hh(int h) => '${h.toString().padLeft(2, '0')}:00';
    final weekend = court.priceWeekend;
    return SurfaceCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 14),
      color: court.active ? null : C.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  court.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.h3,
                ),
              ),
              Pill(
                court.active ? 'Aktif' : 'Nonaktif',
                color: court.active ? C.primaryDeep : C.muted,
                background: court.active ? C.primarySoft : C.surface,
              ),
              PopupMenuButton<_CourtAction>(
                tooltip: 'Menu ${court.name}',
                icon: const Icon(Icons.more_vert, color: C.muted),
                onSelected: (a) => _onAction(context, ref, a),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _CourtAction.toggle,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        court.active
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined,
                      ),
                      title: Text(court.active ? 'Nonaktifkan' : 'Aktifkan'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CourtAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    for (final s in court.allSports)
                      '${s.sport.label} ${s.capacity}',
                  ].join(' · '),
                  style: T.small,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sen–Jum ${rupiah(court.pricePerHour)}/jam'
                  '${weekend == null ? '' : ' · Sab–Min ${rupiah(weekend)}/jam'}'
                  ' · ${hh(court.openHour)}–${hh(court.closeHour)}',
                  style: T.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
