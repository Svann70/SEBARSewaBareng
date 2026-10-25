import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/data/state.dart';

void main() {
  test('room privat tidak muncul di daftar publik', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ids = container.read(filteredLobbiesProvider).map((l) => l.id);
    expect(ids.contains('lb3'), isFalse, reason: 'lb3 = via link');
    expect(ids.contains('lb2'), isTrue, reason: 'lb2 = publik + sandi');
  });

  test('join pakai sandi salah ditolak, sandi benar lolos', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(lobbiesProvider.notifier);

    expect(notifier.join('lb2', secret: 'salah'), 'Sandi room salah.');
    expect(notifier.join('lb2', secret: 'futsal123'), isNull);
    expect(notifier.byId('lb2').joinedByMe, isTrue);
  });

  test('kode undangan hanya cocok untuk room link', () {
    final all = ProviderContainer().read(lobbiesProvider);
    expect(lobbyByInviteCode(all, 'voli-sore')?.id, 'lb3');
    expect(lobbyByInviteCode(all, 'futsal123'), isNull);
  });

  test('akun venue punya beranda sendiri, bukan /home', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authProvider), isNull);
    container.read(authProvider.notifier).login(AccountRole.venue);
    expect(container.read(authProvider), AccountRole.venue);
    expect(AccountRole.venue.home, '/venue');
    expect(AccountRole.player.home, '/home');
    container.read(authProvider.notifier).logout();
    expect(container.read(authProvider), isNull);
  });

  test('slot disaring per tanggal WIB, apa pun zona waktu HP', () {
    // 23:30 WIB Senin = 16:30 UTC Senin; 00:30 WIB Selasa = 17:30 UTC Senin.
    VenueSlot at(String utc) => VenueSlot(
      id: utc,
      court: 1,
      start: DateTime.parse(utc),
      end: DateTime.parse(utc).add(const Duration(hours: 1)),
      price: 100000,
    );
    final all = [at('2026-10-26T16:30:00Z'), at('2026-10-26T17:30:00Z')];
    expect(slotsOn(all, DateTime(2026, 10, 26)).map((s) => s.id), [
      '2026-10-26T16:30:00Z',
    ]);
    expect(slotsOn(all, DateTime(2026, 10, 27)).map((s) => s.id), [
      '2026-10-26T17:30:00Z',
    ]);
  });
  test('jam tampil dalam WIB, apa pun zona waktu HP', () {
    final start = DateTime.utc(2026, 10, 26, 12); // 19:00 WIB
    expect(wib(start).hour, 19);
    expect(
      dayOnly(wib(DateTime.utc(2026, 10, 26, 18))),
      DateTime(2026, 10, 27),
    );
  });
}
