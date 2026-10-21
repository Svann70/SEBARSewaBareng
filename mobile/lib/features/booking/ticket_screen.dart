import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingsProvider).firstWhere((b) => b.id == id);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: kScreenPad,
          children: [
            const RoundBackHeader(title: 'Tiket masuk'),
            const SizedBox(height: 20),
            Center(
              child: Pill(
                booking.checkedIn ? 'Sudah check-in' : 'Siap discan',
                color: booking.checkedIn ? C.green : C.amber,
                background: booking.checkedIn ? C.tealSoft : C.amberSoft,
                icon: Icons.qr_code_scanner,
              ),
            ),
            const SizedBox(height: 10),
            Text(booking.title, textAlign: TextAlign.center, style: T.h1),
            const SizedBox(height: 4),
            Text(
              '${booking.venue} · ${booking.court}',
              textAlign: TextAlign.center,
              style: T.small,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(26),
                boxShadow: C.cardShadow,
              ),
              child: Column(
                children: [
                  Opacity(
                    opacity: booking.checkedIn ? 0.25 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: C.line),
                      ),
                      child: QrImageView(
                        data: booking.token,
                        version: QrVersions.auto,
                        size: 208,
                        gapless: true,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: C.ink,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    booking.code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.6,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('Tunjukkan ke petugas venue', style: T.caption),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TicketInfo(
                    label: 'Tanggal',
                    value: formatDate(booking.start),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TicketInfo(
                    label: 'Jam',
                    value:
                        '${formatTime(booking.start)}–${formatTime(booking.end)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TicketInfo(
                    label: 'Dibayar',
                    value: rupiah(booking.amount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: C.teal),
                      SizedBox(width: 7),
                      Expanded(child: Text('Token sekali pakai', style: T.h3)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'QR hanya berlaku sekali dan kedaluwarsa 2 jam setelah '
                    'jadwal mulai. Scan ulang akan ditolak.',
                    style: T.small,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Simpan',
                          icon: Icons.download_outlined,
                          height: 44,
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tiket disimpan ke galeri.'),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SebarButton(
                          label: booking.checkedIn
                              ? 'Sudah scan'
                              : 'Simulasi scan',
                          icon: Icons.qr_code_scanner,
                          height: 44,
                          color: C.green,
                          onPressed: booking.checkedIn
                              ? null
                              : () {
                                  ref
                                      .read(bookingsProvider.notifier)
                                      .checkIn(booking.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Check-in valid. Skor +2 (92 → 94).',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketInfo extends StatelessWidget {
  const _TicketInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: C.ink,
            ),
          ),
        ],
      ),
    );
  }
}
