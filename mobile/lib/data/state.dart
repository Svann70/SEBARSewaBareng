import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../core/theme.dart';

enum Sport { badminton, futsal, volley, minisoccer }

extension SportX on Sport {
  String get label => switch (this) {
    Sport.badminton => 'Badminton',
    Sport.futsal => 'Futsal',
    Sport.volley => 'Voli',
    Sport.minisoccer => 'Mini Soccer',
  };

  IconData get icon => switch (this) {
    Sport.badminton => Icons.sports_tennis,
    Sport.futsal => Icons.sports_soccer,
    Sport.volley => Icons.sports_volleyball,
    Sport.minisoccer => Icons.sports_football,
  };

  /// Header hero memakai satu warna brand saja supaya layar tidak ramai;
  /// cabang olahraga dibedakan lewat ikon dan label, bukan warna.
  List<Color> get gradient => C.primaryPanel;
}

/// Dua akun dalam satu aplikasi: pemain dan venue.
enum AccountRole { player, venue }

extension AccountRoleX on AccountRole {
  String get label => switch (this) {
    AccountRole.player => 'Pemain',
    AccountRole.venue => 'Venue',
  };

  String get hint => switch (this) {
    AccountRole.player => 'Cari room, join, bayar patungan',
    AccountRole.venue => 'Kelola lapangan, jadwal, dan pencairan',
  };

  IconData get icon => switch (this) {
    AccountRole.player => Icons.sports_tennis,
    AccountRole.venue => Icons.storefront_outlined,
  };

  String get home => switch (this) {
    AccountRole.player => '/home',
    AccountRole.venue => '/venue',
  };
}

/// Satu form login untuk pemain dan venue: peran ditentukan dari akun.
/// ponytail: selama belum ada API, domain email dijadikan penentu
/// (`@venue.sebar.app` = akun mitra); ganti ke peran dari server saat ada.
AccountRole roleForEmail(String email) {
  final value = email.trim().toLowerCase();
  return value.startsWith('admin') || value.endsWith('@venue.sebar.app')
      ? AccountRole.venue
      : AccountRole.player;
}

class AuthNotifier extends Notifier<AccountRole?> {
  @override
  AccountRole? build() => null;

  void login(AccountRole role) => state = role;

  void logout() => state = null;
}

final authProvider = NotifierProvider<AuthNotifier, AccountRole?>(
  AuthNotifier.new,
);

/// Profil venue pemilik akun venue (seed).
const venueProfile = (
  name: 'GOR C-Tra Arena',
  city: 'Bandung',
  courts: 2,
  rating: 4.8,
  verified: true,
  payout: 12750000,
  joinedAt: 'Mitra sejak Mar 2024',
);

/// Venue + aturan harga sewa per jam. Harga akhir mengikuti hari:
/// Senin–Jumat memakai tarif weekday, Sabtu–Minggu tarif weekend.
class VenueInfo {
  const VenueInfo({
    required this.name,
    required this.city,
    required this.courts,
    required this.weekdayRate,
    required this.weekendRate,
    this.openHour = 6,
    this.closeHour = 22,
  });

  final String name;
  final String city;
  final int courts;
  final int weekdayRate;
  final int weekendRate;
  final int openHour;
  final int closeHour;

  bool isWeekend(DateTime day) => day.weekday >= DateTime.saturday;

  int rateOn(DateTime day) => isWeekend(day) ? weekendRate : weekdayRate;

  String get rateLabel =>
      'Weekday Rp${_short(weekdayRate)}/jam · Weekend Rp${_short(weekendRate)}/jam';

  static String _short(int value) {
    if (value >= 1000) {
      final k = value / 1000;
      final text = k == k.roundToDouble()
          ? k.round().toString()
          : k.toStringAsFixed(1);
      return '$text rb';
    }
    return '$value';
  }
}

const venues = <VenueInfo>[
  VenueInfo(
    name: 'GOR C-Tra Arena',
    city: 'Bandung',
    courts: 2,
    weekdayRate: 100000,
    weekendRate: 150000,
  ),
  VenueInfo(
    name: 'Arena Futsal Dago',
    city: 'Bandung',
    courts: 3,
    weekdayRate: 120000,
    weekendRate: 160000,
  ),
  VenueInfo(
    name: 'GOR Sumarecon',
    city: 'Jakarta',
    courts: 2,
    weekdayRate: 150000,
    weekendRate: 200000,
  ),
  VenueInfo(
    name: 'Lapangan Sutos',
    city: 'Surabaya',
    courts: 4,
    weekdayRate: 175000,
    weekendRate: 225000,
  ),
];

VenueInfo venueByName(String name) =>
    venues.firstWhere((v) => v.name == name, orElse: () => venues.first);

/// ── Jadwal venue ─────────────────────────────────────────────────────────

enum SlotStatus { open, booked, lobby, closed }

extension SlotStatusX on SlotStatus {
  String get label => switch (this) {
    SlotStatus.open => 'Kosong',
    SlotStatus.booked => 'Terisi',
    SlotStatus.lobby => 'Room berjalan',
    SlotStatus.closed => 'Ditutup',
  };

  Color get color => switch (this) {
    SlotStatus.open => C.primary,
    SlotStatus.booked => C.muted,
    SlotStatus.lobby => C.amber,
    SlotStatus.closed => C.danger,
  };

  IconData get icon => switch (this) {
    SlotStatus.open => Icons.event_available,
    SlotStatus.booked => Icons.check_circle_outline,
    SlotStatus.lobby => Icons.groups_2_outlined,
    SlotStatus.closed => Icons.block,
  };
}

class VenueSlot {
  const VenueSlot({
    required this.id,
    required this.court,
    required this.start,
    required this.end,
    required this.price,
    this.status = SlotStatus.open,
    this.guest,
  });

  final String id;
  final int court;
  final DateTime start;
  final DateTime end;
  final int price;
  final SlotStatus status;

  /// Nama room atau pemesan saat slot terisi.
  final String? guest;

  int get durationHours => end.difference(start).inHours;

  /// Tarif yang tampil ke pemain selalu per jam.
  int get pricePerHour =>
      durationHours <= 0 ? price : (price / durationHours).round();

  VenueSlot copyWith({SlotStatus? status, int? price, String? guest}) =>
      VenueSlot(
        id: id,
        court: court,
        start: start,
        end: end,
        price: price ?? this.price,
        status: status ?? this.status,
        guest: guest ?? this.guest,
      );
}

DateTime _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset);
}

DateTime _slotAt(int dayOffset, int hour) => DateTime(
  _day(dayOffset).year,
  _day(dayOffset).month,
  _day(dayOffset).day,
  hour,
);

class VenueSlotsNotifier extends Notifier<List<VenueSlot>> {
  @override
  List<VenueSlot> build() => [
    VenueSlot(
      id: 's1',
      court: 1,
      start: _slotAt(0, 8),
      end: _slotAt(0, 10),
      price: 200000,
      status: SlotStatus.booked,
      guest: 'Raka · Badminton',
    ),
    VenueSlot(
      id: 's2',
      court: 1,
      start: _slotAt(0, 10),
      end: _slotAt(0, 12),
      price: 200000,
    ),
    VenueSlot(
      id: 's3',
      court: 1,
      start: _slotAt(0, 13),
      end: _slotAt(0, 15),
      price: 200000,
      status: SlotStatus.lobby,
      guest: 'Room butuh 2 orang',
    ),
    VenueSlot(
      id: 's4',
      court: 1,
      start: _slotAt(0, 16),
      end: _slotAt(0, 18),
      price: 250000,
    ),
    VenueSlot(
      id: 's5',
      court: 1,
      start: _slotAt(0, 19),
      end: _slotAt(0, 21),
      price: 300000,
      status: SlotStatus.booked,
      guest: 'Tim Dago · Futsal',
    ),
    VenueSlot(
      id: 's6',
      court: 2,
      start: _slotAt(0, 16),
      end: _slotAt(0, 18),
      price: 220000,
      status: SlotStatus.booked,
      guest: 'Tim Sutos · Mini Soccer',
    ),
    VenueSlot(
      id: 's7',
      court: 2,
      start: _slotAt(0, 18),
      end: _slotAt(0, 20),
      price: 220000,
    ),
    VenueSlot(
      id: 's8',
      court: 2,
      start: _slotAt(0, 20),
      end: _slotAt(0, 22),
      price: 0,
      status: SlotStatus.closed,
    ),
    VenueSlot(
      id: 's9',
      court: 1,
      start: _slotAt(1, 8),
      end: _slotAt(1, 10),
      price: 200000,
      status: SlotStatus.booked,
      guest: 'Ayu · Badminton',
    ),
    VenueSlot(
      id: 's10',
      court: 1,
      start: _slotAt(1, 10),
      end: _slotAt(1, 12),
      price: 200000,
    ),
    VenueSlot(
      id: 's11',
      court: 2,
      start: _slotAt(1, 19),
      end: _slotAt(1, 21),
      price: 250000,
    ),
  ];

  bool _overlaps(int court, DateTime start, DateTime end) => state.any(
    (s) =>
        s.court == court &&
        s.status != SlotStatus.closed &&
        s.start.isBefore(end) &&
        start.isBefore(s.end),
  );

  /// null = sukses, selain itu pesan error.
  String? add({
    required int court,
    required DateTime start,
    required DateTime end,
    required int price,
  }) {
    if (_overlaps(court, start, end)) return 'Slot bentrok dengan jadwal lain.';
    state = [
      ...state,
      VenueSlot(
        id: 's${DateTime.now().millisecondsSinceEpoch}',
        court: court,
        start: start,
        end: end,
        price: price,
      ),
    ];
    return null;
  }

  void setStatus(String id, SlotStatus status) {
    state = [
      for (final s in state) s.id == id ? s.copyWith(status: status) : s,
    ];
  }

  void setPrice(String id, int price) {
    state = [for (final s in state) s.id == id ? s.copyWith(price: price) : s];
  }
}

final venueSlotsProvider =
    NotifierProvider<VenueSlotsNotifier, List<VenueSlot>>(
      VenueSlotsNotifier.new,
    );

List<VenueSlot> slotsOn(List<VenueSlot> all, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final list =
      all
          .where((s) => DateTime(s.start.year, s.start.month, s.start.day) == d)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return list;
}

/// Siapa yang boleh masuk room.
enum LobbyAccess { open, link, password }

extension LobbyAccessX on LobbyAccess {
  String get label => switch (this) {
    LobbyAccess.open => 'Publik',
    LobbyAccess.link => 'Via link',
    LobbyAccess.password => 'Pakai sandi',
  };

  String get hint => switch (this) {
    LobbyAccess.open => 'Muncul di daftar, siapa saja bisa join',
    LobbyAccess.link => 'Hanya yang punya link undangan',
    LobbyAccess.password => 'Butuh sandi untuk join',
  };

  IconData get icon => switch (this) {
    LobbyAccess.open => Icons.public,
    LobbyAccess.link => Icons.link,
    LobbyAccess.password => Icons.lock_outline,
  };
}

class Member {
  const Member({required this.name, this.isMe = false, this.isHost = false});

  final String name;
  final bool isMe;
  final bool isHost;
}

enum LobbyStatus { open, filled, confirmed, expired, cancelled }

class Lobby {
  const Lobby({
    required this.id,
    required this.title,
    required this.sport,
    required this.venue,
    required this.city,
    required this.court,
    required this.start,
    required this.end,
    required this.priceTotal,
    required this.quota,
    required this.deadline,
    required this.members,
    this.status = LobbyStatus.open,
    this.isHost = false,
    this.access = LobbyAccess.open,
    this.secret,
  });

  final String id;
  final String title;
  final Sport sport;
  final String venue;
  final String city;
  final String court;
  final DateTime start;
  final DateTime end;
  final int priceTotal;
  final int quota;
  final DateTime deadline;
  final List<Member> members;
  final LobbyStatus status;
  final bool isHost;

  /// Sandi room atau kode undangan, tergantung [access].
  final LobbyAccess access;
  final String? secret;

  int get pricePerPerson => pricePerPersonOf(priceTotal, quota);
  int get joined => members.length;
  int get remaining => quota - joined;
  bool get isFull => remaining <= 0;
  bool get joinedByMe => members.any((m) => m.isMe);
  Duration get untilStart => start.difference(DateTime.now());

  Lobby copyWith({List<Member>? members, LobbyStatus? status}) => Lobby(
    id: id,
    title: title,
    sport: sport,
    venue: venue,
    city: city,
    court: court,
    start: start,
    end: end,
    priceTotal: priceTotal,
    quota: quota,
    deadline: deadline,
    members: members ?? this.members,
    status: status ?? this.status,
    isHost: isHost,
    access: access,
    secret: secret,
  );
}

/// Cermin `price_per_person` generated column; dipakai agar nama tetap terbaca.
int pricePerPersonOf(int total, int quota) => pricePerPerson(total, quota);

const me = Member(name: 'Raka', isMe: true);

class WalletEntry {
  const WalletEntry({
    required this.type,
    required this.amount,
    required this.label,
    required this.at,
  });

  final String type; // TOPUP, HOLD, RELEASE, CAPTURE, PENALTY
  final int amount; // negatif = keluar
  final String label;
  final DateTime at;
}

/// Nama jenis mutasi untuk pengguna — kode internal tidak ditampilkan.
extension WalletEntryX on WalletEntry {
  String get typeLabel => switch (type) {
    'TOPUP' => 'Top up',
    'HOLD' => 'Dana dikunci',
    'RELEASE' => 'Dana dilepas',
    'CAPTURE' => 'Pembayaran',
    'PENALTY' => 'Denda',
    _ => 'Mutasi',
  };
}

class Wallet {
  const Wallet({
    required this.balance,
    required this.held,
    required this.entries,
  });

  final int balance;
  final int held;
  final List<WalletEntry> entries;

  int get available => balance - held;

  Wallet copyWith({int? balance, int? held, List<WalletEntry>? entries}) =>
      Wallet(
        balance: balance ?? this.balance,
        held: held ?? this.held,
        entries: entries ?? this.entries,
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.title,
    required this.venue,
    required this.court,
    required this.city,
    required this.start,
    required this.end,
    required this.sport,
    required this.amount,
    required this.token,
    this.checkedIn = false,
  });

  final String id;
  final String code;
  final String title;
  final String venue;
  final String court;
  final String city;
  final DateTime start;
  final DateTime end;
  final Sport sport;
  final int amount;
  final String token;
  final bool checkedIn;

  Booking copyWith({bool? checkedIn}) => Booking(
    id: id,
    code: code,
    title: title,
    venue: venue,
    court: court,
    city: city,
    start: start,
    end: end,
    sport: sport,
    amount: amount,
    token: token,
    checkedIn: checkedIn ?? this.checkedIn,
  );
}

DateTime _at(int dayOffset, int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + dayOffset, hour);
}

final _seedLobbies = <Lobby>[
  Lobby(
    id: 'lb1',
    title: 'Badminton Sabtu Pagi',
    sport: Sport.badminton,
    venue: 'GOR C-Tra Arena',
    city: 'Bandung',
    court: 'Lapangan 3',
    start: _at(2, 8),
    end: _at(2, 10),
    priceTotal: 400000,
    quota: 8,
    deadline: _at(2, 2),
    members: const [
      Member(name: 'Dimas', isHost: true),
      Member(name: 'Ayu'),
      Member(name: 'Bagas'),
      Member(name: 'Nadia'),
      Member(name: 'Fajar'),
    ],
  ),
  Lobby(
    id: 'lb2',
    title: 'Futsal Malam Seru',
    sport: Sport.futsal,
    venue: 'Arena Futsal Dago',
    city: 'Bandung',
    court: 'Court A',
    start: _at(1, 20),
    end: _at(1, 22),
    priceTotal: 300000,
    quota: 10,
    deadline: _at(1, 14),
    access: LobbyAccess.password,
    secret: 'futsal123',
    members: const [
      Member(name: 'Rian', isHost: true),
      Member(name: 'Yoga'),
      Member(name: 'Tio'),
      Member(name: 'Sasa'),
      Member(name: 'Bima'),
      Member(name: 'Kiki'),
      Member(name: 'Lala'),
      Member(name: 'Rafi'),
      Member(name: 'Wulan'),
    ],
  ),
  Lobby(
    id: 'lb3',
    title: 'Voli Sore Santai',
    sport: Sport.volley,
    venue: 'GOR Sumarecon',
    city: 'Jakarta',
    court: 'Lapangan Indoor 1',
    start: _at(3, 16),
    end: _at(3, 18),
    priceTotal: 250000,
    quota: 6,
    deadline: _at(3, 10),
    access: LobbyAccess.link,
    secret: 'VOLI-SORE',
    members: const [
      Member(name: 'Sinta', isHost: true),
      Member(name: 'Adi'),
      Member(name: 'Mira'),
      Member(name: 'Doni'),
    ],
  ),
  Lobby(
    id: 'lb4',
    title: 'Mini Soccer Subuh',
    sport: Sport.minisoccer,
    venue: 'Lapangan Sutos',
    city: 'Surabaya',
    court: 'Mini Soccer 2',
    start: _at(4, 6),
    end: _at(4, 8),
    priceTotal: 600000,
    quota: 12,
    deadline: _at(4, 0),
    members: const [
      Member(name: 'Hendra', isHost: true),
      Member(name: 'Gilang'),
      Member(name: 'Putra'),
      Member(name: 'Aris'),
      Member(name: 'Bayu'),
      Member(name: 'Ilham'),
    ],
  ),
];

/// Room tambahan (seed) supaya daftar penuh terasa nyata: lebih dari 20 room,
/// jadi halaman "Semua room" punya alasan untuk ada.
const _extraTitles = [
  'Badminton Sore Ceria',
  'Futsal Malam Seru',
  'Voli Santai Akhir Pekan',
  'Mini Soccer Jumat Malam',
  'Badminton Ganda Campuran',
  'Futsal Pagi Sebelum Kerja',
  'Voli Putri Komunitas',
  'Mini Soccer Turnamen Kecil',
];

const _extraNames = [
  'Aldi',
  'Nia',
  'Reno',
  'Maya',
  'Fikri',
  'Intan',
  'Dewa',
  'Sari',
];

final _extraLobbies = <Lobby>[
  for (var i = 0; i < 22; i++)
    Lobby(
      id: 'lbx$i',
      title: _extraTitles[i % _extraTitles.length],
      sport: Sport.values[i % Sport.values.length],
      venue: venues[i % venues.length].name,
      city: venues[i % venues.length].city,
      court: 'Lapangan ${1 + i % 3}',
      start: _at(2 + i % 7, 8 + i % 10),
      end: _at(2 + i % 7, 10 + i % 10),
      priceTotal: venues[i % venues.length].rateOn(_at(2 + i % 7, 8)),
      quota: 6 + i % 8,
      deadline: _at(2 + i % 7, 2),
      members: [
        Member(name: _extraNames[i % _extraNames.length], isHost: true),
        Member(name: _extraNames[(i + 3) % _extraNames.length]),
        Member(name: _extraNames[(i + 5) % _extraNames.length]),
      ],
    ),
];

class LobbiesNotifier extends Notifier<List<Lobby>> {
  @override
  List<Lobby> build() => [..._seedLobbies, ..._extraLobbies];

  Lobby byId(String id) => state.firstWhere((l) => l.id == id);

  /// Hasil join: null = sukses, selain itu pesan error untuk UI.
  ///
  /// [useWallet] false = bayar lewat QRIS/transfer, jadi saldo dompet tidak
  /// disentuh. ponytail: pembayaran eksternal belum diverifikasi server;
  /// sambungkan ke webhook pembayaran saat gateway tersedia.
  String? join(String id, {String? secret, bool useWallet = true}) {
    final lobby = byId(id);
    if (lobby.isFull) return 'Room sudah penuh.';
    if (lobby.joinedByMe) return 'Kamu sudah tergabung di room ini.';
    if (lobby.access == LobbyAccess.password &&
        (secret ?? '').trim() != lobby.secret) {
      return 'Sandi room salah.';
    }
    if (lobby.access == LobbyAccess.link &&
        (secret ?? '').trim().toUpperCase() != lobby.secret) {
      return 'Kode undangan tidak cocok.';
    }
    if (useWallet) {
      final wallet = ref.read(walletProvider);
      if (wallet.available < lobby.pricePerPerson) {
        return 'Saldo tersedia tidak cukup untuk join lobby ini.';
      }

      ref
          .read(walletProvider.notifier)
          .hold(lobby.pricePerPerson, 'Hold · ${lobby.title}');
    }

    final updated = [...lobby.members, me];
    final full = updated.length >= lobby.quota;
    state = [
      for (final l in state)
        l.id == id
            ? l.copyWith(
                members: updated,
                status: full ? LobbyStatus.confirmed : LobbyStatus.open,
              )
            : l,
    ];

    if (full) {
      // Simulasi confirm_lobby(): hold dikonversi jadi capture + booking dibuat.
      ref
          .read(walletProvider.notifier)
          .capture(lobby.pricePerPerson, lobby.title);
      ref
          .read(bookingsProvider.notifier)
          .createFrom(lobby.copyWith(members: updated));
    }
    return null;
  }

  void cancelMine(String id) {
    final lobby = byId(id);
    if (!lobby.joinedByMe) return;
    final penalty = penaltyFor(untilStart: lobby.untilStart);
    ref
        .read(walletProvider.notifier)
        .releaseWithPenalty(
          lobby.pricePerPerson,
          (lobby.pricePerPerson * penalty.penaltyPct / 100).round(),
          'Batal · ${lobby.title}',
        );
    state = [
      for (final l in state)
        l.id == id
            ? l.copyWith(members: l.members.where((m) => !m.isMe).toList())
            : l,
    ];
  }

  void create({
    required String title,
    required Sport sport,
    required String venue,
    required String city,
    required String court,
    required DateTime start,
    required int priceTotal,
    required int quota,
    LobbyAccess access = LobbyAccess.open,
    String? secret,
  }) {
    final lobby = Lobby(
      id: 'lb${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      sport: sport,
      venue: venue,
      city: city,
      court: court,
      start: start,
      end: start.add(const Duration(hours: 2)),
      priceTotal: priceTotal,
      quota: quota,
      deadline: start.subtract(const Duration(hours: 6)),
      members: [me],
      isHost: true,
      access: access,
      secret: secret,
    );
    ref
        .read(walletProvider.notifier)
        .hold(lobby.pricePerPerson, 'Hold · ${lobby.title}');
    state = [lobby, ...state];
  }
}

final lobbiesProvider = NotifierProvider<LobbiesNotifier, List<Lobby>>(
  LobbiesNotifier.new,
);

class WalletNotifier extends Notifier<Wallet> {
  @override
  Wallet build() => Wallet(
    balance: 250000,
    held: 0,
    entries: [
      WalletEntry(
        type: 'TOPUP',
        amount: 250000,
        label: 'Top up saldo',
        at: DateTime.now().subtract(const Duration(days: 3)),
      ),
      WalletEntry(
        type: 'CAPTURE',
        amount: -50000,
        label: 'Booking · Badminton Jumat',
        at: DateTime.now().subtract(const Duration(days: 5)),
      ),
      WalletEntry(
        type: 'TOPUP',
        amount: 50000,
        label: 'Top up saldo',
        at: DateTime.now().subtract(const Duration(days: 6)),
      ),
    ],
  );

  void topUp(int amount) {
    state = state.copyWith(
      balance: state.balance + amount,
      entries: [
        WalletEntry(
          type: 'TOPUP',
          amount: amount,
          label: 'Top up saldo',
          at: DateTime.now(),
        ),
        ...state.entries,
      ],
    );
  }

  void hold(int amount, String label) {
    state = state.copyWith(
      held: state.held + amount,
      entries: [
        WalletEntry(type: 'HOLD', amount: 0, label: label, at: DateTime.now()),
        ...state.entries,
      ],
    );
  }

  void capture(int amount, String label) {
    state = state.copyWith(
      balance: state.balance - amount,
      held: state.held - amount,
      entries: [
        WalletEntry(
          type: 'CAPTURE',
          amount: -amount,
          label: 'Booking · $label',
          at: DateTime.now(),
        ),
        ...state.entries,
      ],
    );
  }

  void releaseWithPenalty(int amount, int penalty, String label) {
    final entry = penalty > 0
        ? WalletEntry(
            type: 'PENALTY',
            amount: -penalty,
            label: '$label (denda 50%)',
            at: DateTime.now(),
          )
        : WalletEntry(
            type: 'RELEASE',
            amount: 0,
            label: label,
            at: DateTime.now(),
          );
    state = state.copyWith(
      held: state.held - amount,
      balance: state.balance - penalty,
      entries: [entry, ...state.entries],
    );
  }
}

final walletProvider = NotifierProvider<WalletNotifier, Wallet>(
  WalletNotifier.new,
);

class BookingsNotifier extends Notifier<List<Booking>> {
  @override
  List<Booking> build() => [
    Booking(
      id: 'bk1',
      code: 'SEB-4K2P',
      title: 'Badminton Jumat Malam',
      venue: 'GOR C-Tra Arena',
      court: 'Lapangan 1',
      city: 'Bandung',
      start: _at(1, 19),
      end: _at(1, 21),
      sport: Sport.badminton,
      amount: 50000,
      token: 'SEB-4K2P:u_raka:exp_1730000000:sig_9f2a',
    ),
  ];

  void createFrom(Lobby lobby) {
    final code = 'SEB-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
    state = [
      Booking(
        id: 'bk${DateTime.now().millisecondsSinceEpoch}',
        code: code,
        title: lobby.title,
        venue: lobby.venue,
        court: lobby.court,
        city: lobby.city,
        start: lobby.start,
        end: lobby.end,
        sport: lobby.sport,
        amount: lobby.pricePerPerson,
        token: '$code:u_raka:exp_1730000000:sig_${code.hashCode}',
      ),
      ...state,
    ];
  }

  void checkIn(String id) {
    state = [
      for (final b in state) b.id == id ? b.copyWith(checkedIn: true) : b,
    ];
  }
}

final bookingsProvider = NotifierProvider<BookingsNotifier, List<Booking>>(
  BookingsNotifier.new,
);

/// Filter pencarian di Home.
class Filter {
  const Filter({this.sport, this.city = 'Semua kota', this.query = ''});

  final Sport? sport;
  final String city;
  final String query;
}

class FilterNotifier extends Notifier<Filter> {
  @override
  Filter build() => const Filter();

  void setSport(Sport? sport) =>
      state = Filter(sport: sport, city: state.city, query: state.query);

  void setCity(String city) =>
      state = Filter(sport: state.sport, city: city, query: state.query);

  void setQuery(String query) =>
      state = Filter(sport: state.sport, city: state.city, query: query);
}

final filterProvider = NotifierProvider<FilterNotifier, Filter>(
  FilterNotifier.new,
);

final filteredLobbiesProvider = Provider<List<Lobby>>((ref) {
  final f = ref.watch(filterProvider);
  final all = ref.watch(lobbiesProvider);
  final needle = f.query.trim().toLowerCase();
  return all.where((l) {
    if (l.access == LobbyAccess.link) return false;
    if (f.sport != null && l.sport != f.sport) return false;
    if (f.city != 'Semua kota' && l.city != f.city) return false;
    if (needle.isNotEmpty) {
      final haystack =
          '${l.title} ${l.venue} ${l.city} ${l.court} ${l.sport.label}'
              .toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    return l.status == LobbyStatus.open || l.status == LobbyStatus.filled;
  }).toList();
});

/// Statistik venue untuk layar analytics.
const venueSummary = (
  bookings: 128,
  revenue: 18450000,
  fee: 922500,
  occupancy: 0.78,
  noShow: 4,
);

const peakHours = <(int, int)>[
  (6, 6),
  (8, 14),
  (10, 9),
  (13, 5),
  (16, 11),
  (18, 22),
  (20, 26),
  (21, 15),
];

const monthlyRevenue = <(String, int)>[
  ('Mei', 8200000),
  ('Jun', 11400000),
  ('Jul', 9800000),
  ('Agu', 14100000),
  ('Sep', 16500000),
  ('Okt', 18450000),
];

/// ── Komunitas ────────────────────────────────────────────────────────────

const chatChannels = <String>['Umum', 'Badminton', 'Futsal', 'Cari lawan'];

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channel,
    required this.author,
    required this.text,
    required this.at,
    this.isMe = false,
  });

  final String id;
  final String channel;
  final String author;
  final String text;
  final DateTime at;
  final bool isMe;
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [
    ChatMessage(
      id: 'm1',
      channel: 'Umum',
      author: 'Dimas',
      text: 'Ada yang main badminton minggu ini? Lapangan 3 masih kosong.',
      at: DateTime.now().subtract(const Duration(minutes: 42)),
    ),
    ChatMessage(
      id: 'm2',
      channel: 'Umum',
      author: 'Ayu',
      text: 'Aku ikut. Jam 8 pagi masih aman.',
      at: DateTime.now().subtract(const Duration(minutes: 37)),
    ),
    ChatMessage(
      id: 'm3',
      channel: 'Badminton',
      author: 'Nadia',
      text: 'Raket cadangan ada 2, bisa dipinjam.',
      at: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    ChatMessage(
      id: 'm4',
      channel: 'Futsal',
      author: 'Rian',
      text: 'Room malam ini butuh 2 orang lagi. Sandinya ada di room.',
      at: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
  ];

  void send(String channel, String text) {
    final body = text.trim();
    if (body.isEmpty) return;
    state = [
      ...state,
      ChatMessage(
        id: 'm${DateTime.now().millisecondsSinceEpoch}',
        channel: channel,
        author: me.name,
        text: body,
        at: DateTime.now(),
        isMe: true,
      ),
    ];
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

/// Kode undangan room privat yang bisa dimasukkan dari Home.
Lobby? lobbyByInviteCode(List<Lobby> all, String code) {
  final needle = code.trim().toUpperCase();
  if (needle.isEmpty) return null;
  for (final l in all) {
    if (l.access == LobbyAccess.link && l.secret == needle) return l;
  }
  return null;
}
