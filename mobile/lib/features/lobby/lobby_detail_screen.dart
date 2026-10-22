import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Detail room mengikuti AppDesign2: header gradien penuh, kartu ringkasan
/// yang menumpuk di atasnya, lalu detail, lokasi, dan bar aksi di bawah.
class LobbyDetailScreen extends ConsumerWidget {
  const LobbyDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobby = ref.watch(lobbiesProvider).firstWhere((l) => l.id == id);
    final wallet = ref.watch(walletProvider);
    final joined = lobby.joinedByMe;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            lobby: lobby,
            onShare: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  lobby.access == LobbyAccess.link
                      ? 'Kode undangan ${lobby.secret} disalin.'
                      : 'Link room disalin.',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detail', style: T.h2),
                const SizedBox(height: 7),
                Text(
                  '${lobby.sport.label} di ${lobby.court}, ${lobby.venue}. '
                  'Biaya lapangan ${rupiah(lobby.priceTotal)} dibagi '
                  '${lobby.quota} orang. Slot dikunci '
                  '${formatCountdown(lobby.untilStart)} lagi.',
                  style: T.body,
                ),
                const SizedBox(height: 20),
                const Text('Lokasi', style: T.h2),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: C.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${lobby.venue}\n${lobby.court} · ${lobby.city}',
                        style: T.small,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Membuka peta venue.')),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buka di maps',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: C.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.north_east, size: 12, color: C.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (lobby.access != LobbyAccess.open) ...[
                  _PrivateCard(lobby: lobby),
                  const SizedBox(height: 18),
                ],
                SectionHeader('Peserta ${lobby.joined}/${lobby.quota}'),
                const SizedBox(height: 10),
                for (final m in lobby.members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberRow(member: m),
                  ),
                const SizedBox(height: 10),
                _PenaltyRules(lobby: lobby),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _JoinBar(
        lobby: lobby,
        wallet: wallet,
        joined: joined,
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
    final secret = TextEditingController();
    var useWallet = enough;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: agreed,
        builder: (context, value, _) => StatefulBuilder(
          builder: (context, setSheet) => SheetWrap(
            title: 'Konfirmasi join',
            children: [
              Text(lobby.title, style: T.small),
              const SizedBox(height: 12),
              if (lobby.access == LobbyAccess.password) ...[
                LabeledField(
                  label: 'Sandi room',
                  controller: secret,
                  hint: 'Tanya host',
                  obscure: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 12),
              ],
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
              const Text('Metode pembayaran', style: T.label),
              const SizedBox(height: 8),
              _PayOption(
                selected: useWallet,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Saldo dompet',
                detail: enough
                    ? '${rupiah(wallet.available)} tersedia'
                    : 'Saldo ${rupiah(wallet.available)} — tidak cukup',
                onTap: enough ? () => setSheet(() => useWallet = true) : null,
              ),
              const SizedBox(height: 8),
              _PayOption(
                selected: !useWallet,
                icon: Icons.qr_code_2,
                title: 'QRIS / transfer bank',
                detail: 'Bayar dari luar dompet: QRIS, BCA, Mandiri',
                onTap: () => setSheet(() => useWallet = false),
              ),
              if (!useWallet) ...[
                const SizedBox(height: 10),
                SurfaceCard(
                  radius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: C.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instruksi pembayaran muncul setelah konfirmasi. Slot '
                          'aman sampai pembayaran terverifikasi (maks 15 menit).',
                          style: T.small,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const _PenaltyMini(),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => agreed.value = !value,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: value,
                        onChanged: (v) => agreed.value = v ?? false,
                      ),
                    ),
                    const SizedBox(width: 10),
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
              const SizedBox(height: 14),
              SebarButton(
                label: useWallet
                    ? 'Join · ${rupiah(lobby.pricePerPerson)}'
                    : 'Bayar sekarang · ${rupiah(lobby.pricePerPerson)}',
                onPressed: value && (enough || !useWallet)
                    ? () => Navigator.pop(context, true)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || (useWallet && !enough)) {
      secret.dispose();
      return;
    }

    final error = ref
        .read(lobbiesProvider.notifier)
        .join(lobby.id, secret: secret.text, useWallet: useWallet);
    secret.dispose();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final updated = ref
        .read(lobbiesProvider)
        .firstWhere((l) => l.id == lobby.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isFull
              ? 'Kuota penuh. Booking dibuat, tiket QR sudah terbit.'
              : useWallet
              ? '${rupiah(lobby.pricePerPerson)} dikunci. '
                    'Sisa ${updated.remaining} slot.'
              : 'Instruksi QRIS/transfer dikirim. '
                    'Sisa ${updated.remaining} slot.',
        ),
      ),
    );
    if (updated.isFull) context.go('/home');
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    final p = penaltyFor(untilStart: lobby.untilStart);
    final penaltyAmount = (lobby.pricePerPerson * p.penaltyPct / 100).round();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan join?', style: T.h2),
        content: Text(
          p.penaltyPct == 0
              ? 'Jadwal masih lebih dari 6 jam. Dana '
                    '${rupiah(lobby.pricePerPerson)} kembali penuh ke dompetmu.'
              : 'Kurang dari 6 jam ke mulai. Denda 15% '
                    '(${rupiah(penaltyAmount)}) tidak dikembalikan.',
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
    if (ok == true) {
      ref.read(lobbiesProvider.notifier).cancelMine(lobby.id);
      if (context.mounted) context.pop();
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.lobby, required this.onShare});

  final Lobby lobby;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 246,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: lobby.sport.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CourtPhoto(
                  venue: lobby.venue,
                  court: lobby.court,
                  height: 246,
                  radius: 0,
                  scrim: true,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        C.primaryDeep.withValues(alpha: 0.4),
                        C.primaryDeep.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _HeroPainter()),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _GlassButton(
                            icon: Icons.arrow_back,
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/home'),
                          ),
                          const Spacer(),
                          _GlassButton(icon: Icons.ios_share, onTap: onShare),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Pill(
                        '${formatDate(lobby.start)} · '
                        '${formatTime(lobby.start)}',
                        color: Colors.white,
                        background: Colors.black.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lobby.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 178, 20, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _SummaryCard(lobby: lobby),
              Positioned(
                top: -30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: C.surface,
                      shape: BoxShape.circle,
                      boxShadow: C.cardShadow,
                    ),
                    child: QuotaRing(
                      joined: lobby.joined,
                      quota: lobby.quota,
                      size: 58,
                      color: lobby.isFull ? C.amber : C.primary,
                      foreground: C.ink,
                      track: C.line,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width * 0.94, 34), 96, paint);
    canvas.drawCircle(Offset(size.width * 0.06, size.height), 74, paint);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.68, 0),
      Offset(size.width * 0.52, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.18),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: C.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Pill(
                lobby.sport.label,
                background: lobby.sport.gradient.first.withValues(alpha: 0.12),
                color: lobby.sport.gradient.first,
                icon: lobby.sport.icon,
              ),
              const Spacer(),
              Pill(
                lobby.access.label,
                background: C.surfaceAlt,
                color: C.muted,
                icon: lobby.access.icon,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  icon: Icons.event,
                  label: 'Tanggal',
                  value: formatDate(lobby.start),
                ),
              ),
              const _MetaDivider(),
              Expanded(
                child: _Meta(
                  icon: Icons.schedule,
                  label: 'Jam',
                  value: '${formatTime(lobby.start)}–${formatTime(lobby.end)}',
                ),
              ),
              const _MetaDivider(),
              Expanded(
                child: _Meta(
                  icon: Icons.payments_outlined,
                  label: 'Per orang',
                  value: rupiah(lobby.pricePerPerson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: lobby.quota == 0 ? 0 : lobby.joined / lobby.quota,
              minHeight: 5,
              backgroundColor: C.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(
                lobby.isFull ? C.orange : C.primary,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text('${lobby.remaining} slot tersisa', style: T.caption),
              const Spacer(),
              Text(
                '${lobby.city} · ${rupiah(lobby.priceTotal)}',
                style: T.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 17, color: C.muted),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: C.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: T.caption),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: C.line);
  }
}

class _PrivateCard extends StatelessWidget {
  const _PrivateCard({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      child: Row(
        children: [
          Icon(lobby.access.icon, size: 18, color: C.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lobby.access == LobbyAccess.link
                      ? 'Room privat · kode undangan'
                      : 'Room privat · pakai sandi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lobby.access == LobbyAccess.link
                      ? 'Kode ${lobby.secret}'
                      : 'Sandi dibagikan host',
                  style: T.small,
                ),
              ],
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
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                'Bagikan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: C.primary,
                ),
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    joined ? 'Kamu ikut' : 'Harga per orang',
                    style: T.caption,
                  ),
                  Text(
                    rupiah(lobby.pricePerPerson),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: joined
                    ? GhostButton(
                        label: 'Batalkan join',
                        icon: Icons.logout,
                        color: C.danger,
                        height: 50,
                        onPressed: onCancel,
                      )
                    : SebarButton(
                        label: lobby.isFull
                            ? 'Room penuh'
                            : enough
                            ? 'Join · ${rupiah(lobby.pricePerPerson)}'
                            : 'Top up dulu',
                        icon: lobby.isFull ? null : Icons.arrow_forward,
                        height: 50,
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: member.isMe ? C.primarySoft : C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: member.isMe ? C.primary.withValues(alpha: 0.35) : C.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: C.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.name.characters.first,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: C.primaryDeep,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: C.ink,
                    ),
                  ),
                ),
                if (member.isHost) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: C.butter,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Host',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: C.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Aturan pembatalan — dua zona waktu, denda 15% di bawah 6 jam.
class _PenaltyRules extends StatelessWidget {
  const _PenaltyRules({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    final soon = lobby.untilStart < const Duration(hours: 6);
    return SurfaceCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 15, color: C.muted),
              const SizedBox(width: 7),
              const Text('Aturan pembatalan', style: T.h3),
              const Spacer(),
              if (soon)
                const Pill('Zona denda', color: C.amber, background: C.butter),
            ],
          ),
          const SizedBox(height: 10),
          const _RuleLine(
            color: C.primary,
            title: 'Batal ≥ 6 jam',
            detail: 'Refund penuh',
          ),
          const _RuleLine(
            color: C.amber,
            title: 'Batal < 6 jam',
            detail: 'Denda 15%, refund 85%',
          ),
          const _RuleLine(
            color: C.danger,
            title: 'Tidak datang',
            detail: 'Dana hangus',
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.color,
    required this.title,
    required this.detail,
  });

  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.caption,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konsekuensi batal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: C.ink,
            ),
          ),
          SizedBox(height: 8),
          _RuleLine(color: C.primary, title: '≥ 6 jam', detail: 'Refund penuh'),
          _RuleLine(color: C.amber, title: '< 6 jam', detail: 'Denda 15%'),
          _RuleLine(color: C.danger, title: 'No-show', detail: 'Dana hangus'),
        ],
      ),
    );
  }
}

/// Pilihan metode pembayaran pada lembar konfirmasi join.
class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: selected ? C.primarySoft : C.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? C.primary : C.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: disabled ? C.faint : C.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: disabled ? C.muted : C.ink,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? C.primary : C.faint,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: muted ? C.muted : C.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: muted ? C.muted : C.ink,
            ),
          ),
        ],
      ),
    );
  }
}
