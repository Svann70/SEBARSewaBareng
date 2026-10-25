import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
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
            const RoundBackHeader(title: 'Tiket'),
            const SizedBox(height: 14),
            Pill(
              booking.sport.label.toUpperCase(),
              color: C.primary,
              background: C.primarySoft,
            ),
            const SizedBox(height: 8),
            Text(booking.title, style: T.h1),
            const SizedBox(height: 2),
            Text('${booking.venue} · ${booking.court}', style: T.small),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: Column(
                children: [
                  Opacity(
                    opacity: booking.checkedIn ? 0.25 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.line),
                      ),
                      child: QrImageView(
                        data: booking.token,
                        version: QrVersions.auto,
                        size: 200,
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tunjukkan ke petugas venue. Satu QR untuk kamu saja.',
                    textAlign: TextAlign.center,
                    style: T.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Info(
                    label: 'Tanggal',
                    value: formatDate(booking.start),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Info(
                    label: 'Jam',
                    value:
                        '${formatTime(booking.start)}–${formatTime(booking.end)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Info(
                    label: 'Status',
                    value: booking.checkedIn ? 'Sudah masuk' : 'Siap dipakai',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: C.primary),
                      SizedBox(width: 6),
                      Expanded(child: Text('Token sekali pakai', style: T.h3)),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                          height: 44,
                          onPressed: booking.checkedIn
                              ? null
                              : () {
                                  ref
                                      .read(bookingsProvider.notifier)
                                      .checkIn(booking.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Check-in valid. Selamat bermain!',
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
            const SizedBox(height: 8),
            GhostButton(
              label: 'Arah ke venue',
              icon: Icons.north_east,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Membuka peta venue.')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
          ),
        ],
      ),
    );
  }
}
