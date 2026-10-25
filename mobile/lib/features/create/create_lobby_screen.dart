import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Buat room 4 langkah: 1) pilih venue, 2) pilih lapangan (kartu berfoto,
/// seperti memilih kamar hotel), 3) pilih tanggal + jam, 4) atur room.
///
/// Jam diambil dari jam buka lapangan (GET /venues/:id/availability): semua
/// jam kosong bisa dipilih tanpa venue membuka slot dulu. Slot dibuat server
/// saat room dibuat. Ringkasan harga dan tombol ada di footer tetap.
class CreateLobbyScreen extends ConsumerStatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  ConsumerState<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

/// Jam main yang dipilih: lapangan, jam mulai, durasi.
class _Pick {
  const _Pick(this.day, this.hour, this.hours);

  final CourtDay day;
  final int hour;
  final int hours;

  ApiCourt get court => day.court;
  DateTime get start => day.hours.firstWhere((h) => h.hour == hour).start;
  DateTime get end => start.add(Duration(hours: hours));
  int get price => day.rate * hours;
}

class _CreateLobbyScreenState extends ConsumerState<CreateLobbyScreen> {
  final _title = TextEditingController();
  final _search = TextEditingController();

  int _step = 0;
  DateTime _date = wibToday();

  /// Naik tiap muat grid; respons lama (ganti hari/venue cepat) dibuang.
  int _gridGen = 0;
  String? _venueId;
  List<CourtDay> _grid = const [];
  String? _gridError;
  bool _loadingGrid = false;
  String? _courtId;
  int? _hour;
  int _hours = 1;
  int _quota = 8;
  bool _busy = false;

  /// Filter cabang di langkah 1; juga olahraga room di langkah 3.
  Sport? _sport;
  Sport? _playSport;

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

  CourtDay? get _courtDay {
    for (final c in _grid) {
      if (c.court.id == _courtId) return c;
    }
    return null;
  }

  /// Pilihan lengkap bila semua jam dalam durasi kosong.
  _Pick? get _pick {
    final day = _courtDay;
    final hour = _hour;
    if (day == null || hour == null) return null;
    for (var h = hour; h < hour + _hours; h++) {
      if (!day.hours.any((c) => c.hour == h && c.state == HourState.free)) {
        return null;
      }
    }
    return _Pick(day, hour, _hours);
  }

  /// Jam kosong berturut-turut mulai jam terpilih (maks 8). Belum pilih jam = 8.
  int get _maxHours {
    final day = _courtDay;
    final hour = _hour;
    if (day == null || hour == null) return 8;
    var n = 0;
    while (n < 8 &&
        day.hours.any((h) => h.hour == hour + n && h.state == HourState.free)) {
      n++;
    }
    return n;
  }

  Sport get _sportToPlay {
    final court = _courtDay?.court;
    final sports = court?.allSports ?? const <CourtSport>[];
    if (sports.any((s) => s.sport == _playSport)) return _playSport!;
    if (sports.any((s) => s.sport == _sport)) return _sport!;
    return sports.isEmpty ? Sport.badminton : sports.first.sport;
  }

  int get _capacity {
    final court = _courtDay?.court;
    if (court == null) return 8;
    for (final s in court.allSports) {
      if (s.sport == _sportToPlay) return s.capacity.clamp(2, 30);
    }
    return court.capacity.clamp(2, 30);
  }

  Future<void> _loadGrid() async {
    final venueId = _venueId;
    if (venueId == null) return;
    final gen = ++_gridGen;
    setState(() {
      _loadingGrid = true;
      _gridError = null;
      _hour = null;
    });
    List<CourtDay> grid = const [];
    String? error;
    try {
      grid = await loadAvailability(venueId, _date);
    } catch (e) {
      error = apiMessage(e);
    }
    // Hari/venue sudah diganti selama menunggu: jangan timpa grid yang baru.
    if (!mounted || gen != _gridGen) return;
    setState(() {
      _grid = grid;
      _gridError = error;
      _loadingGrid = false;
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
    setState(() {
      _venueId = venue.id;
      _courtId = null;
      _title.clear();
      _step = 1;
    });
  }

  void _pickCourt(ApiCourt court) {
    setState(() {
      _courtId = court.id;
      _playSport = null;
      _step = 2;
    });
    _loadGrid();
  }

  Future<void> _pickDay(DateTime day) async {
    setState(() => _date = day);
    await _loadGrid();
  }

  void _pickHour(CourtDay day, HourCell cell) {
    setState(() {
      // Ketuk slot persis setelah rentang di lapangan yang sama -> tambah durasi
      if (_courtId == day.court.id &&
          _hour != null &&
          cell.hour == _hour! + _hours &&
          _hours < 8) {
        _hours++;
        return;
      }
      // Ketuk slot terakhir di dalam rentang (> 1 jam) -> kurangi durasi
      if (_courtId == day.court.id &&
          _hour != null &&
          _hours > 1 &&
          cell.hour == _hour! + _hours - 1) {
        _hours--;
        return;
      }
      _hour = cell.hour;
      _quota = _quota.clamp(2, _capacity);
      // Durasi tidak boleh melewati jam terisi/tutup berikutnya.
      _hours = _hours.clamp(1, _maxHours);
    });
  }

  /// Nama bawaan, mis. "Tenis Sen". Diganti ikut olahraga selama pemain
  /// belum mengetik nama sendiri.
  String _autoTitle(Sport sport, DateTime start) =>
      '${sport.label} ${_dayName(wib(start))}';

  /// Nama bawaan terakhir yang diisi otomatis; sama dengan isi field = belum diubah pemain.
  String? _lastAutoTitle;

  void _setAutoTitle(Sport sport, DateTime start) {
    _lastAutoTitle = _autoTitle(sport, start);
    _title.text = _lastAutoTitle!;
  }

  void _toDetail(_Pick pick) {
    setState(() {
      // Ganti lapangan/hari: nama bawaan ikut diperbarui.
      if (_title.text.trim().isEmpty || _title.text == _lastAutoTitle) {
        _setAutoTitle(_sportToPlay, pick.start);
      }
      _quota = _quota.clamp(2, _capacity);
      _step = 3;
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

  Future<void> _submit(_Pick pick) async {
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
        .createForHours(
          courtId: pick.court.id,
          start: pick.start,
          hours: pick.hours,
          sport: _sportToPlay,
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
    final perPerson = pricePerPerson(pick.price, _quota);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Room dibuat. ${rupiah(perPerson)} dikunci sebagai host.',
        ),
      ),
    );
    // Dibuka langsung lewat URL: tidak ada halaman untuk kembali.
    context.canPop() ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venuesProvider);
    final venue = _venueOf(venues);
    final pick = _pick;

    // Back sistem mundur satu langkah; hanya langkah 1 yang menutup halaman.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) setState(() => _step--);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                // Key per langkah: tiap langkah mulai dari atas, bukan mewarisi posisi scroll.
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _venueStep(venues),
                    1 => venue == null ? _venueStep(venues) : _courtStep(venue),
                    2 =>
                      venue == null || _courtId == null
                          ? _venueStep(venues)
                          : _hourStep(venue),
                    _ =>
                      venue == null || pick == null
                          ? _venueStep(venues)
                          : _detailStep(venue, pick),
                  },
                ),
              ),
              if (_step == 2 && venue != null && _courtId != null)
                _hourFooter(pick),
              if (_step == 3 && venue != null && pick != null)
                _detailFooter(pick),
            ],
          ),
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
                v.courts.any(
                  (c) => c.allSports.any((s) => s.sport == _sport),
                )) &&
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
          for (final venue in list)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _VenueCard(venue: venue, onTap: _pickVenue),
            ),
      ],
    );
  }

  // ── Langkah 2: lapangan ──────────────────────────────────────────────────

  Widget _courtStep(ApiVenue venue) {
    // Filter cabang dari langkah 1 ikut dipakai; tidak ada yang cocok = tampilkan semua.
    final matching = [
      for (final c in venue.courts)
        if (_sport == null || c.allSports.any((s) => s.sport == _sport)) c,
    ];
    final courts = matching.isEmpty ? venue.courts : matching;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          step: 1,
          title: venue.name,
          onBack: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 14),
        if (venue.address.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: C.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(venue.address, style: T.small)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('${courts.length} lapangan', style: T.label),
        if (courts.isEmpty)
          const EmptyState(
            icon: Icons.stadium_outlined,
            title: 'Belum ada lapangan',
            message: 'Venue ini belum menyiapkan lapangan untuk dipesan.',
          )
        else
          for (final court in courts)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _CourtCard(court: court, onTap: () => _pickCourt(court)),
            ),
      ],
    );
  }

  // ── Langkah 3: tanggal & jam ─────────────────────────────────────────────

  Widget _hourStep(ApiVenue venue) {
    final today = wibToday();
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    final day = _courtDay;
    ApiCourt? court;
    for (final c in venue.courts) {
      if (c.id == _courtId) court = c;
    }
    final maxHours = _maxHours;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StepHeader(
          step: 2,
          title: court?.name ?? venue.name,
          onBack: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _DayChip(
              day: days[i],
              active: days[i] == _date,
              onTap: () => _pickDay(days[i]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingGrid)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gridError != null)
          EmptyState(
            icon: Icons.error_outline,
            title: 'Jadwal gagal dimuat',
            message: _gridError!,
            action: GhostButton(
              label: 'Coba lagi',
              icon: Icons.refresh,
              onPressed: _loadGrid,
            ),
          )
        else if (day == null)
          const EmptyState(
            icon: Icons.stadium_outlined,
            title: 'Lapangan tidak tersedia',
            message:
                'Lapangan ini sedang tidak bisa dipesan. Pilih lapangan lain.',
          )
        else ...[
          Text('${_shortRupiah(day.rate)}/jam', style: T.label),
          const SizedBox(height: 8),
          for (final cell in day.hours)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${cell.hour.toString().padLeft(2, '0')}.00',
                      style: T.caption,
                    ),
                  ),
                  Expanded(
                    child: _HourCell(
                      cell: cell,
                      selected:
                          _hour != null &&
                          cell.hour >= _hour! &&
                          cell.hour < _hour! + _hours,
                      onTap: () => _pickHour(day, cell),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const _Legend(),
          const SizedBox(height: 18),
          const _Label('Durasi main'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final h in const [1, 2, 3, 4])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: h == 4 ? 0 : 8),
                    child: _ChoiceChip(
                      label: '$h jam',
                      selected: _hours == h,
                      // Lebih panjang dari jam kosong berturut-turut = tidak bisa dipilih.
                      onTap: h <= maxHours
                          ? () => setState(() => _hours = h)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Opsi tambah lebih:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.muted,
                ),
              ),
              const SizedBox(width: 10),
              _DurationStepper(
                hours: _hours,
                onDecrement: _hours > 1 ? () => setState(() => _hours--) : null,
                onIncrement: _hours < maxHours
                    ? () => setState(() => _hours++)
                    : null,
              ),
              const Spacer(),
              if (_hours > 4)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: C.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: C.primaryCheck),
                  ),
                  child: Text(
                    '$_hours jam dipilih',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: C.primaryDeep,
                    ),
                  ),
                ),
            ],
          ),
          if (_hour != null && _pick == null) ...[
            const SizedBox(height: 10),
            Text(
              'Jam setelah ${_hour.toString().padLeft(2, '0')}:00 tidak cukup '
              'untuk $_hours jam. Pilih jam lain atau kurangi durasi.',
              style: T.small.copyWith(color: C.danger),
            ),
          ],
        ],
      ],
    );
  }

  // ── Langkah 4: atur room ─────────────────────────────────────────────────

  Widget _detailStep(ApiVenue venue, _Pick pick) {
    final capacity = _capacity;
    final options = [
      for (final value in const [4, 6, 8, 10])
        if (value <= capacity) value,
    ];
    final sports = pick.court.allSports;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _StepHeader(
          step: 3,
          title: 'Atur room',
          onBack: () => setState(() => _step = 2),
        ),
        const SizedBox(height: 14),
        _VenueSummary(
          venue: venue,
          pick: pick,
          onChange: () => setState(() => _step = 2),
        ),
        if (sports.length > 1) ...[
          const SizedBox(height: 22),
          const _Label('Olahraga'),
          const SizedBox(height: 4),
          const Text(
            'Lapangan serbaguna: pilih yang akan dimainkan.',
            style: T.small,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sports)
                _ChoiceChip(
                  label: '${s.sport.label} · ${s.capacity} orang',
                  selected: _sportToPlay == s.sport,
                  onTap: () => setState(() {
                    if (_title.text == _lastAutoTitle) {
                      _setAutoTitle(s.sport, pick.start);
                    }
                    _playSport = s.sport;
                    _quota = _quota.clamp(2, s.capacity.clamp(2, 30));
                  }),
                ),
            ],
          ),
        ],
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
        Text(
          'Termasuk kamu. Maksimal $capacity orang untuk '
          '${_sportToPlay.label}. Harga per orang ikut berubah.',
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
                    options: options,
                    capacity: capacity,
                    pricePerPerson: pricePerPerson(
                      pick.price,
                      value == 0 ? _quota : value,
                    ),
                    onTap: () => value == 0
                        ? _pickQuota(capacity, pick.price)
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
        _DeadlineBox(start: pick.start),
        const SizedBox(height: 8),
        const Text(
          'Kalau absen belum penuh, room batal dan semua dana dilepas.',
          style: T.caption,
        ),
      ],
    );
  }

  // ── Footer tetap ─────────────────────────────────────────────────────────

  Widget _hourFooter(_Pick? pick) {
    return _FooterBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pick != null) ...[
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: C.primary),
                const SizedBox(width: 6),
                const Text(
                  'Durasi main:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
                const SizedBox(width: 8),
                _DurationStepper(
                  hours: _hours,
                  onDecrement: _hours > 1
                      ? () => setState(() => _hours--)
                      : null,
                  onIncrement: _hours < _maxHours
                      ? () => setState(() => _hours++)
                      : null,
                ),
                const Spacer(),
                Text(
                  '${formatTime(wib(pick.start))}–${formatTime(wib(pick.end))}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pick != null
                          ? '${pick.court.name} · ${pick.hours} jam'
                          : _hour == null
                          ? 'Pilih jam dulu'
                          : 'Durasi melewati jam terisi',
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
                      pick != null
                          ? '${formatDate(wib(pick.start))} · ${rupiah(pick.price)}'
                          : _hour == null
                          ? 'Ketuk jam kosong di jadwal'
                          : 'Kurangi durasi atau pilih jam lain',
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
                  onPressed: pick == null ? null : () => _toDetail(pick),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailFooter(_Pick pick) {
    final perPerson = pricePerPerson(pick.price, _quota);
    return _FooterBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${rupiah(pick.price)} ÷ $_quota orang',
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
            onPressed: _busy ? null : () => _submit(pick),
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
                    'Buat room • langkah ${step + 1} dari 4',
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
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
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

/// Kartu venue berfoto sampul (foto venue, atau foto lapangan pertama).
class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.onTap});

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

    return _Card(
      onTap: () => onTap(venue),
      children: [
        CourtPhoto(url: venue.coverUrl, height: 150, radius: 0),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
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
              const Icon(Icons.chevron_right, size: 22, color: C.faint),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu lapangan ala pilih kamar hotel: galeri foto, olahraga, jam buka, tarif.
class _CourtCard extends StatelessWidget {
  const _CourtCard({required this.court, required this.onTap});

  final ApiCourt court;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = court.priceWeekend;
    return _Card(
      onTap: onTap,
      children: [
        _PhotoGallery(photos: court.photos),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                court.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: C.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in court.allSports)
                    _Tag('${s.sport.label} · ${s.capacity} orang'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 15, color: C.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Buka ${_hh(court.openHour)}–${_hh(court.closeHour)}',
                    style: T.small,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_shortRupiah(court.pricePerHour)}/jam',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: C.ink,
                          ),
                        ),
                        if (weekend != null && weekend != court.pricePerHour)
                          Text(
                            'Sab–Min ${_shortRupiah(weekend)}/jam',
                            style: T.caption,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: SebarButton(
                      label: 'Pilih jam',
                      height: 40,
                      radius: 999,
                      onPressed: onTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Foto lapangan yang bisa digeser, dengan penanda "1/3".
class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photos});

  final List<CourtPhotoInfo> photos;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    const height = 180.0;
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const CourtPhoto(url: null, height: height, radius: 0);
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Mouse ikut bisa menggeser (Flutter web/desktop).
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) =>
                  CourtPhoto(url: photos[i].url, height: height, radius: 0),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_page + 1}/${photos.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: C.primaryDeep,
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

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  /// null = di luar jam buka lapangan ini.
  final HourCell? cell;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final free = cell?.state == HourState.free;
    final label = selected
        ? 'Dipilih'
        : switch (cell?.state) {
            null || HourState.closed => 'Tutup',
            HourState.taken => 'Terisi',
            HourState.past => 'Lewat',
            HourState.free => '',
          };
    final background = selected
        ? C.primaryFill
        : free
        ? C.surface
        : C.surfaceAlt;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: free ? onTap : null,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? C.primaryCheck : C.line),
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// null = tidak bisa dipilih (tampil redup).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: selected ? C.primarySoft : C.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? C.primaryCheck : C.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? C.primaryDeep : C.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.hours,
    this.onDecrement,
    this.onIncrement,
  });

  final int hours;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            color: C.ink,
            disabledColor: C.faint,
            onPressed: onDecrement,
            tooltip: 'Kurangi 1 jam',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$hours jam',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.ink,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            color: C.primary,
            disabledColor: C.faint,
            onPressed: onIncrement,
            tooltip: 'Tambah 1 jam',
          ),
        ],
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
          ('Terisi / tutup', C.surfaceAlt, true),
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
    required this.pick,
    required this.onChange,
  });

  final ApiVenue venue;
  final _Pick pick;
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
                  '${venue.name} • ${pick.court.name}',
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
                  '${formatDate(wib(pick.start))} • '
                  '${formatTime(wib(pick.start))}–${formatTime(wib(pick.end))} (${pick.hours} jam)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
                Text(
                  '${rupiah(pick.price)} · ${_shortRupiah(pick.day.rate)}/jam',
                  style: T.small,
                ),
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
    required this.options,
    required this.capacity,
    required this.pricePerPerson,
    required this.onTap,
  });

  /// null = "Lain".
  final int? value;
  final int total;
  final List<int> options;
  final int capacity;
  final int pricePerPerson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == null ? !options.contains(total) : value == total;
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
  const _DeadlineBox({required this.start});

  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final deadline = start.subtract(const Duration(hours: 6));
    final label =
        '6 jam sebelum main • ${_dayName(wib(deadline))} ${formatTime(wib(deadline))}';

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

/// 6 -> "06.00", 24 -> "24.00".
String _hh(int hour) => '${hour.toString().padLeft(2, '0')}.00';

String _dayName(DateTime d) {
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  return days[d.weekday - 1];
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
