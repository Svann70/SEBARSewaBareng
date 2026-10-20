import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dompet',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: C.ink,
                  ),
                ),
              ),
              CircleIconButton(
                icon: Icons.help_outline,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Saldo tersedia = saldo − dana terkunci (hold).',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SportPanel(
            gradient: [Color(0xFFFF7A93), C.pinkDeep],
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Pill('Saldo tersedia', background: Colors.white24),
                const SizedBox(height: 10),
                Text(
                  rupiah(wallet.available),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    height: 1,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _WalletStat('Saldo', rupiah(wallet.balance)),
                    const SizedBox(width: 22),
                    _WalletStat('Terkunci', rupiah(wallet.held)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SebarButton(
                  label: 'Top up',
                  icon: Icons.add_card,
                  height: 48,
                  onPressed: () => _topUp(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Tarik dana',
                  icon: Icons.arrow_outward,
                  height: 48,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Penarikan hanya tersedia setelah check-in.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader('Riwayat mutasi'),
          const SizedBox(height: 10),
          if (wallet.entries.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada mutasi',
              message: 'Setiap hold, capture, dan refund akan muncul di sini.',
            )
          else
            for (final e in wallet.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LedgerRow(entry: e),
              ),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 17,
                  color: C.green,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Semua mutasi punya baris ledger. sum(ledger) = saldo, '
                    'bisa diaudit kapan saja.',
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

  Future<void> _topUp(BuildContext context, WidgetRef ref) async {
    const options = [50000, 100000, 200000, 500000];
    final amount = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SheetWrap(
        title: 'Top up sandbox',
        children: [
          const Text(
            'Nominal masuk langsung ke saldo dan tercatat sebagai entri TOPUP.',
            style: T.small,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                Material(
                  color: C.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.pop(context, o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      child: Text(
                        rupiah(o),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (amount == null) return;
    ref.read(walletProvider.notifier).topUp(amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rupiah(amount)} ditambahkan ke saldo.')),
      );
    }
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: C.ink,
          ),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (entry.type) {
      'TOPUP' => (Icons.add_circle_outline, C.green, C.mint),
      'CAPTURE' => (Icons.shopping_bag_outlined, C.greenDeep, C.surfaceAlt),
      'HOLD' => (Icons.lock_outline, C.amber, C.butter),
      'RELEASE' => (Icons.lock_open_outlined, C.muted, C.surfaceAlt),
      'PENALTY' => (Icons.gavel_outlined, C.coral, C.pink.withValues(alpha: 0.16)),
      _ => (Icons.swap_horiz, C.muted, C.surfaceAlt),
    };
    final amount = switch (entry.type) {
      'HOLD' => 'dikunci',
      'RELEASE' => 'dilepas',
      _ => '${entry.amount < 0 ? '-' : '+'}${rupiah(entry.amount.abs())}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${entry.type} · ${formatDate(entry.at)} '
                  '${formatTime(entry.at)}',
                  style: const TextStyle(fontSize: 10.5, color: C.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: entry.amount < 0 ? C.ink : C.greenDeep,
            ),
          ),
        ],
      ),
    );
  }
}
