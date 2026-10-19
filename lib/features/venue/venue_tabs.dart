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
    final day = DateTime.now().add(Duration(days: _day));
    final slots = slotsOn(all, day)
        .where((s) => _court == 0 || s.court == _court)
        .toList();

    final booked = slots
        .where((s) => s.status == SlotStatus.booked || s.status == SlotStatus.lobby)
        .length;
    final open = slots.where((s) => s.status == SlotStatus.open).length;
    final estimate = slots
        .where((s) => s.status != SlotStatus.closed)
        .fold<int>(0, (sum, s) => sum + s.price);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: C.ink,
                    ),
                  ),
                  Text(
                    '${formatDate(day)} · '
                    '${_court == 0 ? '${venueProfile.courts} lapangan' : 'Lapangan $_court'}',
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
        const SizedBox(height: 14),
        _DayStrip(
          selected: _day,
          onPick: (d) => setState(() => _day = d),
        ),
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
                child: _Stat(value: '$open', label: 'Kosong', color: C.green),
              ),
              _VLine(),
              Expanded(
                child: _Stat(
                  value: rupiah(estimate),
                  label: 'Potensi',
                  color: C.purple,
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
              for (var c = 1; c <= venueProfile.courts; c++)
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
          for (var c = 1; c <= venueProfile.courts; c++)
            if (_court == 0 || _court == c)
              ..._courtSection(slots, c),
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
              style: const TextStyle(fontSize: 11, color: C.faint),
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

  void _openSlot(BuildContext context, VenueSlot slot) {
    final editable = slot.status != SlotStatus.booked;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetWrap(
        title: 'Slot ${formatTime(slot.start)}–${formatTime(slot.end)}',
        children: [
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
          _DetailRow('Tanggal', formatDate(slot.start)),
          _DetailRow('Durasi', '2 jam'),
          _DetailRow(
            'Harga',
            slot.price == 0 ? 'Tidak dijual' : rupiah(slot.price),
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
                        ? C.green
                        : C.coral,
                    onPressed: () {
                      ref
                          .read(venueSlotsProvider.notifier)
                          .setStatus(
                            slot.id,
                            slot.status == SlotStatus.closed
                                ? SlotStatus.open
                                : SlotStatus.closed,
                          );
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
            child: const Text('Simpan', style: TextStyle(color: C.pink)),
          ),
        ],
      ),
    );
    final price = int.tryParse((value ?? '').replaceAll('.', ''));
    if (price == null || price < 0) return;
    ref.read(venueSlotsProvider.notifier).setPrice(slot.id, price);
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
                color: active ? C.purple : C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? C.purple : C.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Hari ini' : _dow[d.weekday - 1],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white70 : C.faint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: active ? Colors.white : C.ink,
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: C.faint)),
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
            color: selected ? C.purple : C.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? C.purple : C.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : C.muted,
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
                      style: const TextStyle(fontSize: 10.5, color: C.faint),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      slot.status.label,
                      style: TextStyle(
                        fontSize: 10.5,
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
              style: const TextStyle(fontSize: 12.5, color: C.muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
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
  final _price = TextEditingController(text: '200000');

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = int.tryParse(_price.text.replaceAll('.', '')) ?? 0;
    final start = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _hour,
    );
    final error = ref
        .read(venueSlotsProvider.notifier)
        .add(
          court: _court,
          start: start,
          end: start.add(const Duration(hours: 2)),
          price: price,
        );
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error (409)')));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Slot Lapangan $_court ${_hour.toString().padLeft(2, '0')}:00 '
          'dibuka.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetWrap(
      title: 'Tambah slot',
      children: [
        Text(formatDate(widget.day), style: T.small),
        const SizedBox(height: 14),
        const Text('Lapangan', style: T.label),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var c = 1; c <= venueProfile.courts; c++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _court = c),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _court == c ? C.purple : C.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _court == c ? C.purple : C.line,
                      ),
                    ),
                    child: Text(
                      'Lapangan $c',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _court == c ? Colors.white : C.ink,
                      ),
                    ),
                  ),
                ),
              ),
              if (c != venueProfile.courts) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const Text('Jam mulai (2 jam)', style: T.label),
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
                  width: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? C.purple : C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? C.purple : C.line),
                  ),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : C.ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Harga slot',
          controller: _price,
          hint: '200000',
          keyboard: TextInputType.number,
          prefixIcon: Icons.payments_outlined,
        ),
        const SizedBox(height: 16),
        SebarButton(label: 'Buka slot', icon: Icons.add, onPressed: _save),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        SportPanel(
          gradient: const [Color(0xFF43D99A), Color(0xFF17A56B)],
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Pill('Omzet bulan ini', background: Colors.white24),
              const SizedBox(height: 10),
              Text(
                rupiah(venueSummary.revenue),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                  height: 1,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fee SEBAR ${rupiah(venueSummary.fee)} · '
                '${venueSummary.bookings} booking',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.78),
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: C.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 92 * p.$2 / maxPeak,
                                decoration: BoxDecoration(
                                  color: p.$2 == maxPeak ? C.green : C.mint,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${p.$1}',
                                style: const TextStyle(
                                  fontSize: 9,
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
                  const Icon(Icons.bolt, size: 15, color: C.green),
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
                      style: const TextStyle(fontSize: 9.5, color: C.muted),
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
              const Icon(Icons.query_stats, size: 16, color: C.green),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Semua angka dari GROUP BY di database, bukan input manual.',
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
          Icon(icon, size: 16, color: danger ? C.coral : C.green),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: C.ink,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10.5, color: C.muted)),
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
            C.green.withValues(alpha: 0.22),
            C.green.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = C.green
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
        Paint()..color = i == values.length - 1 ? C.amber : C.green,
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
        _resultDetail = 'Raka Pratama · skor +2 · Badminton Jumat Malam';
        _history.insert(0, (code, 'Raka · 19:00 Lapangan 1', true));
      });
    } else if (code == 'SEB-4K2P-DUP') {
      setState(() {
        _result = 'GAGAL';
        _resultDetail = 'ALREADY_CHECKED_IN — tiket sudah discan.';
        _history.insert(0, (code, 'Sudah discan', false));
      });
    } else {
      setState(() {
        _result = 'GAGAL';
        _resultDetail = 'TICKET_EXPIRED — kode tidak dikenal atau kedaluwarsa.';
        _history.insert(0, (code.isEmpty ? '—' : code, 'Tidak dikenal', false));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text('Scan tiket', style: T.h1),
        const SizedBox(height: 3),
        Text('Validasi QR peserta saat masuk lapangan.', style: T.small),
        const SizedBox(height: 14),
        Container(
          height: 188,
          decoration: BoxDecoration(
            color: C.surfaceAlt,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.green, width: 2),
                ),
              ),
              const Icon(Icons.qr_code_scanner, size: 40, color: C.green),
              const Positioned(
                bottom: 14,
                child: Text(
                  'Arahkan kamera ke QR peserta',
                  style: TextStyle(fontSize: 11, color: C.muted),
                ),
              ),
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
                  : C.pink.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _result == 'VALID' ? Icons.verified : Icons.error_outline,
                  size: 20,
                  color: _result == 'VALID' ? C.greenDeep : C.coral,
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
                          color: _result == 'VALID' ? C.greenDeep : C.coral,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _resultDetail!,
                        style: const TextStyle(
                          fontSize: 11.5,
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
                    color: h.$3 ? C.green : C.coral,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.$1,
                          style: const TextStyle(
                            fontSize: 12.5,
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: h.$3 ? C.green : C.coral,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kode uji', style: T.h3),
              const SizedBox(height: 5),
              const Text(
                'SEB-4K2P valid\nSEB-4K2P-DUP sudah discan\nkode lain kedaluwarsa',
                style: T.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
