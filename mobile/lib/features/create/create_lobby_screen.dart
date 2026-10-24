import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Buat room 3 langkah mengikuti referensi desain:
/// 1) pilih venue, 2) pilih tanggal + slot, 3) atur room.
///
/// Slot tetap dipilih dari server, jadi room tidak mungkin dibuat untuk jam
/// yang belum dibuka venue. Ringkasan harga dan tombol ada di footer tetap.
class CreateLobbyScreen extends ConsumerStatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  ConsumerState<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends ConsumerState<CreateLobbyScreen> {
  final _title = TextEditingController();
  final _search = TextEditingController();

  int _step = 0;
  DateTime _date = DateTime.now();
  String? _venueId;
  String? _courtId;
  String? _slotId;
  int _quota = 8;
  List<ApiSlot> _slots = const [];
  bool _loadingSlots = false;
  bool _busy = false;
  Sport? _sport;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(venuesProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    super.dispose();
  }

  ApiVenue? _venueOf(List<ApiVenue> list) {
    for (final v in list) {
      if (v.id == _venueId) return v;
    }
    return null;
  }

  ApiCourt? _courtOf(ApiVenue? venue) {
    if (venue == null) return null;
    for (final c in venue.courts) {
      if (c.id == _courtId) return c;
    }
    return venue.courts.isEmpty ? null : venue.courts.first;
  }

  ApiSlot? get _slot {
    for (final s in _slots) {
      if (s.id == _slotId) return s;
    }
    return null;
  }

  int get _capacity =>
      (_courtOf(_venueOf(ref.read(venuesProvider)))?.capacity.clamp(2, 30)) ??
      8;

  Future<void> _loadSlots() async {
    final venue = _venueOf(ref.read(venuesProvider));
    if (venue == null) return;
    setState(() => _loadingSlots = true);
    final slots = await ref
        .read(venuesProvider.notifier)
        .slots(venue.id, _date);
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loadingSlots = false;
      _slotId = null;
    });
  }

  void _pickVenue(ApiVenue venue) {
    if (venue.id.startsWith('seed-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venue ini hanya contoh. Pilih venue dari server.'),
        ),
      );
      return;
    }
    final court = venue.courts.isEmpty ? null : venue.courts.first;
    setState(() {
      _venueId = venue.id;
      _courtId = court?.id;
      _quota = court == null ? 8 : court.capacity.clamp(2, 30);
      _title.clear();
      _step = 1;
    });
    _loadSlots();
  }

  Future<void> _pickDay(DateTime day) async {
    setState(() => _date = day);
    await _loadSlots();
  }

  void _pickSlot(ApiSlot slot) {
    setState(() {
      _slotId = slot.id;
      _courtId = slot.courtId;
      if (_title.text.trim().isEmpty) {
        _title.text = '${slot.sport.label} ${_dayName(slot.start)}';
      }
    });
  }

  Future<void> _pickQuota(int maxQuota, int price) async {
    var value = _quota.clamp(2, maxQuota);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Jumlah orang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value orang', style: T.h2),
              Slider(
                value: value.toDouble(),
                min: 2,
                max: maxQuota.toDouble(),
                divisions: maxQuota > 2 ? maxQuota - 2 : null,
                onChanged: (v) => setLocal(() => value = v.round()),
              ),
              Text(
                'Harga per orang ${_shortRupiah(pricePerPerson(price, value))}',
                style: T.caption,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _quota = picked);
  }

  Future<void> _submit(ApiSlot slot) async {
    if (_busy) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama room wajib diisi.')));
      return;
    }
    setState(() => _busy = true);
    final error = await ref
        .read(lobbiesProvider.notifier)
        .createRemote(
          slotId: slot.id,
          title: _title.text.trim(),
          quota: _quota,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final perPerson = pricePerPerson(slot.price, _quota);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Room dibuat. ${rupiah(perPerson)} dikunci sebagai host.',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venuesProvider);
    final venue = _venueOf(venues);
    final slot = _slot;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: switch (_step) {
                0 => _venueStep(venues),
                1 => venue == null ? _venueStep(venues) : _slotStep(venue),
                _ =>
                  venue == null ? _venueStep(venues) : _detailStep(venue, slot),
              },
            ),
            if (_step == 1 && venue != null) _slotFooter(slot),
            if (_step == 2 && venue != null && slot != null)
              _detailFooter(slot),
          ],
        ),
      ),
    );
  }

  // ── Langkah 1: venue ─────────────────────────────────────────────────────

  Widget _venueStep(List<ApiVenue> venues) {
    final query = _search.text.trim().toLowerCase();
    final list = [
      for (final v in venues)
        if ((_sport == null ||
                v.courts.any((c) => c.sport == _sport) ||
                v.courts.isEmpty) &&
            (query.isEmpty ||
                v.name.toLowerCase().contains(query) ||
                v.city.toLowerCase().contains(query)))
          v,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _StepHeader(
          step: 0,
          title: 'Pilih venue',
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        const SizedBox(height: 14),
        SearchField(
          controller: _search,
          hint: 'Cari venue atau daerah',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _SportFilter(
          active: _sport,
          onSelect: (sport) => setState(() => _sport = sport),
        ),
        const SizedBox(height: 16),
        Text('${list.length} venue', style: T.label),
        const SizedBox(height: 4),
        if (list.isEmpty)
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'Venue tidak ditemukan',
            message: 'Coba kata kunci lain atau ganti cabang olahraga.',
          )
        else
          for (final venue in list) _VenueRow(venue: venue, onTap: _pickVenue),
      ],
    );
  }

  // ── Langkah 2: tanggal & slot ────────────────────────────────────────────

  Widget _slotStep(ApiVenue venue) {
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(_date.year, _date.month, _date.day).add(Duration(days: i)),
    ];
    final hours = <int>{for (final s in _slots) s.start.hour}.toList()..sort();
    final courts = venue.courts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          step: 1,
          title: venue.name,
          onBack: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = days[i];
              final active =
                  day.day == _date.day &&
                  day.month == _date.month &&
                  day.year == _date.year;
              return _DayChip(
                day: day,
                active: active,
                onTap: () => _pickDay(day),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (courts.isEmpty)
          const EmptyState(
            icon: Icons.stadium_outlined,
            title: 'Belum ada lapangan',
            message: 'Venue ini belum membuka lapangan untuk dipesan.',
          )
        else ...[
          if (_slots.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Belum ada slot',
              message: 'Pilih tanggal lain atau minta venue membuka slot.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      for (final court in courts)
                        SizedBox(
                          width: 96,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  court.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: C.ink,
                                  ),
                                ),
                                Text(
                                  '${_shortRupiah(court.pricePerHour)}/jam',
                                  style: T.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 1, color: C.line),
                  for (final hour in hours)
                    _SlotRow(
                      hour: hour,
                      courts: courts,
                      slots: _slots,
                      selectedId: _slotId,
                      onPick: _pickSlot,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ],
    );
  }

  // ── Langkah 3: atur room ─────────────────────────────────────────────────

  Widget _detailStep(ApiVenue venue, ApiSlot? slot) {
    final court = _courtOf(venue);
    final price = slot?.price ?? 0;
    final capacity = _capacity;
    final options = [
      for (final value in const [4, 6, 8])
        if (value <= capacity) value,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _StepHeader(
          step: 2,
          title: 'Atur room',
          onBack: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 14),
        if (slot != null)
          _VenueSummary(
            venue: venue,
            court: court,
            slot: slot,
            onChange: () => setState(() => _step = 1),
          ),
        const SizedBox(height: 22),
        const _Label('Nama room'),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: C.ink,
          ),
          decoration: const InputDecoration(
            hintText: 'Badminton Sabtu Pagi',
            prefixIcon: Icon(Icons.edit_outlined, size: 19, color: C.muted),
          ),
        ),
        const SizedBox(height: 22),
        const _Label('Jumlah orang'),
        const SizedBox(height: 4),
        const Text(
          'Termasuk kamu. Harga per orang ikut berubah.',
          style: T.small,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final value in [...options, 0])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: value == 0 ? 0 : 8),
                  child: _QuotaChip(
                    value: value == 0 ? null : value,
                    total: _quota,
                    capacity: capacity,
                    pricePerPerson: slot == null
                        ? 0
                        : pricePerPerson(price, value == 0 ? _quota : value),
                    onTap: () => value == 0
                        ? _pickQuota(capacity, price)
                        : setState(() => _quota = value),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const _Label('Siapa yang bisa join'),
        const SizedBox(height: 6),
        for (final access in LobbyAccess.values)
          _AccessRow(
            access: access,
            selected: access == LobbyAccess.open,
            enabled: access == LobbyAccess.open,
            onTap: () {},
          ),
        const SizedBox(height: 22),
        const _Label('Batas kumpul'),
        const SizedBox(height: 8),
        _DeadlineBox(slot: slot),
        const SizedBox(height: 8),
        const Text(
          'Kalau absen belum penuh, room batal dan semua dana dilepas.',
          style: T.caption,
        ),
      ],
    );
  }

  // ── Footer tetap ─────────────────────────────────────────────────────────

  Widget _slotFooter(ApiSlot? slot) {
    final court = _courtOf(_venueOf(ref.read(venuesProvider)));
    return _FooterBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot == null
                      ? 'Pilih slot dulu'
                      : '${court?.name ?? slot.courtName} · '
                            '${formatTime(slot.start)}–${formatTime(slot.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot == null
                      ? 'Ketuk kotak kosong di jadwal'
                      : '${formatDate(slot.start)} · '
                            '${_duration(slot)} · ${rupiah(slot.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 118,
            child: SebarButton(
              label: 'Lanjut',
              height: 48,
              radius: 999,
              onPressed: slot == null ? null : () => setState(() => _step = 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailFooter(ApiSlot slot) {
    final price = slot.price;
    final perPerson = pricePerPerson(price, _quota);
    return _FooterBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${rupiah(price)} ÷ $_quota orang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.caption,
                ),
              ),
              Text(
                rupiah(perPerson),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1,
                  color: C.ink,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 2),
                child: Text('/orang', style: T.caption),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SebarButton(
            label: _busy
                ? 'Membuat room…'
                : 'Buat room • kunci ${rupiah(perPerson)}',
            height: 50,
            radius: 999,
            busy: _busy,
            onPressed: _busy ? null : () => _submit(slot),
          ),
        ],
      ),
    );
  }
}

// ── Bagian tampilan ────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.onBack,
  });

  final int step;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleIconButton(
              icon: step == 0 ? Icons.close : Icons.arrow_back,
              tooltip: step == 0 ? 'Tutup' : 'Kembali',
              onTap: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.h1.copyWith(fontSize: 21),
                  ),
                  Text(
                    'Buat room • langkah ${step + 1} dari 3',
                    style: T.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= step ? C.primaryFill : C.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SportFilter extends StatelessWidget {
  const _SportFilter({required this.active, required this.onSelect});

  final Sport? active;
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
          final selected = sport == active;
          return Material(
            color: selected ? C.primarySoft : C.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelect(sport),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? C.primaryCheck : C.line),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? C.primaryDeep : C.muted,
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

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue, required this.onTap});

  final ApiVenue venue;
  final ValueChanged<ApiVenue> onTap;

  @override
  Widget build(BuildContext context) {
    final prices = [for (final c in venue.courts) c.pricePerHour];
    final min = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
    final max = prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b);
    final range = prices.isEmpty
        ? 'Belum ada lapangan'
        : min == max
        ? '${_shortRupiah(min)}/jam'
        : '${_shortRupiah(min)}–${_shortRupiah(max)}/jam';

    return InkWell(
      onTap: () => onTap(venue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: C.primaryFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stadium_outlined, color: C.ink, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.city} · ${venue.courts.length} lapangan',
                    style: T.small,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: C.faint),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.active,
    required this.onTap,
  });

  final DateTime day;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? C.primaryFill : C.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? C.primaryFill : C.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_dayName(day), style: T.caption),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: C.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.hour,
    required this.courts,
    required this.slots,
    required this.selectedId,
    required this.onPick,
  });

  final int hour;
  final List<ApiCourt> courts;
  final List<ApiSlot> slots;
  final String? selectedId;
  final ValueChanged<ApiSlot> onPick;

  ApiSlot? _slotOf(ApiCourt court) {
    for (final s in slots) {
      if (s.courtId == court.id && s.start.hour == hour) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            '${hour.toString().padLeft(2, '0')}.00',
            style: T.caption,
          ),
        ),
        for (final court in courts)
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Builder(
                builder: (_) {
                  final slot = _slotOf(court);
                  return _SlotCell(
                    slot: slot,
                    // Tanpa slot bukan "dipilih" walau belum ada pilihan
                    // (null == null).
                    selected: slot != null && slot.id == selectedId,
                    onTap: onPick,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final ApiSlot? slot;
  final bool selected;
  final ValueChanged<ApiSlot> onTap;

  @override
  Widget build(BuildContext context) {
    final open = slot?.isOpen ?? false;
    final label = selected
        ? 'Dipilih'
        : slot == null
        ? 'Tutup'
        : open
        ? ''
        : 'Terisi';
    final background = selected
        ? C.primaryFill
        : open
        ? C.surface
        : C.surfaceAlt;
    final border = selected
        ? Border.all(color: C.primaryCheck)
        : Border.all(color: C.line);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: open ? () => onTap(slot!) : null,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? C.ink : C.faint,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (label, color, filled) in [
          ('Kosong', C.surface, false),
          ('Pilihmu', C.primaryFill, true),
          ('Terisi', C.surfaceAlt, true),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: filled ? color : C.line),
                ),
              ),
              const SizedBox(width: 5),
              Text(label, style: T.caption),
            ],
          ),
      ],
    );
  }
}

class _VenueSummary extends StatelessWidget {
  const _VenueSummary({
    required this.venue,
    required this.court,
    required this.slot,
    required this.onChange,
  });

  final ApiVenue venue;
  final ApiCourt? court;
  final ApiSlot slot;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: C.primaryFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.stadium_outlined, color: C.ink, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${venue.name} • ${court?.name ?? slot.courtName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(slot.start)} • '
                  '${formatTime(slot.start)}–${formatTime(slot.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
                Text(rupiah(slot.price), style: T.small),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: C.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
            ),
            child: const Text(
              'Ubah',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({
    required this.value,
    required this.total,
    required this.capacity,
    required this.pricePerPerson,
    required this.onTap,
  });

  /// null = "Lain".
  final int? value;
  final int total;
  final int capacity;
  final int pricePerPerson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == null
        ? ![4, 6, 8].contains(total)
        : value == total;
    final title = value?.toString() ?? 'Lain';
    final subtitle = value == null
        ? '2–$capacity'
        : _shortRupiah(pricePerPerson);

    return Material(
      color: selected ? C.primarySoft : C.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? C.primaryCheck : C.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? C.primaryDeep : C.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? C.primaryDeep : C.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.access,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final LobbyAccess access;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? C.primaryCheck : C.line,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: C.primaryCheck,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  access.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
                Text(switch (access) {
                  LobbyAccess.open => 'Muncul di daftar room',
                  LobbyAccess.link => 'Hanya yang punya kode undangan',
                  LobbyAccess.password => 'Muncul di daftar, join butuh sandi',
                }, style: T.small),
              ],
            ),
          ),
          if (!enabled)
            const Text(
              'Segera',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: C.faint,
              ),
            ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: body,
      ),
    );
  }
}

class _DeadlineBox extends StatelessWidget {
  const _DeadlineBox({required this.slot});

  final ApiSlot? slot;

  @override
  Widget build(BuildContext context) {
    final deadline = slot?.start.subtract(const Duration(hours: 6));
    final label = deadline == null
        ? '6 jam sebelum main'
        : '6 jam sebelum main • ${_dayName(deadline)} '
              '${formatTime(deadline)}';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: C.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: C.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: C.ink,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: C.faint),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: C.ink,
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
      ),
    );
  }
}

// ── Bantuan format ─────────────────────────────────────────────────────────

String _dayName(DateTime d) {
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  return days[d.weekday - 1];
}

String _duration(ApiSlot slot) {
  final minutes = slot.end.difference(slot.start).inMinutes;
  if (minutes % 60 == 0) return '${minutes ~/ 60} jam';
  return '$minutes menit';
}

/// "Rp100 rb" — ringkas untuk chip kuota dan daftar venue.
String _shortRupiah(int value) {
  if (value < 1000) return 'Rp$value';
  final ribu = value / 1000;
  final text = ribu == ribu.roundToDouble()
      ? ribu.round().toString()
      : ribu.toStringAsFixed(1).replaceAll('.', ',');
  return 'Rp$text rb';
}
