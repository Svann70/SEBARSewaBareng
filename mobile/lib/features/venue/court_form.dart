import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Form satu lapangan: nama, olahraga + kapasitas (serbaguna), harga
/// weekday/weekend, jam buka–tutup. [courtId] null = tambah lapangan baru.
/// Setelah disimpan, semua jam di dalam jam buka otomatis bisa dipesan.
class CourtFormScreen extends ConsumerStatefulWidget {
  const CourtFormScreen({super.key, this.courtId});

  final String? courtId;

  @override
  ConsumerState<CourtFormScreen> createState() => _CourtFormScreenState();
}

class _CourtFormScreenState extends ConsumerState<CourtFormScreen> {
  final _name = TextEditingController();
  final _weekday = TextEditingController();
  final _weekend = TextEditingController();
  CourtDraft? _draft;
  bool _busy = false;
  String? _error;

  /// Edit tapi lapangannya tidak ditemukan (muat gagal): jangan jadikan
  /// form tambah, nanti tersimpan sebagai lapangan dobel.
  String? _loadError;

  bool get _editing => widget.courtId != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final notifier = ref.read(venueSlotsProvider.notifier);
    setState(() => _loadError = null);
    if (!notifier.hasVenue) await notifier.refresh();
    if (!mounted) return;
    ApiCourt? court;
    for (final c in notifier.courts) {
      if (c.id == widget.courtId) court = c;
    }
    if (_editing && court == null) {
      setState(
        () => _loadError =
            notifier.lastError ?? 'Lapangan tidak ditemukan di akun ini.',
      );
      return;
    }
    final draft = court == null
        ? CourtDraft(name: 'Lapangan ${notifier.courts.length + 1}')
        : CourtDraft.from(court);
    _name.text = draft.name;
    _weekday.text = draft.weekdayPrice?.toString() ?? '';
    _weekend.text = draft.weekendPrice?.toString() ?? '';
    setState(() => _draft = draft);
  }

  @override
  void dispose() {
    _name.dispose();
    _weekday.dispose();
    _weekend.dispose();
    super.dispose();
  }

  static int? _parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _save() async {
    final d = _draft;
    if (d == null || _busy) return;
    d
      ..name = _name.text
      ..weekdayPrice = _parse(_weekday.text)
      ..weekendPrice = _weekend.text.trim().isEmpty
          ? null
          : _parse(_weekend.text);
    final invalid = d.validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(venueSlotsProvider.notifier).saveCourt(d);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editing
              ? '${d.name.trim()} tersimpan.'
              : '${d.name.trim()} ditambahkan. Pemain sudah bisa memesan.',
        ),
      ),
    );
    context.canPop() ? context.pop() : context.go('/venue');
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    return Scaffold(
      body: SafeArea(
        child: _loadError != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const RoundBackHeader(title: 'Edit lapangan'),
                    const Spacer(),
                    EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Lapangan gagal dimuat',
                      message: _loadError!,
                      action: GhostButton(
                        label: 'Coba lagi',
                        icon: Icons.refresh,
                        onPressed: _load,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              )
            : d == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  RoundBackHeader(
                    title: _editing ? 'Edit lapangan' : 'Tambah lapangan',
                  ),
                  const SizedBox(height: 14),
                  if (!_editing) ...[
                    SurfaceCard(
                      radius: 14,
                      color: C.primarySoft,
                      border: false,
                      child: Text(
                        'Isi sekali saja. Setelah disimpan, semua jam di '
                        'dalam jam buka otomatis bisa dipesan pemain.',
                        style: T.small.copyWith(color: C.primaryDeep),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  LabeledField(
                    label: 'Nama lapangan',
                    controller: _name,
                    hint: 'Contoh: Lapangan A',
                  ),
                  const SizedBox(height: 18),
                  const Text('Olahraga & kapasitas pemain', style: T.label),
                  const SizedBox(height: 4),
                  Text(
                    'Satu lapangan bisa untuk beberapa olahraga. Satu jam '
                    'tetap untuk satu pemesan.',
                    style: T.caption,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sport in Sport.values)
                        FilterChip(
                          label: Text(sport.label),
                          selected: d.sports.containsKey(sport),
                          onSelected: (on) => setState(
                            () => on
                                ? d.sports[sport] = _defaultCapacity(sport)
                                : d.sports.remove(sport),
                          ),
                        ),
                    ],
                  ),
                  for (final entry in d.sports.entries)
                    _CapacityRow(
                      sport: entry.key,
                      value: entry.value,
                      onChanged: (v) => setState(() => d.sports[entry.key] = v),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(
                          label: 'Harga/jam Sen–Jum',
                          controller: _weekday,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceField(
                          label: 'Harga/jam Sab–Min',
                          controller: _weekend,
                          hint: 'Sama',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HourPicker(
                          label: 'Jam buka',
                          value: d.openHour,
                          hours: [for (var h = 0; h <= 23; h++) h],
                          onChanged: (h) => setState(() => d.openHour = h),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HourPicker(
                          label: 'Jam tutup',
                          value: d.closeHour,
                          hours: [for (var h = 1; h <= 24; h++) h],
                          onChanged: (h) => setState(() => d.closeHour = h),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('Foto lapangan', style: T.label),
                  const SizedBox(height: 4),
                  if (_editing)
                    _CourtPhotos(courtId: widget.courtId!)
                  else
                    Text(
                      'Foto bisa ditambah setelah lapangan disimpan: buka menu ⋮ → Edit.',
                      style: T.caption,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: T.small.copyWith(color: C.danger)),
                  ],
                  const SizedBox(height: 20),
                  SebarButton(
                    label: _editing ? 'Simpan perubahan' : 'Tambah lapangan',
                    icon: Icons.check,
                    busy: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
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

/// Foto lapangan di Supabase Storage (lewat backend). Foto pertama = sampul
/// yang dilihat pemain di detail room.
class _CourtPhotos extends ConsumerStatefulWidget {
  const _CourtPhotos({required this.courtId});

  final String courtId;

  @override
  ConsumerState<_CourtPhotos> createState() => _CourtPhotosState();
}

class _CourtPhotosState extends ConsumerState<_CourtPhotos> {
  static const _max = 6;
  bool _busy = false;
  String? _error;

  List<CourtPhotoInfo> get _photos {
    for (final c in ref.read(venueSlotsProvider.notifier).courts) {
      if (c.id == widget.courtId) return c.photos;
    }
    return const [];
  }

  Future<void> _add() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() => _error = 'Foto maksimal 5 MB.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(venueSlotsProvider.notifier)
        // Jenis foto dicek server dari isi berkas, bukan dari header ini.
        .addCourtPhoto(widget.courtId, bytes, 'application/octet-stream');
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _delete(CourtPhotoInfo photo) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .deleteCourtPhoto(widget.courtId, photo.id);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(venueSlotsProvider);
    final photos = _photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maksimal $_max foto (JPG/PNG/WEBP, ≤ 5 MB). Foto pertama jadi sampul.',
          style: T.caption,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, p) in photos.indexed)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      p.url,
                      width: 96,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 96,
                        height: 72,
                        color: C.surfaceAlt,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  if (i == 0)
                    const Positioned(
                      left: 4,
                      bottom: 4,
                      child: Pill(
                        'Sampul',
                        background: C.primarySoft,
                        color: C.primaryDeep,
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      tooltip: 'Hapus foto',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy ? null : () => _delete(p),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                    ),
                  ),
                ],
              ),
            if (photos.length < _max)
              Material(
                color: C.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _busy ? null : _add,
                  child: Container(
                    width: 96,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.line),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: C.primary,
                              ),
                              SizedBox(height: 2),
                              Text('Tambah foto', style: T.caption),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: T.small.copyWith(color: C.danger)),
        ],
      ],
    );
  }
}
