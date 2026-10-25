import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Detail room gaya "absen patungan": foto, ringkasan, kursiku, daftar absen
/// bernomor, aturan patungan v2, lalu bar join/keluar.
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
                if (lobby.mine != null) ...[
                  _MySeatCard(lobby: lobby, seat: lobby.mine!),
                  const SizedBox(height: 20),
                ],
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
                          : '· ${lobby.remaining} kursi lagi',
                      style: T.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < lobby.members.length; i++)
                  _MemberRow(
                    number: i + 1,
                    member: lobby.members[i],
                    onKick: _canKick(lobby, lobby.members[i])
                        ? () => _confirmKick(
                            context,
                            ref,
                            lobby,
                            lobby.members[i],
                          )
                        : null,
                  ),
                for (var i = lobby.members.length; i < lobby.quota; i++)
                  AttendRow(
                    number: i + 1,
                    name: '',
                    trailing: rupiah(lobby.pricePerPerson),
                    pending: true,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Biaya dibagi rata ke semua kursi. Tiap ada yang join, porsi '
                  'turun; selisihnya kembali saat join ditutup '
                  '${formatTime(lobby.deadline)}, lalu booking dan tiket QR terbit.',
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
                const Text('Kalau keluar', style: T.h2),
                const SizedBox(height: 6),
                const _RuleRow(
                  title: '0–2 jam setelah join',
                  detail: 'Refund penuh',
                  color: C.primary,
                ),
                const _RuleRow(
                  title: 'Setelah itu, ada pengganti',
                  detail: 'Refund − Rp10.000',
                  color: C.amber,
                ),
                const _RuleRow(
                  title: 'Tidak ada pengganti / sudah ditutup',
                  detail: 'Hangus',
                  color: C.danger,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join ditutup ${formatCountdown(lobby.deadline.difference(DateTime.now()))} lagi.',
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
        onLeave: () => _confirmLeave(context, ref, lobby),
        onDisband: () => _confirmDisband(context, ref, lobby),
        onLock: () => _confirmLock(context, ref, lobby),
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
              lobby.vacant > 0
                  ? 'Mengisi kursi kosong'
                  : 'Dibagi ${(lobby.seats ?? lobby.joined) + 1} kursi',
              rupiah(lobby.pricePerPerson),
            ),
            const _BillRow(
              'Porsi turun tiap ada yang join; selisihnya kembali saat join ditutup.',
              '',
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
                      'keluar di atas berlaku.',
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
          '${rupiah(lobby.pricePerPerson)} dikunci. Masa bebas keluar 2 jam. '
          'Sisa ${updated?.remaining ?? 0} kursi.',
        ),
      ),
    );
  }

  bool _canKick(Lobby lobby, Member m) =>
      lobby.isHost &&
      lobby.status == LobbyStatus.open &&
      DateTime.now().isBefore(lobby.deadline) &&
      m.isActive &&
      !m.isHost &&
      m.userId != null;

  Future<void> _run(
    BuildContext context,
    Future<(String?, String?)> action, {
    bool popOnSuccess = false,
  }) async {
    final (message, error) = await action;
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? message!)));
    if (error == null && popOnSuccess) {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String body,
    required String confirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: T.h2),
        content: Text(body, style: T.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm, style: const TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmKick(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
    Member m,
  ) async {
    if (!await _ask(
      context,
      title: 'Keluarkan ${m.name}?',
      body:
          'Dananya kembali penuh dan porsi anggota lain naik. Anggota yang '
          'porsinya naik di atas porsi saat join boleh keluar tanpa denda '
          'selama 30 menit.',
      confirm: 'Keluarkan',
    )) {
      return;
    }
    if (!context.mounted) return;
    await _run(
      context,
      ref.read(lobbiesProvider.notifier).kickRemote(lobby.id, m.userId!),
    );
  }

  Future<void> _confirmLock(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    if (!await _ask(
      context,
      title: 'Kunci room sekarang?',
      body:
          'Join langsung ditutup: dana semua anggota dipotong, tiket QR '
          'terbit, dan masa bebas anggota berakhir. Kamu membayar sisa biaya '
          'lapangan; sisa jaminanmu kembali.',
      confirm: 'Kunci',
    )) {
      return;
    }
    if (!context.mounted) return;
    await _run(
      context,
      ref.read(lobbiesProvider.notifier).lockRemote(lobby.id),
    );
  }

  Future<void> _confirmDisband(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    if (!await _ask(
      context,
      title: 'Bubarkan room?',
      body:
          'Semua anggota dapat refund penuh. Gratis kalau room baru dibuat '
          '(< 2 jam) atau belum ada anggota. Selain itu kamu kena denda '
          'sebesar porsimu (${rupiah(lobby.hostShare ?? lobby.share)}): separuh '
          'ke anggota (termasuk yang kamu keluarkan), separuh ke venue.',
      confirm: 'Bubarkan',
    )) {
      return;
    }
    if (!context.mounted) return;
    await _run(
      context,
      ref.read(lobbiesProvider.notifier).disbandRemote(lobby.id),
      popOnSuccess: true,
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
  ) async {
    final seat = lobby.mine;
    final hold = rupiah(seat?.holdAmount ?? lobby.share);
    final body = switch (seat?.phase) {
      'FREE' => 'Kamu masih di masa bebas: $hold kembali penuh.',
      'PROTECTED' =>
        'Porsimu naik, jadi kamu boleh keluar tanpa denda: $hold kembali penuh.',
      'HOST' =>
        'Hari H: kamu keluar tanpa refund dan hak host pindah ke anggota '
            'yang paling lama join. Room tetap berjalan.',
      'FINAL' =>
        'Join sudah ditutup. Kamu keluar tanpa refund; porsi anggota lain '
            'tidak berubah.',
      _ =>
        'Kamu sudah terkunci. Kursimu jadi kursi kosong: kalau ada pengganti, '
            'dana kembali dikurangi Rp10.000; kalau tidak ada sampai join '
            'ditutup, dana hangus.',
    };
    if (!await _ask(
      context,
      title: 'Keluar dari room?',
      body: body,
      confirm: 'Ya, keluar',
    )) {
      return;
    }
    if (!context.mounted) return;
    await _run(
      context,
      ref.read(lobbiesProvider.notifier).leaveRemote(lobby.id),
    );
  }
}

/// Fase kursiku: apa yang terjadi kalau aku keluar sekarang.
class _MySeatCard extends StatelessWidget {
  const _MySeatCard({required this.lobby, required this.seat});

  final Lobby lobby;
  final MySeat seat;

  @override
  Widget build(BuildContext context) {
    String at(DateTime? d) => d == null ? '-' : formatTime(wib(d));
    final (title, body, color) = switch (seat.phase) {
      'FREE' => (
        'Masa bebas sampai ${at(seat.freeUntil)}',
        'Keluar sekarang = refund penuh.',
        C.primary,
      ),
      'PROTECTED' => (
        'Porsimu naik ke ${rupiah(lobby.share)}',
        'Di atas ${rupiah(seat.shareAtJoin)} saat kamu join. Boleh keluar '
            'tanpa denda sampai ${at(seat.protectUntil)}; kalau tidak, '
            'dianggap lanjut.',
        C.amber,
      ),
      'HOST' => (
        'Kamu host · jaminan ${rupiah(lobby.priceTotal)}',
        'Dana 100% ditahan sampai join ditutup, lalu sisanya kembali. '
            'Bubarkan paling lambat H-1.',
        C.primary,
      ),
      'LOCKED' => (
        'Terkunci · porsimu ${rupiah(lobby.share)}',
        'Keluar = cari pengganti (denda Rp10.000) atau hangus.',
        C.amber,
      ),
      'VACANT' => (
        'Kursimu menunggu pengganti',
        'Kalau terisi, ${rupiah(seat.holdAmount)} kembali dikurangi Rp10.000.',
        C.amber,
      ),
      'REPLACED' => (
        'Kursimu sudah diganti',
        'Denda ${rupiah(seat.fineAmount)} dibagikan ke anggota setelah room selesai.',
        C.muted,
      ),
      'ABSENT' => (
        'Kamu tidak ikut main',
        'Dana tidak dikembalikan; kursimu tetap terbayar.',
        C.muted,
      ),
      _ => (
        'Join ditutup · porsi final',
        'Dana sudah dipotong ${rupiah(seat.holdAmount)}.',
        C.primary,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.h3),
          const SizedBox(height: 4),
          Text(body, style: T.small),
        ],
      ),
    );
  }
}

/// Baris absen: nama, tag, dan tombol keluarkan untuk host.
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.number, required this.member, this.onKick});

  final int number;
  final Member member;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final tag = switch (member.status) {
      'VACANT' => 'kursi kosong',
      'ABSENT' => 'tidak main',
      _ =>
        member.isHost
            ? 'host'
            : member.isMe
            ? 'kamu'
            : null,
    };
    final row = AttendRow(
      number: number,
      name: member.status == 'VACANT' ? 'Menunggu pengganti' : member.name,
      tag: tag,
      pending: member.status == 'VACANT',
    );
    if (onKick == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        IconButton(
          tooltip: 'Keluarkan ${member.name}',
          icon: const Icon(Icons.person_remove_outlined, size: 19),
          color: C.danger,
          onPressed: onKick,
        ),
      ],
    );
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
              Text(rupiah(lobby.share), style: T.numberMd),
              const SizedBox(width: 5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'per kursi · ${rupiah(lobby.priceTotal)} dibagi '
                    '${lobby.seats ?? lobby.joined}',
                    style: T.caption,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Join ditutup', style: T.caption),
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
    required this.onLeave,
    required this.onDisband,
    required this.onLock,
  });

  final Lobby lobby;
  final Wallet wallet;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onDisband;
  final VoidCallback onLock;

  /// Hari H (tanggal WIB main) sudah tiba: host tidak bisa membubarkan room.
  bool get _matchDay {
    final now = wib(DateTime.now());
    final start = wib(lobby.start);
    return !DateTime(
      now.year,
      now.month,
      now.day,
    ).isBefore(DateTime(start.year, start.month, start.day));
  }

  @override
  Widget build(BuildContext context) {
    final enough = wallet.available >= lobby.pricePerPerson;
    final open = lobby.status == LobbyStatus.open;
    // Sudah keluar tapi kursinya masih tercatat: tidak bisa join lagi di sini.
    final leftSeat = switch (lobby.mine?.status) {
      'VACANT' => 'Kursimu menunggu pengganti',
      'REPLACED' => 'Kursimu sudah diganti',
      'ABSENT' => 'Kamu tidak ikut main',
      _ => null,
    };
    final Widget action;
    if (leftSeat != null) {
      action = SebarButton(label: leftSeat, height: 46, onPressed: null);
    } else if (joined && lobby.isHost && open) {
      // Host: kunci room lebih awal, plus bubar (sampai H-1) atau keluar (hari H).
      action = Row(
        children: [
          Expanded(
            child: GhostButton(
              label: _matchDay ? 'Keluar' : 'Bubarkan',
              color: C.danger,
              height: 46,
              onPressed: _matchDay ? onLeave : onDisband,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SebarButton(
              label: 'Kunci room',
              height: 46,
              onPressed: onLock,
            ),
          ),
        ],
      );
    } else if (joined) {
      action = GhostButton(
        label: 'Keluar dari room',
        color: C.danger,
        height: 46,
        onPressed: onLeave,
      );
    } else {
      action = SebarButton(
        label: !open
            ? 'Join ditutup'
            : lobby.isFull
            ? 'Room penuh'
            : enough
            ? 'Join · ${rupiah(lobby.pricePerPerson)}'
            : 'Top up dulu',
        height: 46,
        onPressed: !open || lobby.isFull ? null : onJoin,
      );
    }
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
                  Text(joined ? 'Porsimu' : 'Saldo tersedia', style: T.caption),
                  Text(
                    rupiah(
                      !joined
                          ? wallet.available
                          : lobby.mine?.phase == 'HOST'
                          ? lobby.hostShare ?? lobby.share
                          : lobby.share,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: C.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(child: action),
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
            'Kalau keluar',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
          ),
          SizedBox(height: 6),
          Text('2 jam pertama · keluar bebas, refund penuh', style: T.caption),
          Text(
            'Setelah itu · ada pengganti: refund − Rp10.000',
            style: T.caption,
          ),
          Text('Tidak ada pengganti / tidak datang · hangus', style: T.caption),
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
