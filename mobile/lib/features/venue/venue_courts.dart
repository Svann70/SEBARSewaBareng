import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Layar kelola lapangan: foto (hero + galeri), nama, tarif weekday/weekend,
/// plus daftar lapangan lain. Dibuka dari tab Jadwal.
class VenueCourtsScreen extends ConsumerStatefulWidget {
  const VenueCourtsScreen({super.key, this.initialCourt = 0});

  /// Index lapangan aktif saat layar dibuka (index di daftar courts).
  final int initialCourt;

  @override
  ConsumerState<VenueCourtsScreen> createState() => _VenueCourtsScreenState();
}

class _VenueCourtsScreenState extends ConsumerState<VenueCourtsScreen> {
  late String _courtId;
  final _name = TextEditingController();
  final _weekday = TextEditingController();
  final _weekend = TextEditingController();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final courts = ref.read(venueSlotsProvider.notifier).courts;
    if (courts.isEmpty) {
      _courtId = '';
    } else {
      _courtId = courts[widget.initialCourt.clamp(0, courts.length - 1)].id;
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _weekday.dispose();
    _weekend.dispose();
    super.dispose();
  }

  List<ApiCourt> get _courts => ref.read(venueSlotsProvider.notifier).courts;

  ApiCourt? get _court {
    final courts = _courts;
    for (final c in courts) {
      if (c.id == _courtId) return c;
    }
    return courts.isEmpty ? null : courts.first;
  }

  void _load() {
    final courts = _courts;
    for (final court in courts) {
      if (court.id != _courtId) continue;
      _name.text = court.name;
      _weekday.text = '${court.pricePerHour}';
      _weekend.text = '${court.priceWeekend ?? court.pricePerHour}';
      return;
    }
  }

  void _select(String courtId) {
    if (courtId == _courtId) return;
    setState(() => _courtId = courtId);
    _load();
  }

  Future<void> _save() async {
    final court = _court;
    final name = _name.text.trim();
    final weekday = int.tryParse(_weekday.text.replaceAll('.', ''));
    final weekend = int.tryParse(_weekend.text.replaceAll('.', ''));
    if (court == null || name.length < 2 || weekday == null || weekday < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan tarif weekday wajib diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    final error = await ref
        .read(venueSlotsProvider.notifier)
        .setCourtPriceRemote(
          court.id,
          weekday,
          priceWeekend: weekend,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Perubahan nama/harga ${court.name} tersimpan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch state slot supaya daftar lapangan segar setelah tambah/simpan.
    ref.watch(venueSlotsProvider);
    final courts = _courts;
    final venueName = venueProfile.name;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: RoundBackHeader(
                title: 'Lapangan',
                actions: [
                  GhostButton(
                    label: 'Lapangan',
                    icon: Icons.add,
                    height: 40,
                    onPressed: () => showAddCourtSheet(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: kScreenPad,
                children: [
                  if (courts.isEmpty)
                    const EmptyState(
                      icon: Icons.stadium_outlined,
                      title: 'Belum ada lapangan',
                      message: 'Tambahkan lapangan dulu supaya slot bisa dibuka.',
                    )
                  else ...[
                    _CourtEditor(
                      key: ValueKey(_courtId),
                      court: _court!,
                      venueName: venueName,
                      name: _name,
                      weekday: _weekday,
                      weekend: _weekend,
                      saving: _saving,
                      onSave: _save,
                      onPick: _load,
                    ), // setelah galeri berubah, refresh teks
                    const SizedBox(height: 20),
                    const SectionHeader('Lapangan lain'),
                    const SizedBox(height: 8),
                    for (final c in courts)
                      if (c.id != _courtId) ...[
                        _CourtRow(
                          court: c,
                          venueName: venueName,
                          onTap: () => _select(c.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form edit satu lapangan sesuai mockup: foto hero + galeri, nama,
/// weekday/weekend, catatan sinkron, tombol simpan.
class _CourtEditor extends ConsumerWidget {
  const _CourtEditor({
    super.key,
    required this.court,
    required this.venueName,
    required this.name,
    required this.weekday,
    required this.weekend,
    required this.saving,
    required this.onSave,
    required this.onPick,
  });

  final ApiCourt court;
  final String venueName;
  final TextEditingController name;
  final TextEditingController weekday;
  final TextEditingController weekend;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onPick;

  String get _key => courtPhotoKey(venueName, court.name);

  Future<void> _pickMain(BuildContext context, WidgetRef ref) async {
    final picked = await showCourtPhotoPickerSheet(context, court: court);
    if (picked == null) return;
    ref.read(courtPhotosProvider.notifier).setPhoto(_key, picked);
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await showCourtPhotoPickerSheet(context, court: court);
    if (picked == null) return;
    ref.read(courtGalleriesProvider.notifier).addPhoto(_key, picked);
    onPick();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(courtGalleriesProvider)[_key] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CourtPhoto(venue: venueName, court: court.name, height: 170),
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Center(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _pickMain(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 15,
                            color: C.ink,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ganti foto utama',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: C.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        /// Galeri: foto hasil tambah venue + tile pintas prasetel + tambah.
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final url in gallery) _GalleryTile(url: url, onUse: (value) {
              ref.read(courtPhotosProvider.notifier).setPhoto(_key, value);
            }),
              const SizedBox(width: 8),
              for (final preset in CourtPhoto.presets(_key).take(3))
                _GalleryTile(
                  url: preset,
                  onUse: (value) =>
                      ref.read(courtPhotosProvider.notifier).setPhoto(_key, value),
                ),
              _GalleryAddTile(onTap: () => _addPhoto(context, ref)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Nama lapangan',
          controller: name,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: LabeledField(
                label: 'Weekday / jam',
                controller: weekday,
                keyboard: TextInputType.number,
                prefixText: 'Rp',
                hint: '160.000',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LabeledField(
                label: 'Weekend / jam',
                controller: weekend,
                keyboard: TextInputType.number,
                prefixText: 'Rp',
                hint: '200.000',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SurfaceCard(
          radius: 16,
          color: C.surfaceAlt,
          shadow: false,
          child: Text(
            'Foto dan harga baru langsung tampil di semua room yang memakai '
            '${court.name}. Room yang sudah berjalan tetap memakai harga lama.',
            style: T.caption,
          ),
        ),
        const SizedBox(height: 14),
        SebarButton(
          label: 'Simpan perubahan',
          busy: saving,
          onPressed: onSave,
        ),
      ],
    );
  }
}

/// Baris lapangan lain: thumbnail foto, nama, harga per hari.
class _CourtRow extends ConsumerWidget {
  const _CourtRow({
    required this.court,
    required this.venueName,
    required this.onTap,
  });

  final ApiCourt court;
  final String venueName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = courtPhotoKey(venueName, court.name);
    final photos = ref.watch(courtGalleriesProvider)[key];
    final url =
        ref.watch(courtPhotosProvider)[key] ??
        (photos == null || photos.isEmpty ? null : photos.first);
    final hasPhoto = url != null;

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
              SizedBox(
                width: 56,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: url == null
                      ? const _RowThumbFallback()
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          errorBuilder: (_, _, _) => const _RowThumbFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rupiah(court.pricePerHour)} · '
                      'weekend ${rupiah(court.priceWeekend ?? court.pricePerHour)}',
                      style: const TextStyle(fontSize: 12, color: C.faint),
                    ),
                    if (!hasPhoto)
                      const Text(
                        'Belum ada foto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.amber,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 20, color: C.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowThumbFallback extends StatelessWidget {
  const _RowThumbFallback();
  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: C.primarySoft);
}

/// Thumbnail galeri kecil; tap memasangnya sebagai foto utama.
class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.url, required this.onUse});

  final String url;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onUse(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: C.primarySoft,
                child: Icon(Icons.image_outlined, size: 16, color: C.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryAddTile extends StatelessWidget {
  const _GalleryAddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.primary, width: 1.5),
        ),
        child: const Icon(Icons.add, size: 18, color: C.primary),
      ),
    );
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

/// Sheet pilih foto lapangan: prasetel + tautan sendiri.
Future<String?> showCourtPhotoPickerSheet(
  BuildContext context, {
  required ApiCourt court,
}) {
  final url = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final key = courtPhotoKey(venueProfile.name, court.name);
      return SheetWrap(
        title: 'Foto ${court.name}',
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
      );
    },
  )..whenComplete(url.dispose);
}

/// Sheet tambah lapangan baru (nama, olahraga, tarif weekday/weekend, kapasitas).
Future<void> showAddCourtSheet(BuildContext context) async {
  final name = TextEditingController();
  final weekday = TextEditingController(text: '100000');
  final weekend = TextEditingController(text: '125000');
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
              controller: weekday,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarif weekday per jam',
                prefixText: 'Rp',
              ),
            ),
            TextField(
              controller: weekend,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarif weekend per jam',
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
  final pricePerHour = int.tryParse(weekday.text.trim());
  final priceWeekend = int.tryParse(weekend.text.trim());
  final capacityValue = int.tryParse(capacity.text.trim());
  final courtName = name.text.trim();
  name.dispose();
  weekday.dispose();
  weekend.dispose();
  capacity.dispose();
  if (saved != true || !context.mounted) return;
  final error = await ProviderScope.containerOf(context)
      .read(venueSlotsProvider.notifier)
      .addCourtRemote(
        name: courtName,
        sport: sport,
        pricePerHour: pricePerHour ?? 0,
        priceWeekend: priceWeekend,
        capacity: capacityValue ?? 0,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error ?? 'Lapangan $courtName ditambahkan.')),
  );
}
