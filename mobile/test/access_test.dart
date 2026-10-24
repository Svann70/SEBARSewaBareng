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

  test('slot bentrok ditolak 409, slot bebas diterima', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final slots = container.read(venueSlotsProvider.notifier);
    final day = DateTime.now();
    DateTime at(int h) => DateTime(day.year, day.month, day.day, h);

    // Tanpa seed: isi state lewat add() dengan slot Lapangan 1, 08:00-10:00.
    expect(
      slots.add(court: 1, start: at(8), end: at(10), price: 200000),
      isNull,
    );
    expect(
      slots.add(court: 1, start: at(9), end: at(11), price: 200000),
      'Slot bentrok dengan jadwal lain.',
    );
    // Bersebelahan (06:00-08:00) tidak dianggap bentrok.
    expect(
      slots.add(court: 1, start: at(6), end: at(8), price: 200000),
      isNull,
    );
    expect(
      container.read(venueSlotsProvider).where((s) => s.court == 1).length,
      2,
    );
  });

  test('slot hari lain disaring per tanggal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final slots = container.read(venueSlotsProvider.notifier);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    DateTime at(DateTime d, int h) => DateTime(d.year, d.month, d.day, h);

    slots.add(court: 1, start: at(today, 9), end: at(today, 10), price: 100000);
    slots.add(
      court: 2,
      start: at(tomorrow, 19),
      end: at(tomorrow, 21),
      price: 250000,
    );

    final all = container.read(venueSlotsProvider);
    final todayList = slotsOn(all, today);
    expect(todayList.length, 1);
    expect(todayList.every((s) => s.start.day == today.day), isTrue);
    expect(slotsOn(all, tomorrow).length, 1);
  });
}
