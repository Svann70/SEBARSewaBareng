import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Satu form untuk semua pengaturan venue: data GOR + tiap lapangan
/// (olahraga & kapasitas, harga weekday/weekend, jam buka–tutup, on/off).
/// Diisi sekali di awal; setelah itu semua jam di dalam jam buka otomatis
/// bisa disewa pemain tanpa pemilik membuka slot.
class VenueSetupScreen extends ConsumerStatefulWidget {
  const VenueSetupScreen({super.key});

  @override
  ConsumerState<VenueSetupScreen> createState() => _VenueSetupScreenState();
}

class _CourtForm {
  _CourtForm(this.draft)
    : name = TextEditingController(text: draft.name),
      weekday = TextEditingController(
        text: draft.weekdayPrice?.toString() ?? '',
      ),
      weekend = TextEditingController(
        text: draft.weekendPrice?.toString() ?? '',
      );

  final CourtDraft draft;
  final TextEditingController name;
  final TextEditingController weekday;
  final TextEditingController weekend;

  /// Salin isian teks ke draft sebelum validasi/simpan.
  CourtDraft sync() {
    draft.name = name.text;
    draft.weekdayPrice = _parse(weekday.text);
    draft.weekendPrice = weekend.text.trim().isEmpty
        ? null
        : _parse(weekend.text);
    return draft;
  }

  static int? _parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

  void dispose() {
    name.dispose();
    weekday.dispose();
    weekend.dispose();
  }
}

class _VenueSetupScreenState extends ConsumerState<VenueSetupScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _courts = <_CourtForm>[];
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final notifier = ref.read(venueSlotsProvider.notifier);
    if (!notifier.hasVenue && !notifier.missingVenue) await notifier.refresh();
    if (!mounted) return;
    final venue = notifier.venue;
    _name.text = venue?.name ?? '';
    _address.text = venue?.address ?? '';
    _city.text = venue?.city ?? '';
    _courts.addAll([
      for (final c in venue?.courts ?? const <ApiCourt>[])
        _CourtForm(CourtDraft.from(c)),
    ]);
    // GOR baru: langsung siapkan satu lapangan kosong untuk diisi.
    if (_courts.isEmpty) _addCourt();
    setState(() => _ready = true);
  }

  void _addCourt() {
    setState(
      () => _courts.add(
        _CourtForm(CourtDraft(name: 'Lapangan ${_courts.length + 1}')),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    for (final c in _courts) {
      c.dispose();
    }
    super.dispose();
  }

  String? _venueError() {
    if (_name.text.trim().length < 3) return 'Nama GOR minimal 3 huruf.';
    if (_address.text.trim().length < 5) return 'Alamat minimal 5 huruf.';
    if (_city.text.trim().length < 2) return 'Kota minimal 2 huruf.';
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final drafts = [for (final c in _courts) c.sync()];
    var error = _venueError();
    if (error == null && drafts.isEmpty) {
      error = 'Tambah minimal satu lapangan.';
    }
    if (error == null) {
      for (final d in drafts) {
        final e = d.validate();
        if (e != null) {
          error = '${d.name.trim().isEmpty ? 'Lapangan' : d.name.trim()}: $e';
          break;
        }
      }
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(venueSlotsProvider.notifier)
        .saveSetup(
          name: _name.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          courts: drafts,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      setState(() => _error = result);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tersimpan. Pemain sudah bisa memesan jam yang buka.'),
      ),
    );
    context.canPop() ? context.pop() : context.go('/venue');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const RoundBackHeader(title: 'Atur venue'),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    radius: 14,
                    color: C.primarySoft,
                    border: false,
                    child: Text(
                      'Isi sekali saja. Setelah disimpan, semua jam di dalam '
                      'jam buka otomatis bisa dipesan pemain. Kamu cukup '
                      'memantau jadwal.',
                      style: T.small.copyWith(color: C.primaryDeep),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Data GOR', style: T.h2),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Nama GOR',
                    controller: _name,
                    hint: 'Contoh: GOR Budi Jaya',
                    prefixIcon: Icons.storefront_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Alamat',
                    controller: _address,
                    hint: 'Jalan dan nomor',
                    prefixIcon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Kota',
                    controller: _city,
                    hint: 'Contoh: Bandung',
                    prefixIcon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),
                  const Text('Lapangan', style: T.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Satu lapangan bisa untuk beberapa olahraga. Satu jam '
                    'tetap untuk satu pemesan.',
                    style: T.small,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _courts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CourtCard(
                        key: ObjectKey(_courts[i]),
                        index: i + 1,
                        form: _courts[i],
                        onChanged: () => setState(() {}),
                        // Lapangan yang sudah tersimpan dimatikan, bukan
                        // dihapus, supaya riwayat booking tetap utuh.
                        onRemove: _courts[i].draft.id == null
                            ? () =>
                                  setState(() => _courts.removeAt(i).dispose())
                            : null,
                      ),
                    ),
                  GhostButton(
                    label: 'Tambah lapangan',
                    icon: Icons.add,
                    onPressed: _addCourt,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: T.small.copyWith(color: C.danger)),
                  ],
                  const SizedBox(height: 16),
                  SebarButton(
                    label: 'Simpan',
                    icon: Icons.check,
                    busy: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({
    super.key,
    required this.index,
    required this.form,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final _CourtForm form;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  CourtDraft get d => form.draft;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 16,
      color: d.active ? null : C.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Lapangan $index', style: T.h3)),
              Text(
                d.active ? 'Aktif' : 'Mati',
                style: T.small.copyWith(
                  color: d.active ? C.primaryDeep : C.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Switch(
                value: d.active,
                activeThumbColor: C.primary,
                onChanged: (v) {
                  d.active = v;
                  onChanged();
                },
              ),
            ],
          ),
          if (!d.active)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Lapangan mati tidak tampil ke pemain dan tidak bisa dipesan.',
                style: T.caption,
              ),
            ),
          LabeledField(
            label: 'Nama lapangan',
            controller: form.name,
            hint: 'Contoh: Lapangan A',
          ),
          const SizedBox(height: 14),
          const Text('Olahraga & kapasitas pemain', style: T.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sport in Sport.values)
                FilterChip(
                  label: Text(sport.label),
                  selected: d.sports.containsKey(sport),
                  onSelected: (on) {
                    on
                        ? d.sports[sport] = _defaultCapacity(sport)
                        : d.sports.remove(sport);
                    onChanged();
                  },
                ),
            ],
          ),
          for (final entry in d.sports.entries)
            _CapacityRow(
              sport: entry.key,
              value: entry.value,
              onChanged: (v) {
                d.sports[entry.key] = v;
                onChanged();
              },
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PriceField(
                  label: 'Harga/jam Sen–Jum',
                  controller: form.weekday,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriceField(
                  label: 'Harga/jam Sab–Min',
                  controller: form.weekend,
                  hint: 'Sama',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HourPicker(
                  label: 'Jam buka',
                  value: d.openHour,
                  hours: [for (var h = 0; h <= 23; h++) h],
                  onChanged: (h) {
                    d.openHour = h;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HourPicker(
                  label: 'Jam tutup',
                  value: d.closeHour,
                  hours: [for (var h = 1; h <= 24; h++) h],
                  onChanged: (h) {
                    d.closeHour = h;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (onRemove != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16, color: C.danger),
                label: const Text(
                  'Batal tambah',
                  style: TextStyle(color: C.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static int _defaultCapacity(Sport sport) => switch (sport) {
    Sport.futsal || Sport.basketball => 10,
    Sport.minisoccer => 14,
    Sport.volley => 12,
    Sport.badminton || Sport.tennis || Sport.padel => 4,
  };
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({
    required this.sport,
    required this.value,
    required this.onChanged,
  });

  final Sport sport;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(sport.icon, size: 18, color: C.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(sport.label, style: T.body)),
          IconButton(
            tooltip: 'Kurangi',
            onPressed: value > 2 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$value orang',
              textAlign: TextAlign.center,
              style: T.label,
            ),
          ),
          IconButton(
            tooltip: 'Tambah',
            onPressed: value < 30 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    this.hint = '100000',
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(prefixText: 'Rp', hintText: hint),
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.hours,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> hours;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.label),
        const SizedBox(height: 7),
        DropdownButtonFormField<int>(
          initialValue: hours.contains(value) ? value : hours.first,
          isExpanded: true,
          items: [
            for (final h in hours)
              DropdownMenuItem(
                value: h,
                child: Text('${h.toString().padLeft(2, '0')}:00'),
              ),
          ],
          onChanged: (h) {
            if (h != null) onChanged(h);
          },
        ),
      ],
    );
  }
}
