import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Beranda gaya desain "Hijau": sapaan, chip olahraga, room di kotamu,
/// lalu tiket berikutnya. Tanpa panel saldo/grafik — dompet punya layarnya.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final lobbies = ref.watch(filteredLobbiesProvider);
    final bookings = ref.watch(bookingsProvider);
    final user = ref.watch(sessionProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: C.primary,
        backgroundColor: C.surface,
        onRefresh: () async {
          await Future.wait([
            ref.read(bookingsProvider.notifier).refresh(),
            ref.read(lobbiesProvider.notifier).refresh(),
            ref.read(notificationsProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: kScreenPad,
          children: [
            _Greeting(
              name: user?.fullName ?? 'Raka',
              onCommunity: () => context.push('/community'),
              unread: ref.watch(notificationsProvider).unread,
              onNotifications: () => context.push('/notifications'),
            ),
            const SizedBox(height: 14),
            const FadeSlideIn(child: _PromoCarousel()),
            const SizedBox(height: 14),
            _SportChips(
              active: filter.sport,
              onSelect: (sport) =>
                  ref.read(filterProvider.notifier).setSport(sport),
            ),
            const SizedBox(height: 10),
            _CityLine(
              city: filter.city,
              onTap: () => _pickCity(context, ref, filter.city),
            ),
            const SizedBox(height: 14),
            SectionHeader(
              'Room di ${filter.city == 'Semua kota' ? 'sekitarmu' : filter.city}',
              action: 'Lihat semua',
              onTap: () => context.push('/rooms'),
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
              for (final (i, lobby) in lobbies.take(4).indexed)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RoomCard(
                      sport: lobby.sport.label,
                      title: lobby.title,
                      when:
                          '${formatDate(lobby.start)} · '
                          '${formatTime(lobby.start)}–${formatTime(lobby.end)}',
                      place: '${lobby.venue} · ${lobby.court}',
                      pricePerPerson: lobby.pricePerPerson,
                      members: [for (final m in lobby.members) m.name],
                      joined: lobby.joined,
                      quota: lobby.quota,
                      access: lobby.access.label.toUpperCase(),
                      onTap: () => context.push('/lobby/${lobby.id}'),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            SectionHeader(
              'Tiket berikutnya',
              action: 'Semua tiket',
              onTap: () => context.push('/tickets'),
            ),
            const SizedBox(height: 8),
            if (bookings.isEmpty)
              const EmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'Belum ada tiket',
                message: 'Tiket terbit otomatis saat kuota room terpenuhi.',
              )
            else
              for (final (i, b) in bookings.take(2).indexed)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TicketTile(
                      day: const [
                        'Sen',
                        'Sel',
                        'Rab',
                        'Kam',
                        'Jum',
                        'Sab',
                        'Min',
                      ][b.start.weekday - 1],
                      date: '${b.start.day}',
                      month: const [
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
                      ][b.start.month - 1],
                      title: b.title,
                      when: '${formatTime(b.start)} · ${b.court}',
                      place: b.venue,
                      onTap: () => context.push('/ticket/${b.id}'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final cities = <String>[
      'Semua kota',
      ...{for (final v in ref.read(venuesProvider)) v.city},
      if (ref.read(venuesProvider).isEmpty) ...{for (final v in venues) v.city},
    ];
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
                  fontWeight: c == current ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                  color: c == current ? C.primary : C.ink,
                ),
              ),
              trailing: c == current
                  ? const Icon(Icons.check, color: C.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (picked != null) ref.read(filterProvider.notifier).setCity(picked);
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.onCommunity,
    required this.unread,
    required this.onNotifications,
  });

  final String name;
  final VoidCallback onCommunity;
  final int unread;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hai, $name', style: T.h1),
              const SizedBox(height: 2),
              Text(formatLongDate(DateTime.now()), style: T.small),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: unread > 0 ? '$unread notifikasi baru' : 'Notifikasi',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(
              Icons.notifications_none,
              size: 21,
              color: C.faint,
            ),
          ),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onCommunity,
          icon: const Icon(Icons.forum_outlined, size: 20, color: C.faint),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 2),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: C.primarySoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: C.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

/// Banner promo geser manual. Tanpa timer supaya `pumpAndSettle` di tes
/// tidak menunggu animasi tanpa henti.
/// ponytail: autoplay dilewati; tambah kalau benar-benar diminta.
class _PromoCarouselState extends State<_PromoCarousel> {
  static const _promos = [
    _Promo(
      'PROMO',
      'Jam pagi diskon 20%',
      'Badminton & futsal · 06.00–09.00',
      Icons.wb_sunny_outlined,
      [Color(0xFFFFF1D6), Color(0xFFFFE1A8)],
      C.ink,
      '/rooms',
    ),
    _Promo(
      'EVENT',
      'Sparring komunitas Sabtu',
      'Cari lawan, isi slot kosong di sekitarmu',
      Icons.emoji_events_outlined,
      C.primaryPanel,
      C.ink,
      '/community',
    ),
    _Promo(
      'GRATIS',
      'Ajak 3 teman, kamu gratis',
      'Otomatis aktif saat room penuh',
      Icons.card_giftcard,
      C.inkPanel,
      Colors.white,
      '/create',
    ),
  ];

  final _controller = PageController(viewportFraction: 0.94);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PromoCard(
                promo: _promos[i],
                onTap: () => context.push(_promos[i].route),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _promos.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? C.primaryFill : C.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Promo {
  const _Promo(
    this.tag,
    this.title,
    this.subtitle,
    this.icon,
    this.colors,
    this.foreground,
    this.route,
  );

  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color foreground;
  final String route;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.onTap});

  final _Promo promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: promo.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  right: -14,
                  bottom: -22,
                  child: Icon(
                    promo.icon,
                    size: 132,
                    color: promo.foreground.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: promo.foreground.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          promo.tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: promo.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        promo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.5,
                          color: promo.foreground,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              promo.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: promo.foreground.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: promo.foreground,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportChips extends ConsumerWidget {
  const _SportChips({this.active, required this.onSelect});

  final Sport? active;
  final ValueChanged<Sport?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <(String, Sport?)>[
      ('Semua', null),
      for (final sport in Sport.values) (sport.label, sport),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, sport) = items[i];
          final selected = sport == active;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(selected ? null : sport);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? C.primaryFill : C.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? C.primaryFill : C.line),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? C.ink : C.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityLine extends StatelessWidget {
  const _CityLine({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: C.primary),
            const SizedBox(width: 5),
            Text(
              city,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.ink,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, size: 16, color: C.faint),
          ],
        ),
      ),
    );
  }
}
