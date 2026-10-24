import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

// ─── Jadwal ────────────────────────────────────────────────────────────────

class VenueScheduleTab extends ConsumerStatefulWidget {
  const VenueScheduleTab({super.key});

  @override
  ConsumerState<VenueScheduleTab> createState() => _VenueScheduleTabState();
}

class _VenueScheduleTabState extends ConsumerState<VenueScheduleTab> {
  int _day = 0;
  int _court = 0; // 0 = semua
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Refresh awal saat login bisa gagal dan sebelumnya tidak pernah
    // dicoba ulang; muat ulang sendiri supaya tab ini selalu bisa dipakai
    // tanpa harus logout-login.
    Future.microtask(() {
      if (!ref.read(venueSlotsProvider.notifier).hasVenue) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(venueSlotsProvider.notifier).refresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(venueSlotsProvider);
    final notifier = ref.read(venueSlotsProvider.notifier);
    final venues = notifier.venues;
    final hasVenue = notifier.hasVenue;
    final courts = hasVenue ? notifier.courts : const <ApiCourt>[];
    final courtCount = courts.length;
    final day = DateTime.now().add(Duration(days: _day));
    final slots = slotsOn(
      all,
      day,
    ).where((s) => _court == 0 || s.court == _court).toList();

    final booked = slots
        .where(
          (s) => s.status == SlotStatus.booked || s.status == SlotStatus.lobby,
        )
        .length;
    final open = slots.where((s) => s.status == SlotStatus.open).length;
    final estimate = slots
        .where((s) => s.status != SlotStatus.closed)
        .fold<int>(0, (sum, s) => sum + s.price);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPad,
        children: [
          if (!hasVenue) ..._loadBanner(notifier),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasVenue
                          ? venueProfile.name
                          : _refreshing
                          ? 'Memuat data venue…'
                          : notifier.missingVenue
                          ? 'Belum ada venue'
                          : 'Data venue belum dimuat',
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
                      hasVenue
                          ? '${formatDate(day)} · '
                                '${_court == 0 ? '$courtCount lapangan' : 'Lapangan $_court'}'
                          : notifier.missingVenue
                          ? 'Buat venue dulu untuk mulai'
                          : 'Tarik layar untuk memuat ulang',
                      style: T.small,
                    ),
                  ],
                ),
              ),
              GhostButton(
                label: 'Lapangan',
                icon: Icons.stadium_outlined,
                height: 38,
                onPressed: () => context.push('/venue/courts'),
              ),
            ],
          ),
          if (venues.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final v in venues)
                    _CourtChip(
                      label: v.name,
                      selected: v.id == notifier.venueId,
                      onTap: () => notifier.selectVenue(v.id),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _DayStrip(selected: _day, onPick: (d) => setState(() => _day = d)),
          const SizedBox(height: 12),
          SurfaceCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(value: '$booked', label: 'Terisi', color: C.ink),
                ),
                _VLine(),
                Expanded(
                  child: _Stat(
                    value: '$open',
                    label: 'Kosong',
                    color: C.primary,
                  ),
                ),
                _VLine(),
                Expanded(
                  child: _Stat(
                    value: rupiah(estimate),
                    label: 'Potensi',
                    color: C.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CourtChip(
                  label: 'Semua',
                  selected: _court == 0,
                  onTap: () => setState(() => _court = 0),
                ),
                for (var c = 1; c <= courtCount; c++)
                  _CourtChip(
                    label: courts[c - 1].name,
                    selected: _court == c,
                    onTap: () => setState(() => _court = c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (slots.isEmpty)
            EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Belum ada slot',
              message:
                  'Atur jam dan tarif lapangan dulu supaya pemain bisa booking.',
              action: GhostButton(
                label: 'Kelola lapangan',
                icon: Icons.add,
                onPressed: () => context.push('/venue/courts'),
              ),
            )
          else
            for (var c = 1; c <= courtCount; c++)
              if (_court == 0 || _court == c)
                ..._courtSection(slots, c, courts[c - 1].name),
          const SizedBox(height: 6),
          SurfaceCard(
            radius: 18,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: C.muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Slot terisi tidak bisa dihapus. Tutup slot hanya untuk yang '
                    'masih kosong.',
                    style: T.small,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner saat venue belum termuat: "buat venue" untuk akun tanpa venue,
  /// spinner saat memuat, pesan + tombol Muat ulang saat gagal.
  List<Widget> _loadBanner(VenueSlotsNotifier notifier) {
    // Server menjawab tapi akun ini tidak punya venue — muat ulang tidak
    // akan mengubah apa pun, tawarkan membuat venue.
    if (notifier.missingVenue) {
      return [
        SurfaceCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 20, color: C.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Akun venue ini belum punya venue. Buat dulu untuk menambah '
                  'lapangan dan slot.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
              ),
              GhostButton(
                label: 'Buat venue',
                icon: Icons.add,
                height: 34,
                onPressed: () => showCreateVenueSheet(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ];
    }
    final busy = _refreshing || notifier.isLoading;
    return [
      SurfaceCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.error_outline, size: 20, color: C.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data venue belum dimuat dari server.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                  if (!busy && notifier.lastError != null) ...[
                    const SizedBox(height: 2),
                    Text(notifier.lastError!, style: T.small),
                  ],
                ],
              ),
            ),
            if (!busy)
              GhostButton(
                label: 'Muat ulang',
                icon: Icons.refresh,
                height: 34,
                onPressed: _refresh,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _courtSection(List<VenueSlot> slots, int court, String name) {
    final mine = slots.where((s) => s.court == court).toList();
    if (mine.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.h3,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· ${mine.length} slot',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.faint),
            ),
            const SizedBox(width: 8),
            GhostButton(
              label: 'Kelola',
              icon: Icons.edit_outlined,
              height: 34,
              onPressed: () =>
                  context.push('/venue/courts', extra: court - 1),
            ),
          ],
        ),
      ),
      for (final s in mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SlotRow(slot: s, onTap: () => _openSlot(context, s)),
        ),
      const SizedBox(height: 6),
    ];
  }

  /// Venue memilih atau mengganti foto lapangan lewat layar Kelola (venue_courts.dart).
  void _openCourtManager(int court) {
    final router = GoRouter.of(context);
    router.push('/venue/courts', extra: court - 1);
  }

  void _openSlot(BuildContext context, VenueSlot slot) {
    final editable = slot.status != SlotStatus.booked;
    final courtName = slot.courtName ?? 'Lapangan ${slot.court}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetWrap(
        title: 'Slot ${formatTime(slot.start)}–${formatTime(slot.end)}',
        children: [
          Stack(
            children: [
              CourtPhoto(
                venue: venueProfile.name,
                court: courtName,
                height: 150,
                radius: 18,
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: C.ink.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      Navigator.pop(context);
                      _openCourtManager(slot.court);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Ganti foto',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Pill(
                slot.status.label,
                color: slot.status.color,
                background: slot.status.color.withValues(alpha: 0.16),
                icon: slot.status.icon,
              ),
              const SizedBox(width: 6),
              Pill(courtName, background: C.surfaceAlt),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow('Tanggal', formatLongDate(slot.start)),
          _DetailRow('Durasi', '${slot.durationHours} jam'),
          _DetailRow(
            'Harga',
            slot.price == 0
                ? 'Tidak dijual'
                : '${rupiah(slot.price)} · ${rupiah(slot.pricePerHour)}/jam',
          ),
          if (slot.guest != null) _DetailRow('Terisi oleh', slot.guest!),
          const SizedBox(height: 6),
          if (!editable)
            Text(
              'Slot sudah dibayar. Perubahan hanya lewat alur refund.',
              style: T.small,
            ),
          if (editable) ...[
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: slot.status == SlotStatus.closed
                        ? 'Buka slot'
                        : 'Tutup slot',
                    icon: slot.status == SlotStatus.closed
                        ? Icons.lock_open
                        : Icons.lock_outline,
                    color: slot.status == SlotStatus.closed
                        ? C.primary
                        : C.danger,
                    onPressed: () async {
                      final next = slot.status == SlotStatus.closed
                          ? SlotStatus.open
                          : SlotStatus.closed;
                      final error = await ref
                          .read(venueSlotsProvider.notifier)
                          .setStatusRemote(slot.id, next);
                      if (!context.mounted) return;
                      if (error != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhostButton(
                    label: 'Ubah harga',
                    icon: Icons.sell_outlined,
                    onPressed: () {
                      Navigator.pop(context);
                      _editPrice(slot);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _editPrice(VenueSlot slot) async {
    final controller = TextEditingController(text: '${slot.price}');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harga slot', style: T.h2),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rp',
            hintText: '200000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Simpan', style: TextStyle(color: C.primary)),
          ),
        ],
      ),
    );
    disposeAfterClose([controller]);
    if (value == null) return;
    final price = int.tryParse(value.replaceAll('.', ''));
    if (!_validPrice(price)) {
      if (mounted) _showPriceError(context);
      return;
    }
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .setPriceRemote(slot.id, price!);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

/// Batas harga sama dengan validasi backend (Rp1.000 – Rp100.000.000).
bool _validPrice(int? price) =>
    price != null && price >= 1000 && price <= 100000000;

const _priceRangeMessage = 'Harga harus Rp1.000 – Rp100.000.000.';

void _showPriceError(BuildContext context) => ScaffoldMessenger.of(
  context,
).showSnackBar(const SnackBar(content: Text(_priceRangeMessage)));

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selected, required this.onPick});

  final int selected;
  final ValueChanged<int> onPick;

  static const _dow = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = now.add(Duration(days: i));
          final active = i == selected;
          return GestureDetector(
            onTap: () => onPick(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              decoration: BoxDecoration(
                color: active ? C.primaryFill : C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? C.primaryFill : C.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Hari ini' : _dow[d.weekday - 1],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? C.ink : C.faint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: C.faint)),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: C.line);
}

class _CourtChip extends StatelessWidget {
  const _CourtChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.primaryFill : C.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? C.primaryFill : C.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? C.ink : C.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onTap});

  final VenueSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = slot.status.color;
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTime(slot.start),
                      style: const TextStyle(
                        fontSize: 13,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.guest ??
                          (slot.courtName ?? 'Lapangan ${slot.court}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      slot.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                slot.price == 0 ? '—' : rupiah(slot.price),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: C.ink,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 15, color: C.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: C.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Validasi form venue — samakan dengan skema backend
/// (name 3–120, address 5–300, city 2–60).
String? _venueFormError(String name, String address, String city) {
  if (name.trim().length < 3) return 'Nama venue minimal 3 karakter.';
  if (address.trim().length < 5) return 'Alamat minimal 5 karakter.';
  if (city.trim().length < 2) return 'Kota minimal 2 karakter.';
  return null;
}

/// Sheet buat venue pertama: dipakai banner tab Jadwal dan sheet tambah
/// slot saat akun venue belum punya venue sama sekali (mis. akun lama yang
/// role-nya dinaikkan manual di database).
Future<void> showCreateVenueSheet(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  String? formError;
  var saved = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void submit() {
            final error = _venueFormError(name.text, address.text, city.text);
            if (error != null) {
              setSheet(() => formError = error);
              return;
            }
            saved = true;
            Navigator.pop(sheetContext);
          }

          return SheetWrap(
            title: 'Buat venue',
            children: [
              Text(
                'Venue pertama untuk akun ini. Setelah jadi, tambah lapangan '
                'lalu buka slot pertamamu.',
                style: T.small,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Nama venue',
                controller: name,
                hint: 'Contoh: GOR C-Tra Arena',
                prefixIcon: Icons.storefront_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Alamat',
                controller: address,
                hint: 'Jalan dan nomor',
                prefixIcon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Kota',
                controller: city,
                hint: 'Contoh: Bandung',
                prefixIcon: Icons.place,
                textCapitalization: TextCapitalization.words,
              ),
              if (formError != null) ...[
                const SizedBox(height: 10),
                Text(
                  formError!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SebarButton(
                label: 'Simpan venue',
                icon: Icons.check,
                onPressed: submit,
              ),
            ],
          );
        },
      ),
    ),
  );
  final venueName = name.text.trim();
  final addr = address.text.trim();
  final cityName = city.text.trim();
  disposeAfterClose([name, address, city]);
  if (!saved || !context.mounted) return;
  final error = await ref
      .read(venueSlotsProvider.notifier)
      .createVenueRemote(name: venueName, address: addr, city: cityName);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error ?? 'Venue $venueName dibuat. Lanjut tambah lapangan.',
      ),
    ),
  );
}

// ─── Analytics ─────────────────────────────────────────────────────────────

class VenueAnalyticsScreen extends StatelessWidget {
  const VenueAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: RoundBackHeader(title: 'Analytics venue'),
            ),
            const Expanded(child: VenueAnalyticsTab()),
          ],
        ),
      ),
    );
  }
}

class VenueAnalyticsTab extends StatelessWidget {
  const VenueAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final maxPeak = peakHours.map((e) => e.$2).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: kScreenPad,
      children: [
        SportPanel(
          gradient: C.primaryPanel,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill(
                'Omzet bulan ini',
                color: C.ink,
                background: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(rupiah(venueSummary.revenue), style: T.h1),
              const SizedBox(height: 6),
              Text(
                'Fee SEBAR ${rupiah(venueSummary.fee)} · '
                '${venueSummary.bookings} booking',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: C.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Okupansi',
                value: '${(venueSummary.occupancy * 100).round()}%',
                icon: Icons.pie_chart_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Kpi(
                label: 'No-show',
                value: '${venueSummary.noShow}',
                icon: Icons.block,
                danger: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Peak hours'),
        const SizedBox(height: 10),
        SurfaceCard(
          radius: 18,
          child: Column(
            children: [
              SizedBox(
                height: 122,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final p in peakHours)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${p.$2}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: C.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 92 * p.$2 / maxPeak,
                                decoration: BoxDecoration(
                                  color: p.$2 == maxPeak ? C.primary : C.mint,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${p.$1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: C.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.bolt, size: 15, color: C.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Jam tersibuk 20:00, 26 booking '
                      '(${(26 / 128 * 100).round()}%).',
                      style: T.small,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Tren pendapatan'),
        const SizedBox(height: 10),
        SurfaceCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(
            children: [
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineChartPainter(
                    values: monthlyRevenue.map((e) => e.$2.toDouble()).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final m in monthlyRevenue)
                    Text(
                      m.$1,
                      style: const TextStyle(fontSize: 12, color: C.muted),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          radius: 18,
          child: Row(
            children: [
              const Icon(Icons.query_stats, size: 16, color: C.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Angka dihitung otomatis dari transaksi yang tercatat.',
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

class _Kpi extends StatelessWidget {
  const _Kpi({
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: danger ? C.danger : C.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: C.ink,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    final dx = size.width / (values.length - 1);

    Offset point(int i) => Offset(
      dx * i,
      size.height - 6 - ((values[i] - minV) / range) * (size.height - 12),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p0 = point(i);
      final p1 = point(i + 1);
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            C.primary.withValues(alpha: 0.22),
            C.primary.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = C.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 3.4, Paint()..color = C.surface);
      canvas.drawCircle(
        p,
        2.2,
        Paint()..color = i == values.length - 1 ? C.amber : C.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.values != values;
}

// ─── Scan ──────────────────────────────────────────────────────────────────

class VenueScanTab extends StatefulWidget {
  const VenueScanTab({super.key});

  @override
  State<VenueScanTab> createState() => _VenueScanTabState();
}

class _VenueScanTabState extends State<VenueScanTab> {
  final _code = TextEditingController();
  String? _result;
  String? _resultDetail;
  final _history = <(String, String, bool)>[
    ('SEB-4K2P', 'Raka · 19:00 Lapangan 1', true),
    ('SEB-9QX1', 'Ayu · 08:00 Lapangan 1', true),
    ('SEB-3MZ7', 'Doni · sudah discan', false),
  ];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _scan() {
    final code = _code.text.trim().toUpperCase();
    if (code == 'SEB-4K2P') {
      setState(() {
        _result = 'VALID';
        _resultDetail = 'Raka Pratama · Badminton Jumat Malam';
        _history.insert(0, (code, 'Raka · 19:00 Lapangan 1', true));
      });
    } else if (code == 'SEB-4K2P-DUP') {
      setState(() {
        _result = 'GAGAL';
        _resultDetail = 'Tiket ini sudah pernah discan.';
        _history.insert(0, (code, 'Sudah discan', false));
      });
    } else {
      setState(() {
        _result = 'GAGAL';
        _resultDetail = 'Kode tidak dikenal atau sudah kedaluwarsa.';
        _history.insert(0, (code.isEmpty ? '—' : code, 'Tidak dikenal', false));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: kScreenPad,
      children: [
        const Text('Scan tiket', style: T.h1),
        const SizedBox(height: 3),
        Text('Validasi QR peserta saat masuk lapangan.', style: T.small),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: C.surfaceAlt,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.primary, width: 2),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 42,
                  color: C.primary,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Arahkan kamera ke QR peserta', style: T.small),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Input manual kode booking',
          controller: _code,
          hint: 'SEB-4K2P',
          prefixIcon: Icons.keyboard,
        ),
        const SizedBox(height: 12),
        SebarButton(
          label: 'Validasi tiket',
          icon: Icons.check_circle_outline,
          onPressed: _scan,
        ),
        if (_result != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _result == 'VALID'
                  ? C.mint
                  : C.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _result == 'VALID' ? Icons.verified : Icons.error_outline,
                  size: 20,
                  color: _result == 'VALID' ? C.primaryDeep : C.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result == 'VALID' ? 'Tiket valid' : 'Tiket ditolak',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _result == 'VALID' ? C.primaryDeep : C.danger,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _resultDetail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: C.ink,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionHeader('Scan terakhir'),
        const SizedBox(height: 8),
        for (final h in _history.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    h.$3 ? Icons.verified_outlined : Icons.error_outline,
                    size: 16,
                    color: h.$3 ? C.primary : C.danger,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.ink,
                          ),
                        ),
                        Text(h.$2, style: T.small),
                      ],
                    ),
                  ),
                  Text(
                    h.$3 ? 'Masuk' : 'Ditolak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: h.$3 ? C.primary : C.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: C.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Minta peserta menunjukkan QR tiket. Satu tiket hanya '
                  'berlaku untuk sekali masuk.',
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
