import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Daftar lengkap room. Home hanya menampilkan sebagian; di sini semua room
/// dikelompokkan per tanggal + bisa dicari dan disaring, karena scroll kartu
/// saja tidak cukup saat room sudah puluhan.
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(filterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final lobbies = ref.watch(filteredLobbiesProvider);

    final groups = <String, List<Lobby>>{};
    for (final lobby in lobbies) {
      groups.putIfAbsent(_dayLabel(lobby.start), () => []).add(lobby);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: kScreenPadTop.copyWith(bottom: 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 4),
            const RoundBackHeader(title: 'Semua room'),
            const SizedBox(height: 14),
            SearchField(
              controller: _search,
              hint: 'Cari room, venue, atau kota',
              onChanged: (value) =>
                  ref.read(filterProvider.notifier).setQuery(value),
            ),
            const SizedBox(height: 14),
            _SportChips(
              selected: filter.sport,
              onSelect: (sport) =>
                  ref.read(filterProvider.notifier).setSport(sport),
            ),
            const SizedBox(height: 10),
            _CityRow(
              city: filter.city,
              onTap: () => _pickCity(context, ref, filter.city),
            ),
            const SizedBox(height: 16),
            Text(
              lobbies.isEmpty
                  ? 'Tidak ada room yang cocok'
                  : '${lobbies.length} room · '
                        '${groups.length} tanggal',
              style: T.small,
            ),
            const SizedBox(height: 10),
            if (lobbies.isEmpty)
              EmptyState(
                icon: Icons.search_off,
                title: 'Room tidak ditemukan',
                message: filter.query.isEmpty
                    ? 'Coba ubah filter olahraga atau kota.'
                    : 'Coba kata kunci lain atau kosongkan pencarian.',
                action: GhostButton(
                  label: 'Bersihkan filter',
                  icon: Icons.filter_alt_off_outlined,
                  onPressed: () {
                    _search.clear();
                    ref.read(filterProvider.notifier).setQuery('');
                    ref.read(filterProvider.notifier).setSport(null);
                    ref.read(filterProvider.notifier).setCity('Semua kota');
                  },
                ),
              )
            else
              for (final entry in groups.entries) ...[
                SectionHeader(entry.key),
                const SizedBox(height: 8),
                for (final lobby in entry.value)
                  Padding(
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
              ],
          ],
        ),
      ),
    );
  }

  static String _dayLabel(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    return switch (day.difference(today).inDays) {
      0 => 'Hari ini',
      1 => 'Besok',
      _ => formatLongDate(start),
    };
  }

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    String city,
  ) async {
    final cities = <String>[
      'Semua kota',
      ...{for (final v in venues) v.city},
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SheetWrap(
        title: 'Pilih kota',
        children: [
          for (final value in cities)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                radius: 16,
                onTap: () => Navigator.pop(sheetContext, value),
                child: Row(
                  children: [
                    Icon(
                      value == city
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: value == city ? C.primary : C.faint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    ref.read(filterProvider.notifier).setCity(picked);
  }
}

class _SportChips extends StatelessWidget {
  const _SportChips({required this.selected, required this.onSelect});

  final Sport? selected;
  final ValueChanged<Sport?> onSelect;

  @override
  Widget build(BuildContext context) {
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
          final active = sport == selected;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(sport);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? C.primaryFill : C.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? C.primaryFill : C.line),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? C.ink : C.muted,
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

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.primarySoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: C.primary),
              const SizedBox(width: 7),
              Text(
                city,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.primary,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.expand_more, size: 16, color: C.primary),
            ],
          ),
        ),
      ),
    );
  }
}
