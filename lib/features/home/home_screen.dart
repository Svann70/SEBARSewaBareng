import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _Greeting(score: me.score),
            const SizedBox(height: 16),
            SportPanel(
              gradient: const [Color(0xFFFF7A93), C.pinkDeep],
              height: 146,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Pill('Saldo tersedia', background: Colors.white24),
                        const SizedBox(height: 10),
                        Text(
                          rupiah(wallet.available),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            height: 1,
                            color: C.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Terkunci ${rupiah(wallet.held)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeroStat(value: '${me.score}', label: 'Skor'),
                      const SizedBox(height: 10),
                      _HeroStat(value: '${bookings.length}', label: 'Tiket'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SportCircles(active: filter.sport),
            const SizedBox(height: 6),
            _CityLine(
              city: filter.city,
              count: lobbies.length,
              onTap: () => _pickCity(context, ref, filter.city),
            ),
            const SizedBox(height: 14),
            SectionHeader(
              'Room tersedia',
              action: 'Kode undangan',
              onTap: () => _enterInviteCode(context, ref),
            ),
            const SizedBox(height: 8),
            if (lobbies.isEmpty)
              EmptyState(
                icon: Icons.groups_outlined,
                title: 'Belum ada room di kotamu',
                message: 'Buat room pertama, lalu bagikan sandinya ke teman.',
                action: GhostButton(
                  label: 'Buat room',
                  icon: Icons.add,
                  onPressed: () => context.push('/create'),
                ),
              )
            else
              for (var i = 0; i < lobbies.length; i++)
                _TimelineRow(
                  lobby: lobbies[i],
                  first: i == 0,
                  last: i == lobbies.length - 1,
                ),
            const SizedBox(height: 10),
            SectionHeader(
              'Tiket berikutnya',
              action: 'Semua',
              onTap: () => context.go('/home'),
            ),
            const SizedBox(height: 10),
            for (final b in bookings.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  radius: 18,
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
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: C.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_2,
                          size: 18,
                          color: C.ink,
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
              visualDensity: VisualDensity.compact,
              title: Text(
                c,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: c == current ? C.pink : C.ink,
                ),
              ),
              trailing: c == current
                  ? const Icon(Icons.check, color: C.pink, size: 18)
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
            child: const Text('Masuk', style: TextStyle(color: C.pink)),
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
              const Text(
                'Halo, Raka',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text('Siap main minggu ini?', style: T.small),
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
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: C.butter,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'R',
            style: TextStyle(
              color: C.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1,
            color: C.ink,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Filter olahraga berbentuk lingkaran — bentuk lain dari chip, supaya
/// halaman tidak monoton kotak.
class _SportCircles extends ConsumerWidget {
  const _SportCircles({this.active});

  final Sport? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(filterProvider.notifier);
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SportCircle(
            label: 'Semua',
            icon: Icons.apps,
            gradient: const [Color(0xFF3A3A48), Color(0xFF23232C)],
            selected: active == null,
            onTap: () => notifier.setSport(null),
          ),
          for (final s in Sport.values)
            _SportCircle(
              label: s.label,
              icon: s.icon,
              gradient: s.gradient,
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
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : C.surface,
                  border: Border.all(color: selected ? Colors.white24 : C.line),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? Colors.white : C.muted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? C.ink : C.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris kota tanpa kotak: hanya pin, nama, dan jumlah room.
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
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: C.pink),
            const SizedBox(width: 6),
            Text(
              city,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· $count room',
              style: const TextStyle(fontSize: 11.5, color: C.faint),
            ),
            const Spacer(),
            const Text(
              'Ubah',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: C.pink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris pada linimasa room: penanda tanggal di kiri, kartu di kanan.
/// Bentuk mengikuti referensi AppDesign3.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.lobby,
    required this.first,
    required this.last,
  });

  final Lobby lobby;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(first: first, last: last),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: first ? C.pink : C.bg,
                      border: Border.all(
                        color: first ? C.pink : C.line,
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${lobby.start.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: first ? Colors.white : C.ink,
                          ),
                        ),
                        Text(
                          formatDate(lobby.start).split(', ').last.split(' ').last,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: first ? Colors.white70 : C.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _RoomRow(lobby: lobby)),
          ],
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.first, required this.last});

  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.line
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const x = 19.0;
    var y = first ? 42.0 : 0.0;
    final end = last ? size.height - 12 : size.height;
    while (y < end) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, end)), paint);
      y += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.first != first || old.last != last;
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    final tint = lobby.sport.gradient.first;
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/lobby/${lobby.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(lobby.sport.icon, size: 19, color: tint),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lobby.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.h3,
                          ),
                        ),
                        if (lobby.access != LobbyAccess.open)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              lobby.access.icon,
                              size: 13,
                              color: C.faint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${lobby.venue} · ${formatTime(lobby.start)}–'
                      '${formatTime(lobby.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.small,
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          rupiah(lobby.pricePerPerson),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: C.ink,
                          ),
                        ),
                        const Text(
                          ' /orang',
                          style: TextStyle(fontSize: 10, color: C.faint),
                        ),
                        const Spacer(),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _QuotaDots(
                              joined: lobby.joined,
                              quota: lobby.quota,
                              full: lobby.isFull,
                            ),
                          ),
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
    );
  }
}

/// Kuota sebagai titik-titik, bukan progress bar — variasi bentuk.
class _QuotaDots extends StatelessWidget {
  const _QuotaDots({
    required this.joined,
    required this.quota,
    required this.full,
  });

  final int joined;
  final int quota;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final color = full ? C.orange : C.green;
    return Row(
      children: [
        for (var i = 0; i < quota.clamp(0, 12); i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < joined ? color : C.line,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          '$joined/$quota',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: C.muted,
          ),
        ),
      ],
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Icon(sport.icon, size: 21, color: tint),
    );
  }
}
