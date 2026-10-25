import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Detail room gaya "absen patungan": foto, ringkasan, daftar absen
/// bernomor, aturan batal, lalu bar join.
class LobbyDetailScreen extends ConsumerStatefulWidget {
  const LobbyDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends ConsumerState<LobbyDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(lobbiesProvider.notifier).loadDetail(widget.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref
        .watch(lobbiesProvider)
        .where((l) => l.id == widget.id)
        .toList();
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lobby = matches.first;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PhotoHeader(lobby: lobby),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lobby.sport.label.toUpperCase()} · '
                  '${lobby.access.label.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: C.faint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(lobby.title, style: T.h1),
                const SizedBox(height: 2),
                Text(
                  'Dibuat ${lobby.isHost ? 'olehmu' : 'host'} · ${lobby.venue}',
                  style: T.small,
                ),
                const SizedBox(height: 16),
                _Summary(lobby: lobby),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: Text('Absen', style: T.h2)),
                    Text(
                      '${lobby.joined}/${lobby.quota}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lobby.isFull
                          ? '· penuh'
                          : '· ${lobby.remaining} slot lagi',
                      style: T.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < lobby.members.length; i++)
                  AttendRow(
                    number: i + 1,
                    name: lobby.members[i].name,
                    tag: lobby.members[i].isHost
                        ? 'host'
                        : lobby.members[i].isMe
                        ? 'kamu'
                        : null,
                    trailing: null,
                  ),
                for (var i = lobby.members.length; i < lobby.quota; i++)
                  AttendRow(
                    number: i + 1,
                    name: '',
                    trailing: rupiah(lobby.pricePerPerson),
                    pending: true,
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Centang = dana sudah dikunci. Saat baris terakhir terisi, '
                  'booking dan tiket QR terbit otomatis.',
                  style: T.caption,
                ),
                const SizedBox(height: 20),
                const Text('Lokasi', style: T.h2),
                const SizedBox(height: 6),
                Text(lobby.venue, style: T.h3),
                Text('${lobby.court} · ${lobby.city}', style: T.small),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Membuka peta venue.')),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Maps',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.primary,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.north_east, size: 13, color: C.primary),
                    ],
                  ),
                ),
                if (lobby.access != LobbyAccess.open) ...[
                  const SizedBox(height: 16),
                  _PrivateCard(lobby: lobby),
                ],
                const SizedBox(height: 20),
                const Text('Kalau batal', style: T.h2),
                const SizedBox(height: 6),
                _RuleRow(
                  title: 'Lebih dari 6 jam sebelum main',
                  detail: 'Refund penuh',
                  color: C.primary,
                ),
                _RuleRow(
                  title: 'Kurang dari 6 jam',
                  detail:
                      'Denda 15% · ${rupiah((lobby.pricePerPerson * 15) ~/ 100)}',
                  color: C.amber,
                ),
                _RuleRow(
                  title: 'Tidak datang',
                  detail: 'Hangus ${rupiah(lobby.pricePerPerson)}',
                  color: C.danger,
                ),
                const SizedBox(height: 8),
                Text(
                  'Slot dikunci ${formatCountdown(lobby.untilStart)} lagi.',
                  style: T.caption,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _JoinBar(
        lobby: lobby,
        wallet: wallet,
        joined: lobby.joinedByMe,
        onJoin: () => _openJoinSheet(context, ref, lobby),
        onCancel: () => _confirmCancel(context, ref, lobby),
      ),
    );
  }

  Future<void> _openJoinSheet(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    final wallet = ref.read(walletProvider);
    final enough = wallet.available >= lobby.pricePerPerson;
    final agreed = ValueNotifier<bool>(false);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: agreed,
        builder: (context, value, _) => SheetWrap(
          title: 'Join · ${rupiah(lobby.pricePerPerson)}',
          children: [
            Text(lobby.title, style: T.small),
            const SizedBox(height: 12),
            _BillRow('Harga lapangan', rupiah(lobby.priceTotal)),
            _BillRow(
              'Dibagi ${lobby.quota} orang',
              rupiah(lobby.pricePerPerson),
            ),
            if (roundingSurplus(lobby.priceTotal, lobby.quota) > 0)
              _BillRow(
                'Surplus pembulatan ke venue',
                rupiah(roundingSurplus(lobby.priceTotal, lobby.quota)),
                muted: true,
              ),
            const Divider(height: 22),
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: C.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enough
                        ? 'Saldo ${rupiah(wallet.available)} tersedia'
                        : 'Saldo ${rupiah(wallet.available)} — tidak cukup',
                    style: T.small,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PenaltyMini(),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => agreed.value = !value,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: value,
                      onChanged: (v) => agreed.value = v ?? false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Saya paham dana dikunci saat join dan aturan '
                      'pembatalan di atas berlaku.',
                      style: T.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SebarButton(
              label: enough
                  ? 'Join · ${rupiah(lobby.pricePerPerson)}'
                  : 'Saldo kurang',
              onPressed: value && enough
                  ? () => Navigator.pop(context, true)
                  : null,
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final error = await ref.read(lobbiesProvider.notifier).joinRemote(lobby.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final updatedList = ref
        .read(lobbiesProvider)
        .where((l) => l.id == lobby.id)
        .toList();
    final updated = updatedList.isEmpty ? null : updatedList.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated?.isFull == true
              ? 'Kuota penuh. Booking dibuat, tiket QR sudah terbit.'
              : '${rupiah(lobby.pricePerPerson)} dikunci. '
                    'Sisa ${updated?.remaining ?? 0} slot.',
        ),
      ),
    );
    if (updated?.isFull == true) context.go('/home');
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan join?', style: T.h2),
        content: Text(
          'Dana ${rupiah(lobby.pricePerPerson)} kembali penuh ke dompetmu '
          'selama masih sebelum batas join (6 jam sebelum mulai).',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, batalkan',
              style: TextStyle(color: C.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(lobbiesProvider.notifier)
        .leaveRemote(lobby.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pop();
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: CourtPhoto(
              url: lobby.photoUrl,
              height: 220,
              radius: 0,
              scrim: true,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back,
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const Spacer(),
                  _GlassButton(
                    icon: Icons.ios_share,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lobby.access == LobbyAccess.link
                              ? 'Kode undangan ${lobby.secret} disalin.'
                              : 'Link room disalin.',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: C.ink.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Foto venue',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.ink.withValues(alpha: 0.45),
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Meta(label: 'Tanggal', value: formatDate(lobby.start)),
              ),
              Expanded(
                child: _Meta(
                  label: 'Jam',
                  value: '${formatTime(lobby.start)}–${formatTime(lobby.end)}',
                ),
              ),
              Expanded(
                child: _Meta(label: 'Lapangan', value: lobby.court),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rupiah(lobby.pricePerPerson), style: T.numberMd),
              const SizedBox(width: 5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'per orang · ${rupiah(lobby.priceTotal)} dibagi '
                    '${lobby.quota}',
                    style: T.caption,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Batas kumpul', style: T.caption),
              const SizedBox(width: 8),
              Text(
                '${formatDate(lobby.deadline)}, '
                '${formatTime(lobby.deadline)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: C.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _PrivateCard extends StatelessWidget {
  const _PrivateCard({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Icon(lobby.access.icon, size: 16, color: C.faint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              lobby.access == LobbyAccess.link
                  ? 'Room privat · kode ${lobby.secret}'
                  : 'Room privat · pakai sandi',
              style: T.small,
            ),
          ),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  lobby.access == LobbyAccess.link
                      ? 'Kode ${lobby.secret} disalin.'
                      : 'Sandi room disalin ke papan klip.',
                ),
              ),
            ),
            child: const Text(
              'Bagikan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinBar extends StatelessWidget {
  const _JoinBar({
    required this.lobby,
    required this.wallet,
    required this.joined,
    required this.onJoin,
    required this.onCancel,
  });

  final Lobby lobby;
  final Wallet wallet;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final enough = wallet.available >= lobby.pricePerPerson;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    joined ? 'Kamu ikut' : 'Saldo tersedia',
                    style: T.caption,
                  ),
                  Text(
                    rupiah(joined ? lobby.pricePerPerson : wallet.available),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: joined
                    ? GhostButton(
                        label: 'Batalkan join',
                        color: C.danger,
                        height: 46,
                        onPressed: onCancel,
                      )
                    : SebarButton(
                        label: lobby.isFull
                            ? 'Room penuh'
                            : enough
                            ? 'Join · ${rupiah(lobby.pricePerPerson)}'
                            : 'Top up dulu',
                        height: 46,
                        onPressed: lobby.isFull ? null : onJoin,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: T.small)),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyMini extends StatelessWidget {
  const _PenaltyMini();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konsekuensi batal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
          ),
          SizedBox(height: 6),
          Text('≥ 6 jam · refund penuh', style: T.caption),
          Text('< 6 jam · tidak bisa keluar', style: T.caption),
          Text('No-show · dana hangus', style: T.caption),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.value, {this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: muted ? C.muted : C.ink,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted ? C.muted : C.ink,
            ),
          ),
        ],
      ),
    );
  }
}
