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
        padding: kScreenPad,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Dompet', style: T.h1)),
              CircleIconButton(
                icon: Icons.help_outline,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Saldo tersedia adalah saldo dikurangi dana yang '
                      'masih terkunci di room.',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Patungan aman, dana terkunci sampai check-in.',
            style: T.small,
          ),
          const SizedBox(height: 16),
          SportPanel(
            gradient: C.pinkPanel,
            radius: 30,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pill(
                  'Saldo tersedia',
                  color: Colors.white,
                  background: Colors.black.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  rupiah(wallet.available),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _WalletStat('Saldo', rupiah(wallet.balance)),
                    const SizedBox(width: 26),
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
                  height: 50,
                  onPressed: () => _topUp(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Tarik dana',
                  icon: Icons.arrow_outward,
                  height: 50,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Penarikan tersedia setelah jadwal selesai.',
                      ),
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
              message: 'Setiap top up, pembayaran, dan refund muncul di sini.',
            )
          else
            for (final e in wallet.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LedgerRow(entry: e),
              ),
          const SizedBox(height: 10),
          SurfaceCard(
            radius: 22,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: C.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: C.teal,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Setiap transaksi tercatat otomatis dan bisa diperiksa '
                    'kapan saja.',
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
        title: 'Top up saldo',
        children: [
          const Text(
            'Pilih nominal. Saldo langsung masuk dan bisa dipakai join room.',
            style: T.small,
          ),
          const SizedBox(height: 16),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: C.line),
                      ),
                      child: Text(
                        rupiah(o),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
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
      'TOPUP' => (Icons.add_circle_outline, C.green, C.tealSoft),
      'CAPTURE' => (Icons.shopping_bag_outlined, C.purple, C.purpleSoft),
      'HOLD' => (Icons.lock_outline, C.amber, C.amberSoft),
      'RELEASE' => (Icons.lock_open_outlined, C.muted, C.surfaceAlt),
      'PENALTY' => (Icons.gavel_outlined, C.coral, C.pinkSoft),
      _ => (Icons.swap_horiz, C.muted, C.surfaceAlt),
    };
    final amount = switch (entry.type) {
      'HOLD' => 'Dikunci',
      'RELEASE' => 'Dilepas',
      _ => '${entry.amount < 0 ? '-' : '+'}${rupiah(entry.amount.abs())}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 18, color: color),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${entry.typeLabel} · ${formatDate(entry.at)} '
                  '${formatTime(entry.at)}',
                  style: T.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: entry.type == 'HOLD' || entry.type == 'RELEASE'
                  ? C.muted
                  : entry.amount < 0
                  ? C.ink
                  : C.green,
            ),
          ),
        ],
      ),
    );
  }
}
