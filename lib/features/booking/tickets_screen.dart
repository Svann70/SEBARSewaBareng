import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Tiket saya',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: C.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Satu QR per peserta, hanya bisa discan sekali.',
            style: T.small,
          ),
          const SizedBox(height: 16),
          if (bookings.isEmpty)
            EmptyState(
              icon: Icons.qr_code_2,
              title: 'Belum ada tiket',
              message: 'Tiket terbit otomatis saat kuota lobby terpenuhi.',
              action: GhostButton(
                label: 'Cari lobby',
                icon: Icons.search,
                onPressed: () {},
              ),
            )
          else
            for (final b in bookings)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TicketCard(booking: b),
              ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/ticket/${booking.id}'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    booking.sport.icon,
                    size: 21,
                    color: C.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.h3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.venue} · ${booking.court}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Pill(
                  booking.checkedIn ? 'Checked in' : 'Confirmed',
                  color: booking.checkedIn ? C.green : C.orange,
                  background: (booking.checkedIn ? C.green : C.orange).withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
          const _TicketDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: _Meta(
                          icon: Icons.event_outlined,
                          text: formatDate(booking.start),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _Meta(
                          icon: Icons.schedule,
                          text:
                              '${formatTime(booking.start)}–${formatTime(booking.end)}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  booking.code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: C.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: C.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketDivider extends StatelessWidget {
  const _TicketDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          const _Notch(),
          Expanded(
            child: CustomPaint(
              painter: _DashPainter(),
              child: const SizedBox(height: 18),
            ),
          ),
          const _Notch(),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
