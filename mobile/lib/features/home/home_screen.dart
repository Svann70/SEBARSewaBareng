import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final filter = ref.watch(filterProvider);
    final lobbies = ref.watch(filteredLobbiesProvider);
    final bookings = ref.watch(bookingsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: C.pink,
        backgroundColor: C.surface,
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: kScreenPad,
          children: [
            _Greeting(score: me.score),
            const SizedBox(height: 16),
            SearchField(
              controller: _search,
              onChanged: (value) =>
                  ref.read(filterProvider.notifier).setQuery(value),
            ),
            const SizedBox(height: 16),
            _SaldoPanel(wallet: wallet, bookings: bookings.length),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CountCard(
                    icon: Icons.groups_outlined,
                    value: '${lobbies.length}',
                    label: 'Room',
                    color: C.teal,
                    tint: C.tealSoft,
                  ),
                ),
                Expanded(
                  child: CountCard(
                    icon: Icons.confirmation_number_outlined,
                    value: '${bookings.length}',
                    label: 'Tiket',
                    color: C.pink,
                    tint: C.pinkSoft,
                  ),
                ),
                Expanded(
                  child: CountCard(
                    icon: Icons.emoji_events_outlined,
                    value: '${me.score}',
                    label: 'Skor',
                    color: C.amber,
                    tint: C.amberSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TrendChartCard(
              title: 'Progres skor',
              subtitle: '6 bulan terakhir',
              headline: '${me.score}%',
              badge: '+22 poin',
              values: [
                for (final n in [78, 84, 80, 88, 90, me.score]) n.toDouble(),
              ],
              labels: const ['Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt'],
            ),
            const SizedBox(height: 18),
            _SportCircles(active: filter.sport),
            const SizedBox(height: 6),
            _CityLine(
              city: filter.city,
              count: lobbies.length,
              onTap: () => _pickCity(context, ref, filter.city),
            ),
            const SizedBox(height: 12),
            SectionHeader(
              'Room tersedia',
              action: 'Kode undangan',
              onTap: () => _enterInviteCode(context, ref),
            ),
            const SizedBox(height: 8),
            if (lobbies.isEmpty)
              EmptyState(
                icon: Icons.groups_outlined,
                title: filter.query.isEmpty
                    ? 'Belum ada room di kotamu'
                    : 'Room tidak ditemukan',
                message: filter.query.isEmpty
                    ? 'Buat room pertama, lalu bagikan sandinya ke teman.'
                    : 'Coba kata kunci lain atau ubah filter olahraga.',
                action: GhostButton(
                  label: 'Buat room',
                  icon: Icons.add,
                  onPressed: () => context.push('/create'),
                ),
              )
            else
              for (var i = 0; i < lobbies.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RankRow(
                    rank: i + 1,
                    title: lobbies[i].title,
                    subtitle:
                        '${lobbies[i].venue} · '
                        '${formatTime(lobbies[i].start)}–'
                        '${formatTime(lobbies[i].end)}',
                    value: lobbies[i].isFull
                        ? 'Penuh'
                        : '${lobbies[i].remaining} slot',
                    background: _roomTint(i),
                    avatars: [for (final m in lobbies[i].members) m.name],
                    onTap: () => context.push('/lobby/${lobbies[i].id}'),
                  ),
                ),
            const SizedBox(height: 12),
            SectionHeader(
              'Tiket berikutnya',
              action: 'Semua',
              onTap: () => context.go('/home'),
            ),
            const SizedBox(height: 10),
            if (bookings.isEmpty)
              const EmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'Belum ada tiket',
                message: 'Tiket terbit otomatis saat kuota room terpenuhi.',
              )
            else
              for (final b in bookings.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    radius: 22,
                    onTap: () => context.push('/ticket/${b.id}'),
                    child: Row(
                      children: [
                        _SportAvatar(sport: b.sport),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.h3,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${b.venue} · ${formatDate(b.start)} '
                                '${formatTime(b.start)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.small,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: C.pinkSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            size: 20,
                            color: C.pinkDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static Color _roomTint(int i) => switch (i % 4) {
    0 => C.pinkSoft,
    2 => C.amberSoft,
    3 => C.tealSoft,
    _ => C.surface,
  };

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    const cities = ['Semua kota', 'Bandung', 'Jakarta', 'Surabaya'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SheetWrap(
        title: 'Pilih kota',
        children: [
          for (final c in cities)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                c,
                style: TextStyle(
                  fontWeight: c == current ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                  color: c == current ? C.pink : C.ink,
                ),
              ),
              trailing: c == current
                  ? const Icon(Icons.check_circle, color: C.pink, size: 20)
                  : null,
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (picked != null) ref.read(filterProvider.notifier).setCity(picked);
  }

  Future<void> _enterInviteCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final all = ref.read(lobbiesProvider);
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masuk dengan kode', style: T.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kode undangan dibagikan host lewat link room.',
              style: T.small,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'VOLI-SORE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Masuk'),
          ),
        ],
      ),
    );
    if (code == null || !context.mounted) return;
    final lobby = lobbyByInviteCode(all, code);
    if (lobby == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode undangan tidak ditemukan.')),
      );
      return;
    }
    context.push('/lobby/${lobby.id}');
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hai, Raka', style: T.h1),
              const SizedBox(height: 2),
              Text(formatLongDate(DateTime.now()), style: T.small),
            ],
          ),
        ),
        ScoreBadge(score),
        const SizedBox(width: 8),
        CircleIconButton(
          icon: Icons.forum_outlined,
          badge: true,
          onTap: () => context.push('/community'),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: C.pinkFill,
            shape: BoxShape.circle,
            border: Border.all(color: C.surface, width: 3),
            boxShadow: C.cardShadow,
          ),
          alignment: Alignment.center,
          child: const Text(
            'R',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel saldo pink pekat — teks putih aman (kontras ≥ 4,8:1).
class _SaldoPanel extends StatelessWidget {
  const _SaldoPanel({required this.wallet, required this.bookings});

  final Wallet wallet;
  final int bookings;

  @override
  Widget build(BuildContext context) {
    return SportPanel(
      gradient: C.pinkPanel,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(
                    'Saldo tersedia',
                    color: Colors.white,
                    background: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DarkPillButton(
                label: 'Top up',
                icon: Icons.add,
                height: 38,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Buka tab Dompet untuk top up.'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rupiah(wallet.available),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.numberLg.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMeta(value: rupiah(wallet.held), label: 'Terkunci'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HeroMeta(value: '$bookings', label: 'Tiket aktif'),
              ),
            ],
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
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter olahraga berbentuk lingkaran.
class _SportCircles extends ConsumerWidget {
  const _SportCircles({this.active});

  final Sport? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(filterProvider.notifier);
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SportCircle(
            label: 'Semua',
            icon: Icons.grid_view_rounded,
            color: C.tealFill,
            selected: active == null,
            onTap: () => notifier.setSport(null),
          ),
          for (final s in Sport.values)
            _SportCircle(
              label: s.label,
              icon: s.icon,
              color: s.gradient.first,
              selected: active == s,
              onTap: () => notifier.setSport(active == s ? null : s),
            ),
        ],
      ),
    );
  }
}

class _SportCircle extends StatelessWidget {
  const _SportCircle({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : C.surface,
                  border: Border.all(
                    color: selected ? color : C.line,
                    width: selected ? 0 : 1,
                  ),
                  boxShadow: selected ? C.cardShadow : null,
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? C.ink : C.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris kota: pin, nama, jumlah room, aksi ubah.
class _CityLine extends StatelessWidget {
  const _CityLine({
    required this.city,
    required this.count,
    required this.onTap,
  });

  final String city;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: C.pink),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: C.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '· $count room',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.caption,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ubah',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: C.pink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportAvatar extends StatelessWidget {
  const _SportAvatar({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final tint = sport.gradient.first;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: Icon(sport.icon, size: 22, color: tint),
    );
  }
}
