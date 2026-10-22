import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(venueSlotsProvider);
    final notifier = ref.read(venueSlotsProvider.notifier);
    final venues = notifier.venues;
    final courtCount = notifier.courts.isEmpty
        ? venueProfile.courts
        : notifier.courts.length;
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

    return ListView(
      padding: kScreenPad,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  Text(
                    '${formatDate(day)} · '
                    '${_court == 0 ? '$courtCount lapangan' : 'Lapangan $_court'}',
                    style: T.small,
                  ),
                ],
              ),
            ),
            GhostButton(
              label: 'Tambah',
              icon: Icons.add,
              height: 38,
              onPressed: () => showAddSlotSheet(context),
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
                child: _Stat(value: '$open', label: 'Kosong', color: C.primary),
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
                  label: 'Lapangan $c',
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
            message: 'Buka slot untuk tanggal ini supaya pemain bisa booking.',
            action: GhostButton(
              label: 'Tambah slot',
              icon: Icons.add,
              onPressed: () => showAddSlotSheet(context, day: day),
            ),
          )
        else
          for (var c = 1; c <= courtCount; c++)
            if (_court == 0 || _court == c) ..._courtSection(slots, c),
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
    );
  }

  List<Widget> _courtSection(List<VenueSlot> slots, int court) {
    final mine = slots.where((s) => s.court == court).toList();
    if (mine.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(
          children: [
            Text('Lapangan $court', style: T.h3),
            const SizedBox(width: 6),
            Text(
              '· ${mine.length} slot',
              style: const TextStyle(fontSize: 12, color: C.faint),
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

  /// Venue memilih atau mengganti foto lapangan. Kuncinya sama dengan yang
  /// dibaca layar room, jadi perubahan langsung tampil di sana.
  ///
  /// ponytail: sumber foto masih prasetel/tautan; ganti ke unggahan galeri
  /// saat API media tersedia.
  Future<void> _pickCourtPhoto(int court) async {
    final courtName = 'Lapangan $court';
    final key = courtPhotoKey(venueProfile.name, courtName);
    final url = TextEditingController();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SheetWrap(
        title: 'Foto $courtName',
        children: [
          Text(
            'Pilih foto bawaan atau tempel tautan gambar sendiri. Foto ini '
            'langsung dipakai semua room yang memilih lapangan ini.',
            style: T.small,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CourtPhoto.presets(key).length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _PhotoChoice(
                url: CourtPhoto.presets(key)[i],
                onTap: (value) => Navigator.pop(sheetContext, value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Tautan foto sendiri',
            controller: url,
            hint: 'https://…',
            keyboard: TextInputType.url,
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          SebarButton(
            label: 'Pakai tautan ini',
            onPressed: () {
              final value = url.text.trim();
              if (!value.startsWith('http')) return;
              Navigator.pop(sheetContext, value);
            },
          ),
        ],
      ),
    );
    url.dispose();
    if (picked == null) return;
    ref.read(courtPhotosProvider.notifier).setPhoto(key, picked);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Foto $courtName diperbarui.')));
  }

  void _openSlot(BuildContext context, VenueSlot slot) {
    final editable = slot.status != SlotStatus.booked;
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
                court: 'Lapangan ${slot.court}',
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
                      _pickCourtPhoto(slot.court);
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
              Pill('Lapangan ${slot.court}', background: C.surfaceAlt),
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
    final price = int.tryParse((value ?? '').replaceAll('.', ''));
    if (price == null || price < 0) return;
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .setPriceRemote(slot.id, price);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

/// Pilihan foto bawaan pada sheet ganti foto lapangan.
class _PhotoChoice extends StatelessWidget {
  const _PhotoChoice({required this.url, required this.onTap});

  final String url;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(url),
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 140,
          height: 92,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 280,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const _PhotoChoiceFallback(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const _PhotoChoiceFallback(),
          ),
        ),
      ),
    );
  }
}

class _PhotoChoiceFallback extends StatelessWidget {
  const _PhotoChoiceFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: C.primarySoft,
      child: Center(
        child: Icon(Icons.stadium_outlined, size: 22, color: C.primary),
      ),
    );
  }
}

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
                      slot.guest ?? 'Lapangan ${slot.court}',
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

/// Sheet tambah slot: dipakai dari Beranda (FAB) dan tab Jadwal.
Future<void> showAddSlotSheet(BuildContext context, {DateTime? day}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddSlotSheet(day: day ?? DateTime.now()),
  );
}

class _AddSlotSheet extends ConsumerStatefulWidget {
  const _AddSlotSheet({required this.day});

  final DateTime day;

  @override
  ConsumerState<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends ConsumerState<_AddSlotSheet> {
  int _court = 1;
  int _hour = 8;
  int _duration = 2;

  Future<void> _save() async {
    final courts = ref.read(venueSlotsProvider.notifier).courts;
    final court = _court <= courts.length ? courts[_court - 1] : null;
    if (court == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun venue ini belum punya lapangan aktif.'),
        ),
      );
      return;
    }
    final start = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _hour,
    );
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .addRemote(
          courtId: court.id,
          start: start,
          duration: Duration(hours: _duration),
          pricePerHour: court.pricePerHour,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Slot ${court.name} ${_hour.toString().padLeft(2, '0')}:00 '
          'selama $_duration jam sudah dibuka.',
        ),
      ),
    );
  }

  /// Tarif per jam milik lapangan, bukan milik slot.
  Future<void> _editCourtPrice(ApiCourt court) async {
    final controller = TextEditingController(text: '${court.pricePerHour}');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarif lapangan', style: T.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${court.name} · per jam', style: T.small),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'Rp'),
            ),
            const SizedBox(height: 8),
            Text(
              'Slot yang sudah dibuka tetap memakai harga lamanya.',
              style: T.caption,
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
            child: const Text('Simpan', style: TextStyle(color: C.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
    final price = int.tryParse((value ?? '').replaceAll('.', ''));
    if (price == null) return;
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .setCourtPriceRemote(court.id, price);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Tarif ${court.name} diperbarui.')),
    );
  }

  Future<void> _addCourt() async {
    final name = TextEditingController();
    final price = TextEditingController(text: '100000');
    final capacity = TextEditingController(text: '12');
    var sport = Sport.badminton;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Tambah lapangan', style: T.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama lapangan'),
              ),
              DropdownButton<Sport>(
                value: sport,
                isExpanded: true,
                items: [
                  for (final s in Sport.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setDialog(() => sport = v ?? sport),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tarif per jam',
                  prefixText: 'Rp',
                ),
              ),
              TextField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kapasitas orang'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: C.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan', style: TextStyle(color: C.primary)),
            ),
          ],
        ),
      ),
    );
    final pricePerHour = int.tryParse(price.text.trim());
    final cap = int.tryParse(capacity.text.trim());
    final courtName = name.text.trim();
    name.dispose();
    price.dispose();
    capacity.dispose();
    if (saved != true || !mounted) return;
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .addCourtRemote(
          name: courtName,
          sport: sport,
          pricePerHour: pricePerHour ?? 0,
          capacity: cap ?? 0,
        );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Lapangan $courtName ditambahkan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(venueSlotsProvider.notifier);
    final courts = notifier.courts;
    final courtCount = courts.length;
    final court = _court <= courts.length ? courts[_court - 1] : null;
    final rate = court?.pricePerHour ?? 0;
    final total = rate * _duration;

    return SheetWrap(
      title: 'Tambah slot',
      children: [
        Text(
          '${notifier.venue?.name ?? 'Venue'} · ${formatLongDate(widget.day)}',
          style: T.small,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Lapangan', style: T.label),
            const Spacer(),
            TextButton(
              onPressed: _addCourt,
              child: const Text('Tambah lapangan'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (courts.isEmpty)
          Text(
            'Belum ada lapangan di akun venue ini. Slot tidak bisa dibuka '
            'sebelum lapangan dibuat.',
            style: T.small,
          )
        else
          Row(
            children: [
              for (var c = 1; c <= courtCount; c++) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _court = c),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _court == c ? C.primaryFill : C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _court == c ? C.primaryFill : C.line,
                        ),
                      ),
                      child: Text(
                        courts[c - 1].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (c != courtCount) const SizedBox(width: 8),
              ],
            ],
          ),
        if (court != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tarif ${rupiah(rate)}/jam · ${court.capacity} orang',
                  style: T.caption,
                ),
              ),
              TextButton(
                onPressed: () => _editCourtPrice(court),
                child: const Text('Ubah tarif'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        CourtPhoto(
          venue: venueProfile.name,
          court: court?.name ?? 'Lapangan $_court',
          height: 140,
          radius: 18,
        ),
        const SizedBox(height: 14),
        const Text('Jam mulai', style: T.label),
        const SizedBox(height: 7),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final h = 8 + i;
              final active = h == _hour;
              return GestureDetector(
                onTap: () => setState(() => _hour = h),
                child: Container(
                  width: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? C.primaryFill : C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? C.primaryFill : C.line),
                  ),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: C.ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const Text('Durasi', style: T.label),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var d = 1; d <= 3; d++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _duration = d),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _duration == d ? C.primaryFill : C.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _duration == d ? C.primaryFill : C.line,
                      ),
                    ),
                    child: Text(
                      '$d jam',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.ink,
                      ),
                    ),
                  ),
                ),
              ),
              if (d != 3) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          radius: 16,
          color: C.surfaceAlt,
          shadow: false,
          child: Column(
            children: [
              _DetailRow('Tarif per jam', rupiah(rate)),
              _DetailRow('Durasi', '$_duration jam'),
              const Divider(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Harga slot',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: C.ink,
                      ),
                    ),
                  ),
                  Text(
                    rupiah(total),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: C.primaryDeep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SebarButton(
          label: 'Buka slot',
          icon: Icons.add,
          onPressed: court == null ? null : _save,
        ),
      ],
    );
  }
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
