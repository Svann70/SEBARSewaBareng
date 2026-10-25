import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/state.dart';

// ─── Jadwal ────────────────────────────────────────────────────────────────

/// Jadwal otomatis: semua jam di dalam jam buka tiap lapangan aktif. Pemilik
/// hanya memantau; ketuk jam kosong untuk menutupnya, jam ditutup untuk
/// membukanya lagi, jam terisi untuk melihat siapa yang memesan.
class VenueScheduleTab extends ConsumerStatefulWidget {
  const VenueScheduleTab({super.key});

  @override
  ConsumerState<VenueScheduleTab> createState() => _VenueScheduleTabState();
}

class _VenueScheduleTabState extends ConsumerState<VenueScheduleTab> {
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(venueSlotsProvider);
    final notifier = ref.read(venueSlotsProvider.notifier);
    final day = wibToday().add(Duration(days: _day));
    final grid = ref.watch(venueDayProvider(day));

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPad,
        children: [
          const Text('Jadwal', style: T.h1),
          const SizedBox(height: 2),
          Text(formatLongDate(day), style: T.small),
          const SizedBox(height: 14),
          _DayStrip(selected: _day, onPick: (d) => setState(() => _day = d)),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend('Kosong', C.surface, C.line),
              _Legend('Terisi', C.amberSoft, C.amber),
              _Legend('Ditutup', Color(0xFFFBE4E2), C.danger),
              _Legend('Lewat batas', C.surfaceAlt, C.surfaceAlt),
            ],
          ),
          const SizedBox(height: 14),
          grid.when(
            skipLoadingOnReload: true,
            data: (courts) => courts.isEmpty
                ? EmptyState(
                    icon: Icons.sports_score,
                    title: 'Belum ada lapangan aktif',
                    message:
                        'Tambah lapangan sekali, jadwal terisi otomatis dari '
                        'jam buka.',
                    action: GhostButton(
                      label: 'Tambah lapangan',
                      icon: Icons.add,
                      onPressed: () => context.push('/venue/court/new'),
                    ),
                  )
                : Column(
                    children: [
                      for (final c in courts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CourtHours(
                            day: c,
                            onTap: (cell) => _onHour(c, cell),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Jadwal gagal dimuat',
              message: apiMessage(e),
              action: GhostButton(
                label: 'Muat ulang',
                icon: Icons.refresh,
                onPressed: notifier.refresh,
              ),
            ),
          ),
          SurfaceCard(
            radius: 18,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: C.muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ketuk jam kosong untuk menutupnya (perbaikan atau dipakai '
                    'sendiri). Jam terisi tidak bisa ditutup.',
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

  Future<void> _onHour(CourtDay day, HourCell cell) async {
    final notifier = ref.read(venueSlotsProvider.notifier);
    final when = '${formatTime(wib(cell.start))} di ${day.court.name}';
    switch (cell.state) {
      case HourState.taken:
        // Room bisa dibuat pemain kapan saja; muat ulang bila namanya belum ada.
        var who = notifier.bookingAt(day.court.id, cell.start);
        if (who == null) {
          await notifier.refresh();
          if (!mounted) return;
          who = notifier.bookingAt(day.court.id, cell.start);
        }
        _toast(
          '${formatTime(wib(cell.start))} · ${who ?? 'Sudah dipesan pemain.'}',
        );
      case HourState.past:
        _toast('Jam $when sudah lewat batas pemesanan (6 jam sebelum main).');
      case HourState.free:
      case HourState.closed:
        final closing = cell.state == HourState.free;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              closing ? 'Tutup jam ini?' : 'Buka lagi jam ini?',
              style: T.h2,
            ),
            content: Text(
              closing
                  ? 'Jam $when tidak bisa dipesan pemain sampai dibuka lagi.'
                  : 'Jam $when bisa dipesan pemain lagi.',
              style: T.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: C.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  closing ? 'Tutup' : 'Buka',
                  style: TextStyle(color: closing ? C.danger : C.primary),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final error = closing
            ? await notifier.closeHour(day, cell)
            : await notifier.reopenHour(day, cell);
        if (!mounted) return;
        _toast(
          error ?? (closing ? 'Jam $when ditutup.' : 'Jam $when dibuka lagi.'),
        );
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _CourtHours extends StatelessWidget {
  const _CourtHours({required this.day, required this.onTap});

  final CourtDay day;
  final ValueChanged<HourCell> onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.court.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.h3,
                ),
              ),
              Text('${rupiah(day.rate)}/jam', style: T.small),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${day.taken} dari ${day.hours.length} jam terisi · '
            '${[for (final s in day.court.allSports) s.sport.label].join(', ')}',
            style: T.caption,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in day.hours)
                _HourChip(cell: h, onTap: () => onTap(h)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({required this.cell, required this.onTap});

  final HourCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, status) = switch (cell.state) {
      HourState.free => (C.surface, C.line, C.ink, 'kosong'),
      HourState.taken => (C.amberSoft, C.amber, C.ink, 'terisi'),
      HourState.closed => (
        const Color(0xFFFBE4E2),
        C.danger,
        C.danger,
        'ditutup',
      ),
      HourState.past => (C.surfaceAlt, C.surfaceAlt, C.faint, 'lewat batas'),
    };
    return Semantics(
      button: true,
      label: '${formatTime(wib(cell.start))} $status',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 58,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Text(
              formatTime(wib(cell.start)),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.fill, this.border);

  final String label;
  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: T.caption),
      ],
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
    final now = wibToday();
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

// ─── Scan ──────────────────────────────────────────────────────────────────

class VenueScanTab extends StatefulWidget {
  const VenueScanTab({super.key});

  @override
  State<VenueScanTab> createState() => _VenueScanTabState();
}

class _VenueScanTabState extends State<VenueScanTab> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _result;
  String? _resultDetail;

  /// (kode, keterangan, valid) — dari server, terbaru di atas.
  final _history = <(String, String, bool)>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _who(Map<String, dynamic> t) {
    final start = DateTime.tryParse(t['startAt'] as String? ?? '');
    final time = start == null ? '' : ' · ${formatTime(wib(start))}';
    return '${t['playerName'] ?? 'Pemain'} · ${t['roomTitle'] ?? ''}$time · ${t['courtName'] ?? ''}';
  }

  Future<void> _loadHistory() async {
    try {
      final data = await api.get('/venue/checkins') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll([
            for (final t
                in (data['items'] as List? ?? []).cast<Map<String, dynamic>>())
              (formatCheckinCode(t['code'] as String? ?? ''), _who(t), true),
          ]);
      });
    } catch (_) {
      // Riwayat hanya pelengkap; validasi tetap bisa dipakai.
    }
  }

  Future<void> _scan() async {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final t =
          await api.post('/venue/checkins/scan', body: {'code': code})
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _result = 'VALID';
        _resultDetail = _who(t);
        _history.insert(0, (
          formatCheckinCode(t['code'] as String? ?? code),
          _who(t),
          true,
        ));
        _code.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = 'GAGAL';
        _resultDetail = apiMessage(error);
        _history.insert(0, (code.toUpperCase(), apiMessage(error), false));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: kScreenPad,
      children: [
        const Text('Scan tiket', style: T.h1),
        const SizedBox(height: 3),
        Text(
          'Ketik kode check-in di tiket pemain saat masuk lapangan.',
          style: T.small,
        ),
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
              const Text(
                'Scan kamera menyusul; pakai kode di bawah',
                style: T.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Kode check-in pemain',
          controller: _code,
          hint: 'A1B2C-3D4E5',
          prefixIcon: Icons.keyboard,
        ),
        const SizedBox(height: 12),
        SebarButton(
          label: _busy ? 'Memeriksa…' : 'Validasi tiket',
          icon: Icons.check_circle_outline,
          busy: _busy,
          onPressed: _busy ? null : _scan,
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
        if (_history.isEmpty)
          const Text('Belum ada tiket yang discan.', style: T.small),
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
