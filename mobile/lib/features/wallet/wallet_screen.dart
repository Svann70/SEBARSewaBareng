import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final held = wallet.entries.where((e) => e.type == 'HOLD').toList();
    final ledger = wallet.entries.where((e) => e.type != 'HOLD').toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: C.primary,
        backgroundColor: C.surface,
        onRefresh: () async {
          await ref.read(walletProvider.notifier).refresh();
        },
        child: ListView(
          padding: kScreenPad,
          children: [
            const Text('Dompet', style: T.h1),
            const SizedBox(height: 2),
            const Text(
              'Dana aman, terkunci sampai room penuh.',
              style: T.small,
            ),
            const SizedBox(height: 14),
            SportPanel(
              gradient: C.primaryPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo tersedia',
                    style: T.caption.copyWith(
                      color: C.ink.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedRupiah(
                    wallet.available,
                    style: T.numberLg.copyWith(color: C.ink),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Total',
                          value: rupiah(wallet.balance),
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'Dikunci',
                          value: rupiah(wallet.held),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SebarButton(
                    label: 'Top up',
                    height: 46,
                    onPressed: () => _topUp(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhostButton(
                    label: 'Tarik dana',
                    height: 46,
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
            const SizedBox(height: 20),
            if (held.isNotEmpty) ...[
              const SectionHeader('Sedang dikunci'),
              const SizedBox(height: 4),
              for (final e in held) _HeldRow(entry: e),
              const SizedBox(height: 20),
            ],
            const SectionHeader('Riwayat'),
            const SizedBox(height: 4),
            if (ledger.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada mutasi',
                message:
                    'Setiap top up, pembayaran, dan refund muncul di sini.',
              )
            else ...[
              _DayLabel(_dayGroup(ledger.first.at)),
              for (var i = 0; i < ledger.length; i++) ...[
                if (i > 0 &&
                    _dayGroup(ledger[i].at) != _dayGroup(ledger[i - 1].at))
                  _DayLabel(_dayGroup(ledger[i].at)),
                _LedgerRow(entry: ledger[i]),
              ],
            ],
            const SizedBox(height: 12),
            const Text(
              'Setiap transaksi tercatat otomatis dan bisa diperiksa kapan saja.',
              style: T.caption,
            ),
          ],
        ),
      ),
    );
  }

  static String _dayGroup(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'HARI INI';
    if (diff < 7) return 'MINGGU INI';
    return formatDate(at).toUpperCase();
  }

  Future<void> _topUp(BuildContext context, WidgetRef ref) async {
    const options = [50000, 100000, 200000, 500000];
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetWrap(
        title: 'Top up saldo',
        children: [
          const Text('Nominal', style: T.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                Material(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context, o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.line),
                      ),
                      child: Text(
                        rupiah(o),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Metode', style: T.label),
          const SizedBox(height: 8),
          const _Method(
            label: 'QRIS',
            detail: 'Scan dari e-wallet atau m-banking',
          ),
          const _Method(
            label: 'Transfer bank',
            detail: 'Virtual account · cek otomatis',
          ),
          const SizedBox(height: 8),
          Text(
            'Top up memakai saldo uji (sandbox) selama gateway pembayaran '
            'belum tersambung.',
            style: T.caption,
          ),
        ],
      ),
    );
    if (amount == null) return;
    final error = await ref.read(walletProvider.notifier).topUpRemote(amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${rupiah(amount)} ditambahkan ke saldo.'),
      ),
    );
  }
}

class _Method extends StatelessWidget {
  const _Method({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
                Text(detail, style: T.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: C.faint),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: T.caption.copyWith(color: C.ink.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: C.ink,
          ),
        ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(label, style: T.label),
    );
  }
}

class _HeldRow extends StatelessWidget {
  const _HeldRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: C.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: C.ink,
                  ),
                ),
                Text('Dipotong saat room penuh', style: T.caption),
              ],
            ),
          ),
          Text(
            rupiah(entry.amount.abs()),
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final amount =
        '${entry.amount < 0 ? '-' : '+'}'
        '${rupiah(entry.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: C.ink,
                  ),
                ),
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
              fontWeight: FontWeight.w600,
              color: entry.amount < 0 ? C.ink : C.primary,
            ),
          ),
        ],
      ),
    );
  }
}
