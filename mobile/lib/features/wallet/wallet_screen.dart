import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    onPressed: () => _withdraw(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (held.isNotEmpty) ...[
              const SectionHeader('Sedang dikunci'),
              const SizedBox(height: 4),
              for (final e in held)
                _HeldRow(entry: e, onTap: () => _showEntryDetail(context, e)),
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
                _LedgerRow(
                  entry: ledger[i],
                  onTap: () => _showEntryDetail(context, ledger[i]),
                ),
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

  Future<void> _showEntryDetail(BuildContext context, WalletEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetWrap(
        title: 'Detail pembayaran',
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(entry.label, style: T.h2)),
              const SizedBox(width: 12),
              Text(
                _amountLabel(entry),
                style: TextStyle(
                  color: entry.amount < 0 ? C.ink : C.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Status', value: 'Berhasil'),
          _DetailRow(label: 'Jenis', value: entry.typeLabel),
          _DetailRow(
            label: 'Waktu',
            value: '${formatLongDate(entry.at)} · ${formatTime(entry.at)}',
          ),
          if (entry.balanceAfter != null)
            _DetailRow(
              label: 'Saldo setelah transaksi',
              value: rupiah(entry.balanceAfter!),
            ),
          if (entry.heldAfter != null)
            _DetailRow(
              label: 'Saldo terkunci setelah transaksi',
              value: rupiah(entry.heldAfter!),
            ),
          if (entry.refType != null)
            _DetailRow(label: 'Referensi', value: entry.refType!),
          if (entry.refId != null)
            _DetailRow(label: 'ID transaksi', value: entry.refId!),
          const SizedBox(height: 8),
          const Text(
            'Detail ini berasal dari catatan transaksi server dan tidak dapat '
            'diubah.',
            style: T.caption,
          ),
        ],
      ),
    );
  }

  static String _amountLabel(WalletEntry entry) {
    if (entry.amount == 0) return 'Tidak berubah';
    return '${entry.amount < 0 ? '-' : '+'}${rupiah(entry.amount.abs())}';
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

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    const fee = 2500;
    final available = ref.read(walletProvider).available;

    final draft = await showModalBottomSheet<(int, String, String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _WithdrawSheet(
        available: available,
        fee: fee,
      ),
    );
    if (draft == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi penarikan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Nominal diterima', value: rupiah(draft.$1)),
            _DetailRow(label: 'Fee penarikan', value: rupiah(fee)),
            _DetailRow(label: 'Total dipotong', value: rupiah(draft.$1 + fee)),
            _DetailRow(label: 'Rekening', value: '${draft.$2} · ${draft.$3}'),
            _DetailRow(label: 'Nama', value: draft.$4),
            const SizedBox(height: 8),
            const Text(
              'Dana akan berstatus menunggu proses dan saldo langsung dikurangi.',
              style: T.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tarik dana'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(walletProvider.notifier)
        .withdrawRemote(
          amount: draft.$1,
          bankCode: draft.$2,
          accountNumber: draft.$3,
          accountName: draft.$4,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              '${rupiah(draft.$1)} berhasil diajukan. Fee ${rupiah(fee)} '
                  'sudah dipotong.',
        ),
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
  const _HeldRow({required this.entry, required this.onTap});

  final WalletEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
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
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: C.faint),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.onTap});

  final WalletEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount =
        '${entry.amount < 0 ? '-' : '+'}'
        '${rupiah(entry.amount.abs())}';
    return GestureDetector(
      onTap: onTap,
      child: Padding(
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
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: C.faint),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label, style: T.caption)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: C.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.available, required this.fee});

  final int available;
  final int fee;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _accountController;
  late final TextEditingController _nameController;
  String _bankCode = 'BCA';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _accountController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text);
    final account = _accountController.text.trim();
    final name = _nameController.text.trim();

    if (amount == null || amount < 10000) {
      setState(() => _errorMessage = 'Minimal penarikan Rp10.000.');
      return;
    }
    if (amount + widget.fee > widget.available) {
      setState(
        () => _errorMessage =
            'Saldo tidak cukup untuk nominal dan fee penarikan.',
      );
      return;
    }
    if (account.length < 6) {
      setState(() => _errorMessage = 'Nomor rekening minimal 6 digit.');
      return;
    }
    if (name.length < 2) {
      setState(
        () => _errorMessage =
            'Nama pemilik rekening wajib diisi (min. 2 karakter).',
      );
      return;
    }

    Navigator.pop(context, (
      amount,
      _bankCode,
      account,
      name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SheetWrap(
        title: 'Tarik dana',
        children: [
          Text('Saldo tersedia ${rupiah(widget.available)}', style: T.caption),
          const SizedBox(height: 4),
          const Text(
            'Minimal penarikan Rp10.000. Biaya penarikan Rp2.500 per transaksi.',
            style: T.caption,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nominal yang diterima',
              prefixText: 'Rp ',
            ),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _bankCode,
            decoration: const InputDecoration(labelText: 'Bank tujuan'),
            items: const [
              DropdownMenuItem(value: 'BCA', child: Text('BCA')),
              DropdownMenuItem(value: 'BNI', child: Text('BNI')),
              DropdownMenuItem(value: 'BRI', child: Text('BRI')),
              DropdownMenuItem(value: 'MANDIRI', child: Text('Bank Mandiri')),
              DropdownMenuItem(value: 'CIMB', child: Text('CIMB Niaga')),
              DropdownMenuItem(
                value: 'BSI',
                child: Text('Bank Syariah Indonesia'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _bankCode = value ?? _bankCode),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Nomor rekening'),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama pemilik rekening',
              hintText: 'Sesuai data bank',
            ),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: C.dangerSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: C.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SebarButton(
              label: 'Lanjutkan',
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
