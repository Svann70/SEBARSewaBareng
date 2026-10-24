import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../core/money.dart';
import '../core/theme.dart';
import '../core/widgets.dart' show courtPhotosProvider;
import 'api.dart';

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

/// Profil pengguna yang sedang login (dari server).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.reliability = 100,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final AccountRole role;
  final int reliability;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    phone: (json['phone'] as String?)?.trim(),
    role: accountRoleFromApi(json['role'] as String?),
    reliability: _asInt(json['reliabilityScore'], 100),
  );
}

AccountRole accountRoleFromApi(String? value) =>
    value == 'VENUE_ADMIN' ? AccountRole.venue : AccountRole.player;

class SessionNotifier extends Notifier<SessionUser?> {
  @override
  SessionUser? build() => null;

  void set(SessionUser? user) => state = user;
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionUser?>(
  SessionNotifier.new,
);

class AuthNotifier extends Notifier<AccountRole?> {
  @override
  AccountRole? build() {
    void onExpired() => _endSession();
    api.onSessionExpired = onExpired;
    ref.onDispose(() {
      // Container lain (tes) bisa sudah memasang callback-nya sendiri.
      if (api.onSessionExpired == onExpired) api.onSessionExpired = null;
    });
    return null;
  }

  /// Pesan untuk layar masuk setelah sesi dicabut server; dibaca sekali.
  String? _sessionNotice;

  /// Login lokal tanpa token, hanya untuk tes. Jangan dipakai di lib/:
  /// router guard hanya melihat [state].
  @visibleForTesting
  void login(AccountRole role) => state = role;

  @visibleForTesting
  void logout() => state = null;

  /// Login ke server. null = sukses, selain itu pesan error.
  Future<String?> signIn(String email, String password) async {
    try {
      await api.login(email.trim(), password);
      final user = SessionUser.fromJson(api.user ?? const {});
      ref.read(sessionProvider.notifier).set(user);
      await _bootstrap(user.role);
      // Router pindah ke beranda begitu state terisi; tunggu data awal dulu.
      // Sesi bisa dicabut selama bootstrap: jangan masuk tanpa token.
      if (!api.hasSession) {
        return takeSessionNotice() ?? 'Sesi berakhir. Silakan masuk lagi.';
      }
      state = user.role;
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Daftar akun. [venue] wajib untuk akun mitra.
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required AccountRole role,
    Map<String, dynamic>? venue,
  }) async {
    try {
      await api.register(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
        role: role == AccountRole.venue ? 'VENUE_ADMIN' : 'PLAYER',
        venue: role == AccountRole.venue ? venue : null,
      );
      final user = SessionUser.fromJson(api.user ?? const {});
      ref.read(sessionProvider.notifier).set(user);
      await _bootstrap(user.role);
      // Router pindah ke beranda begitu state terisi; tunggu data awal dulu.
      // Sesi bisa dicabut selama bootstrap: jangan masuk tanpa token.
      if (!api.hasSession) {
        return takeSessionNotice() ?? 'Sesi berakhir. Silakan masuk lagi.';
      }
      state = user.role;
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<void> signOut() async {
    await api.logout();
    _endSession(notice: null);
    // Callback sesi berakhir bisa terpanggil selama logout menunggu server.
    _sessionNotice = null;
  }

  /// Kosongkan sesi lalu buang data akun sebelumnya. Router mengarahkan ke
  /// /login begitu [state] null.
  void _endSession({String? notice = 'Sesi berakhir. Silakan masuk lagi.'}) {
    if (state == null && ref.read(sessionProvider) == null) return;
    _sessionNotice = notice;
    ref.read(sessionProvider.notifier).set(null);
    state = null;
    // Ditunda: callback bisa terpanggil di tengah refresh provider lain.
    venueProfile = _seedVenueProfile;
    Future.microtask(() {
      if (!ref.mounted) return;
      for (final p in _accountData) {
        ref.invalidate(p);
      }
    });
  }

  String? takeSessionNotice() {
    final notice = _sessionNotice;
    _sessionNotice = null;
    return notice;
  }

  /// Simpan nama/telepon ke server lalu perbarui sesi lokal.
  /// [clearPhone] true menghapus nomor telepon.
  Future<String?> updateProfile({
    String? fullName,
    String? phone,
    bool clearPhone = false,
  }) async {
    try {
      await api.updateMe(
        fullName: fullName,
        phone: phone,
        clearPhone: clearPhone,
      );
      ref
          .read(sessionProvider.notifier)
          .set(SessionUser.fromJson(api.user ?? const {}));
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Ubah password. Sukses = semua sesi dicabut server, pemanggil wajib signOut.
  Future<String?> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      await api.changePassword(current: current, next: next);
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Muat data awal setelah login. Kegagalan satu bagian tidak membatalkan
  /// login; layar tetap menampilkan data terakhir/seed.
  Future<void> _bootstrap(AccountRole role) async {
    final jobs = <Future<Object?>>[
      ref.read(walletProvider.notifier).refresh(),
      ref.read(bookingsProvider.notifier).refresh(),
      ref.read(lobbiesProvider.notifier).refresh(),
    ];
    if (role == AccountRole.venue) {
      jobs.add(ref.read(venueSlotsProvider.notifier).refresh());
    } else {
      jobs.add(ref.read(venuesProvider.notifier).refresh());
    }
    await Future.wait(jobs);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AccountRole?>(
  AuthNotifier.new,
);

/// Data milik akun yang dibuang saat keluar, supaya akun berikutnya di
/// perangkat yang sama tidak melihatnya.
final _accountData = <ProviderOrFamily>[
  venuesProvider,
  venueSlotsProvider,
  lobbiesProvider,
  walletProvider,
  bookingsProvider,
  filterProvider,
  chatProvider,
  courtPhotosProvider,
];

/// Pesan error yang aman ditampilkan ke pengguna.
String apiMessage(Object error) =>
    error is ApiException ? error.message : 'Tidak bisa menghubungi server.';

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  // Postgres NUMERIC datang sebagai string desimal ("100000.00").
  if (value is String) {
    return num.tryParse(value)?.toInt() ?? fallback;
  }
  return fallback;
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

DateTime _asDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

String _apiDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

Sport sportFromApi(String? value) => switch (value?.toUpperCase()) {
  'FUTSAL' => Sport.futsal,
  'VOLLEY' => Sport.volley,
  'MINISOCCER' => Sport.minisoccer,
  _ => Sport.badminton,
};

String sportToApi(Sport sport) => switch (sport) {
  Sport.badminton => 'BADMINTON',
  Sport.futsal => 'FUTSAL',
  Sport.volley => 'VOLLEY',
  Sport.minisoccer => 'MINISOCCER',
};

LobbyStatus _lobbyStatusFromApi(String? value) => switch (value) {
  'FILLED' => LobbyStatus.filled,
  'CONFIRMED' => LobbyStatus.confirmed,
  'EXPIRED' => LobbyStatus.expired,
  'CANCELLED' => LobbyStatus.cancelled,
  _ => LobbyStatus.open,
};

/// Profil venue pemilik akun venue. Nilai awal = seed, diganti dari
/// `/venue/venues` setelah login supaya nama dan jumlah lapangan sesuai akun.
const _seedVenueProfile = (
  name: 'GOR C-Tra Arena',
  city: 'Bandung',
  courts: 2,
  rating: 4.8,
  verified: true,
  payout: 12750000,
  joinedAt: 'Mitra sejak Mar 2024',
);
var venueProfile = _seedVenueProfile;

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

/// ── Katalog venue dari API ──────────────────────────────────────────────

class ApiCourt {
  const ApiCourt({
    required this.id,
    required this.name,
    required this.sport,
    required this.pricePerHour,
    required this.capacity,
  });

  final String id;
  final String name;
  final Sport sport;
  final int pricePerHour;
  final int capacity;

  factory ApiCourt.fromJson(Map<String, dynamic> json) => ApiCourt(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Lapangan',
    sport: sportFromApi(json['sport'] as String?),
    pricePerHour: _asInt(json['pricePerHour']),
    capacity: _asInt(json['capacity'], 12),
  );
}

class ApiVenue {
  const ApiVenue({
    required this.id,
    required this.name,
    required this.city,
    required this.courts,
  });

  final String id;
  final String name;
  final String city;
  final List<ApiCourt> courts;

  factory ApiVenue.fromJson(Map<String, dynamic> json) => ApiVenue(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Venue',
    city: json['city'] as String? ?? '',
    courts: [
      for (final c in _asList(json['courts'])) ApiCourt.fromJson(_asMap(c)),
    ],
  );
}

class ApiSlot {
  const ApiSlot({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.sport,
    required this.start,
    required this.end,
    required this.price,
    required this.status,
    this.lobbyId,
  });

  final String id;
  final String courtId;
  final String courtName;
  final Sport sport;
  final DateTime start;
  final DateTime end;
  final int price;
  final String status;
  final String? lobbyId;

  bool get isOpen => status == 'OPEN' && lobbyId == null;

  factory ApiSlot.fromJson(Map<String, dynamic> json) => ApiSlot(
    id: json['id'] as String? ?? '',
    courtId: json['courtId'] as String? ?? '',
    courtName: json['courtName'] as String? ?? 'Lapangan',
    sport: sportFromApi(json['sport'] as String?),
    start: _asDate(json['startAt']),
    end: _asDate(json['endAt']),
    price: _asInt(json['price']),
    status: json['status'] as String? ?? 'OPEN',
    lobbyId: json['lobbyId'] as String?,
  );
}

Sport _seedSport(String venue) {
  final name = venue.toLowerCase();
  if (name.contains('futsal')) return Sport.futsal;
  if (name.contains('voli')) return Sport.volley;
  if (name.contains('soccer') || name.contains('sutos')) {
    return Sport.minisoccer;
  }
  return Sport.badminton;
}

class VenuesNotifier extends Notifier<List<ApiVenue>> {
  @override
  List<ApiVenue> build() => _seedVenues();

  /// Seed dipakai sampai `/venues` menjawab, supaya layar tidak kosong saat
  /// offline. Id seed tidak bisa dipakai membuat lobby.
  static List<ApiVenue> _seedVenues() => [
    for (final v in venues)
      ApiVenue(
        id: 'seed-${v.name}',
        name: v.name,
        city: v.city,
        courts: [
          for (var c = 1; c <= v.courts; c++)
            ApiCourt(
              id: 'seed-${v.name}-$c',
              name: 'Lapangan $c',
              sport: _seedSport(v.name),
              pricePerHour: v.weekdayRate,
              capacity: 12,
            ),
        ],
      ),
  ];

  Future<String?> refresh() async {
    try {
      final data = _asMap(await api.get('/venues'));
      final items = [
        for (final item in _asList(data['items']))
          ApiVenue.fromJson(_asMap(item)),
      ];
      if (items.isNotEmpty) state = items;
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Slot lapangan untuk tanggal tertentu. Kosong = belum ada/tidak bisa
  /// dimuat; layar menampilkan pesan.
  Future<List<ApiSlot>> slots(String venueId, DateTime day) async {
    if (venueId.startsWith('seed-')) return const [];
    try {
      final data = _asMap(
        await api.get('/venues/$venueId/slots', query: {'date': _apiDate(day)}),
      );
      return [
        for (final item in _asList(data['items']))
          ApiSlot.fromJson(_asMap(item)),
      ];
    } catch (_) {
      return const [];
    }
  }
}

final venuesProvider = NotifierProvider<VenuesNotifier, List<ApiVenue>>(
  VenuesNotifier.new,
);

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
    this.courtId,
    this.courtName,
  });

  final String id;
  final int court;
  final DateTime start;
  final DateTime end;
  final int price;
  final SlotStatus status;
  final String? courtId;
  final String? courtName;

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
        courtId: courtId,
        courtName: courtName,
      );
}

class VenueSlotsNotifier extends Notifier<List<VenueSlot>> {
  /// Tanpa seed: slot venue selalu dari server, supaya jadwal tidak pernah
  /// menampilkan data palsu yang menutupi kegagalan muat.
  @override
  List<VenueSlot> build() => const [];

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

  // ── Sisi server (akun venue) ───────────────────────────────────────────

  // Satu akun venue bisa punya beberapa venue (venues.owner_id di DB).
  List<ApiVenue> _venues = const [];
  String? _venueId;
  List<VenueSlot> _raw = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _lastError;
  Future<String?>? _inFlight;

  List<ApiVenue> get venues => _venues;

  /// Sedang memuat dari server — dipakai layar untuk spinner.
  bool get isLoading => _loading;

  /// Pesan kegagalan muat terakhir, null kalau tidak ada/terakhir sukses.
  String? get lastError => _lastError;

  /// True setelah /venue/venues sukses. False = belum bisa kelola lapangan
  /// atau slot; tombol add di layar harus memicu refresh() dulu.
  bool get hasVenue => _venueId != null;

  /// Server sudah menjawab tapi akun ini tidak punya venue sama sekali
  /// (mis. akun lama yang role-nya dinaikkan manual) — bukan kegagalan
  /// muat; layar harus menawarkan membuat venue, bukan muat ulang.
  bool get missingVenue => _loaded && _venues.isEmpty;

  ApiVenue? get venue {
    for (final v in _venues) {
      if (v.id == _venueId) return v;
    }
    return _venues.isEmpty ? null : _venues.first;
  }

  List<ApiCourt> get courts => venue?.courts ?? const [];

  String? get venueId => _venueId;

  /// Pindah venue tanpa request ulang: slot semua venue sudah di [_raw].
  void selectVenue(String id) {
    if (id == _venueId) return;
    _venueId = id;
    _applyProfile();
    _applySlots();
  }

  void _applyProfile() {
    final v = venue;
    if (v == null) return;
    venueProfile = (
      name: v.name,
      city: v.city,
      courts: v.courts.length,
      rating: venueProfile.rating,
      verified: venueProfile.verified,
      payout: venueProfile.payout,
      joinedAt: venueProfile.joinedAt,
    );
  }

  void _applySlots() {
    final ids = {for (final c in courts) c.id};
    state = [
      for (final s in _raw)
        if (ids.contains(s.courtId)) s,
    ];
  }

  int _courtNumber(String courtId) {
    final index = courts.indexWhere((c) => c.id == courtId);
    return index < 0 ? 0 : index + 1;
  }

  VenueSlot _fromApi(ApiSlot slot) {
    final court = _courtNumber(slot.courtId);
    final status = slot.status == 'BLOCKED'
        ? SlotStatus.closed
        : slot.lobbyId != null
        ? SlotStatus.lobby
        : slot.status == 'BOOKED'
        ? SlotStatus.booked
        : SlotStatus.open;
    return VenueSlot(
      id: slot.id,
      court: court == 0 ? 1 : court,
      start: slot.start,
      end: slot.end,
      price: slot.price,
      status: status,
      guest: slot.lobbyId == null ? null : 'Room aktif',
      courtId: slot.courtId,
      courtName: slot.courtName,
    );
  }

  /// Muat ulang venue + slot 7 hari ke depan. Single-flight: panggilan saat
  /// refresh berjalan berbagi future yang sama supaya tidak request dobel
  /// (layar venue memuat semua tab sekaligus saat shell terbuka).
  Future<String?> refresh() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _doRefresh();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<String?> _doRefresh() async {
    _loading = true;
    try {
      final data = _asMap(await api.get('/venue/venues'));
      final mine = [
        for (final item in _asList(data['items']))
          ApiVenue.fromJson(_asMap(item)),
      ];
      _venues = mine;
      _loaded = true;
      final selected = _venueId;
      _venueId = mine.any((v) => v.id == selected)
          ? selected
          : (mine.isEmpty ? null : mine.first.id);
      _applyProfile();

      final days = <DateTime>[
        for (var i = 0; i < 7; i++) DateTime.now().add(Duration(days: i)),
      ];
      final pages = await Future.wait([for (final day in days) _slotsFor(day)]);
      _raw = [for (final page in pages) ...page];
      _applySlots();
      _lastError = null;
      return null;
    } catch (error) {
      _lastError = apiMessage(error);
      return _lastError;
    } finally {
      _loading = false;
    }
  }

  /// Satu hari gagal tidak membatalkan refresh — layar tetap menampilkan
  /// data hari lain dan bisa dicoba lagi lewat tarik-muat-ulang.
  Future<List<VenueSlot>> _slotsFor(DateTime day) async {
    try {
      final page = _asMap(
        await api.get('/venue/slots', query: {'date': _apiDate(day)}),
      );
      return [
        for (final item in _asList(page['items']))
          _fromApi(ApiSlot.fromJson(_asMap(item))),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Buka slot dari tarif per jam lapangan: `price` = tarif × durasi.
  Future<String?> addRemote({
    required String courtId,
    required DateTime start,
    required Duration duration,
    required int pricePerHour,
  }) async {
    try {
      await api.post(
        '/venue/slots',
        body: {
          'courtId': courtId,
          'startAt': start.toUtc().toIso8601String(),
          'endAt': start.add(duration).toUtc().toIso8601String(),
          'price': pricePerHour * duration.inHours,
        },
      );
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> setStatusRemote(String id, SlotStatus status) async {
    try {
      await api.patch(
        '/venue/slots/$id',
        body: {'status': status == SlotStatus.closed ? 'BLOCKED' : 'OPEN'},
      );
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> setPriceRemote(String id, int price) async {
    try {
      await api.patch('/venue/slots/$id', body: {'price': price});
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Tarif per jam lapangan — sumber harga semua slot baru di lapangan itu.
  /// Slot yang sudah ada menyimpan harganya sendiri.
  Future<String?> setCourtPriceRemote(String courtId, int pricePerHour) async {
    try {
      await api.patch(
        '/venue/courts/$courtId',
        body: {'pricePerHour': pricePerHour},
      );
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> addCourtRemote({
    required String name,
    required Sport sport,
    required int pricePerHour,
    required int capacity,
  }) async {
    final id = _venueId;
    if (id == null) return 'Venue belum dimuat dari server.';
    try {
      await api.post(
        '/venue/courts',
        body: {
          'venueId': id,
          'name': name,
          'sport': sportToApi(sport),
          'pricePerHour': pricePerHour,
          'capacity': capacity,
        },
      );
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Buat venue pertama untuk akun venue yang belum punya venue
  /// (mis. akun lama yang role-nya dinaikkan manual di database).
  Future<String?> createVenueRemote({
    required String name,
    required String address,
    required String city,
  }) async {
    try {
      await api.post(
        '/venue/venues',
        body: {'name': name, 'address': address, 'city': city},
      );
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
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

  // ── Sisi server ────────────────────────────────────────────────────────

  Future<String?> refresh() async {
    try {
      final data = _asMap(await api.get('/lobbies'));
      final items = [
        for (final item in _asList(data['items'])) lobbyFromApi(_asMap(item)),
      ];
      state = items;
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  /// Ambil detail (nama peserta asli) lalu gabungkan ke daftar.
  Future<String?> loadDetail(String id) async {
    try {
      final json = _asMap(await api.get('/lobbies/$id'));
      final lobby = lobbyFromApi(
        json,
        members: [
          for (final item in _asList(json['members']))
            _memberFromApi(_asMap(item)),
        ],
      );
      if (state.any((l) => l.id == id)) {
        state = [for (final l in state) l.id == id ? lobby : l];
      } else {
        state = [...state, lobby]..sort((a, b) => a.start.compareTo(b.start));
      }
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> joinRemote(String id) async {
    try {
      await api.post('/lobbies/$id/join');
      await Future.wait([
        loadDetail(id),
        ref.read(walletProvider.notifier).refresh(),
        ref.read(bookingsProvider.notifier).refresh(),
      ]);
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> leaveRemote(String id) async {
    try {
      final lobby = byId(id);
      if (lobby.isHost) {
        await api.delete('/lobbies/$id');
      } else {
        await api.delete('/lobbies/$id/members/me');
      }
      await Future.wait([
        refresh(),
        ref.read(walletProvider.notifier).refresh(),
        ref.read(bookingsProvider.notifier).refresh(),
      ]);
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> createRemote({
    required String slotId,
    required String title,
    required int quota,
  }) async {
    try {
      await api.post(
        '/lobbies',
        body: {'slotId': slotId, 'title': title, 'quota': quota},
      );
      await Future.wait([
        refresh(),
        ref.read(walletProvider.notifier).refresh(),
      ]);
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }
}

Member _memberFromApi(Map<String, dynamic> json) {
  final role = json['role'] as String?;
  final userId = json['userId'] as String?;
  return Member(
    name: json['fullName'] as String? ?? 'Pemain',
    isHost: role == 'HOST',
    isMe: userId != null && userId == api.userId,
  );
}

Lobby lobbyFromApi(Map<String, dynamic> json, {List<Member>? members}) {
  final joined = _asInt(json['joined']);
  final sport = sportFromApi(_asMap(json['court'])['sport'] as String?);
  final deadline = json['joinDeadline'];
  final venue = _asMap(json['venue']);
  final slot = _asMap(json['slot']);
  return Lobby(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Room',
    sport: sport,
    venue: venue['name'] as String? ?? 'Venue',
    city: venue['city'] as String? ?? '',
    court: _asMap(json['court'])['name'] as String? ?? 'Lapangan',
    start: _asDate(slot['startAt']),
    end: _asDate(slot['endAt']),
    priceTotal: _asInt(json['priceTotal']),
    quota: _asInt(json['quota'], 2),
    deadline: deadline == null ? DateTime.now() : _asDate(deadline),
    members:
        members ??
        [for (var i = 0; i < joined; i++) Member(name: 'Peserta ${i + 1}')],
    status: _lobbyStatusFromApi(json['status'] as String?),
    isHost: json['hostId'] == api.userId,
  );
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

  // ── Sisi server ────────────────────────────────────────────────────────

  Future<String?> refresh() async {
    try {
      final wallet = _asMap(await api.get('/me/wallet'));
      final ledger = _asMap(await api.get('/me/wallet/ledger'));
      state = Wallet(
        balance: _asInt(wallet['balance']),
        held: _asInt(wallet['held']),
        entries: [
          for (final item in _asList(ledger['items']))
            _entryFromApi(_asMap(item)),
        ],
      );
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }

  Future<String?> topUpRemote(int amount) async {
    try {
      final key = 'app-${DateTime.now().microsecondsSinceEpoch}';
      await api.topup(amount, key);
      await refresh();
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }
}

WalletEntry _entryFromApi(Map<String, dynamic> json) {
  final type = json['type'] as String? ?? 'MUTASI';
  return WalletEntry(
    type: type,
    amount: _asInt(json['amount']),
    label: switch (type) {
      'TOPUP' => 'Top up saldo',
      'CAPTURE' => 'Pembayaran booking',
      'HOLD' => 'Dana dikunci',
      'RELEASE' => 'Dana dilepas',
      'PENALTY' => 'Denda',
      _ => 'Mutasi',
    },
    at: _asDate(json['createdAt']),
  );
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

  Future<String?> refresh() async {
    try {
      final data = _asMap(await api.get('/me/bookings'));
      state = [
        for (final item in _asList(data['items']))
          _bookingFromApi(_asMap(item)),
      ];
      return null;
    } catch (error) {
      return apiMessage(error);
    }
  }
}

Booking _bookingFromApi(Map<String, dynamic> json) {
  final slot = _asMap(json['slot']);
  final court = _asMap(json['court']);
  final venue = _asMap(json['venue']);
  final lobby = _asMap(json['lobby']);
  final code = json['bookingCode'] as String? ?? '';
  return Booking(
    id: json['id'] as String? ?? '',
    code: code,
    title: lobby['title'] as String? ?? 'Booking',
    venue: venue['name'] as String? ?? 'Venue',
    court: court['name'] as String? ?? 'Lapangan',
    city: venue['city'] as String? ?? '',
    start: _asDate(slot['startAt']),
    end: _asDate(slot['endAt']),
    sport: sportFromApi(court['sport'] as String?),
    amount: _asInt(json['amountPaid']),
    // Backend v1 belum menerbitkan token QR; kode booking dipakai sebagai
    // isi QR. Scan validasi tetap di sisi venue (v2).
    token: code,
  );
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
