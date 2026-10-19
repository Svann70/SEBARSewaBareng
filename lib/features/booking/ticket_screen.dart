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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const RoundBackHeader(title: 'Tiket masuk'),
            const SizedBox(height: 20),
            Center(
              child: Pill(
                booking.checkedIn ? 'Sudah check-in' : 'Siap discan',
                color: booking.checkedIn ? C.green : C.orange,
                background: (booking.checkedIn ? C.green : C.orange).withValues(alpha: 0.18),
                icon: Icons.qr_code_scanner,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              booking.title,
              textAlign: TextAlign.center,
              style: T.h1,
            ),
            const SizedBox(height: 3),
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
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: C.line),
              ),
              child: Column(
                children: [
                  Opacity(
                    opacity: booking.checkedIn ? 0.25 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: booking.token,
                        version: QrVersions.auto,
                        size: 208,
                        gapless: true,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: C.bg,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: C.bg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    booking.code,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.6,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Tunjukkan ke petugas venue',
                    style: TextStyle(fontSize: 11, color: C.muted),
                  ),
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
                    value: '${formatTime(booking.start)}–${formatTime(booking.end)}',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: C.green),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text('Token sekali pakai', style: T.h3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'QR ditandatangani HMAC dan kedaluwarsa 2 jam setelah mulai. '
                    'Scan kedua ditolak dengan kode ALREADY_CHECKED_IN.',
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
                          label: booking.checkedIn ? 'Sudah scan' : 'Simulasi scan',
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: C.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
