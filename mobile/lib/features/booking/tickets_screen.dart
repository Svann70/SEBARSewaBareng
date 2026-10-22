import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  int _tab = 0;

  static const _tabs = ['Siap dipakai', 'Menunggu', 'Selesai'];

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    final now = DateTime.now();
    final ready = bookings
        .where((b) => b.end.isAfter(now) && !b.checkedIn)
        .toList();
    final done = bookings.where((b) => b.checkedIn || !b.end.isAfter(now));
    final shown = switch (_tab) {
      1 => <Booking>[],
      2 => done.toList(),
      _ => ready,
    };

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: C.primary,
        backgroundColor: C.surface,
        onRefresh: () async {
          await ref.read(bookingsProvider.notifier).refresh();
        },
        child: ListView(
          padding: kScreenPad,
          children: [
            const Text('Tiket', style: T.h1),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Tab(
                        label: i == 1 ? '${_tabs[i]} · 0' : _tabs[i],
                        active: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              EmptyState(
                icon: Icons.qr_code_2,
                title: _tab == 1
                    ? 'Tidak ada yang menunggu'
                    : 'Belum ada tiket',
                message: _tab == 1
                    ? 'Tiket terbit otomatis begitu absen room penuh.'
                    : 'Tiket terbit otomatis saat kuota room terpenuhi.',
                action: GhostButton(
                  label: 'Cari room',
                  icon: Icons.search,
                  onPressed: () => context.go('/home'),
                ),
              )
            else
              for (final b in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TicketTile(
                    day: const [
                      'Sen',
                      'Sel',
                      'Rab',
                      'Kam',
                      'Jum',
                      'Sab',
                      'Min',
                    ][b.start.weekday - 1],
                    date: '${b.start.day}',
                    month: const [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'Mei',
                      'Jun',
                      'Jul',
                      'Agu',
                      'Sep',
                      'Okt',
                      'Nov',
                      'Des',
                    ][b.start.month - 1],
                    title: b.title,
                    when:
                        '${formatTime(b.start)}–${formatTime(b.end)} · '
                        '${b.court}',
                    place: b.venue,
                    note: b.checkedIn ? 'Sudah check-in' : null,
                    onTap: () => context.push('/ticket/${b.id}'),
                  ),
                ),
            const SizedBox(height: 14),
            Text(
              'Tiket terbit otomatis saat absen room penuh. Tunjukkan QR ke '
              'petugas venue sebelum main.',
              style: T.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? C.primaryFill : C.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? C.primaryFill : C.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? C.ink : C.muted,
            ),
          ),
        ),
      ),
    );
  }
}
