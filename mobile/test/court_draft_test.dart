import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/data/state.dart';

void main() {
  CourtDraft valid() => CourtDraft(
    name: 'Serbaguna A',
    sports: {Sport.futsal: 10, Sport.basketball: 10, Sport.tennis: 4},
    weekdayPrice: 100000,
    weekendPrice: 150000,
    openHour: 6,
    closeHour: 22,
  );

  test('form lapangan lengkap lolos dan dikirim sesuai API', () {
    final d = valid();
    expect(d.validate(), isNull);
    final json = d.toJson();
    expect(json['openTime'], '06:00');
    expect(json['closeTime'], '22:00');
    expect(json['priceWeekend'], 150000);
    expect((json['sports'] as List).first, {
      'sport': 'FUTSAL',
      'capacity': 10,
    }, reason: 'olahraga pertama = olahraga utama');
  });

  test('isian salah ditolak sebelum dikirim', () {
    expect((valid()..sports.clear()).validate(), contains('olahraga'));
    expect((valid()..sports[Sport.tennis] = 1).validate(), contains('Tenis'));
    expect((valid()..weekdayPrice = 500).validate(), contains('Senin'));
    expect((valid()..weekendPrice = 500).validate(), contains('Sabtu'));
    expect(
      (valid()
            ..openHour = 22
            ..closeHour = 22)
          .validate(),
      contains('Jam tutup'),
    );
    expect((valid()..name = 'A').validate(), contains('Nama'));
  });

  test('harga weekend kosong = sama dengan weekday', () {
    final d = valid()..weekendPrice = null;
    expect(d.validate(), isNull);
    expect(d.toJson()['priceWeekend'], isNull);
  });

  test('lapangan dari API terbaca lengkap untuk diedit', () {
    final court = ApiCourt.fromJson({
      'id': 'c1',
      'name': 'Serbaguna',
      'sport': 'FUTSAL',
      'capacity': 10,
      'pricePerHour': 100000,
      'priceWeekend': null,
      'openTime': '08:00',
      'closeTime': '24:00',
      'status': 'MAINTENANCE',
      'sports': [
        {'sport': 'FUTSAL', 'capacity': 10},
        {'sport': 'PADEL', 'capacity': 4},
      ],
    });
    final d = CourtDraft.from(court);
    expect(d.active, isFalse);
    expect(d.openHour, 8);
    expect(d.closeHour, 24);
    expect(d.sports, {Sport.futsal: 10, Sport.padel: 4});
    expect(d.weekendPrice, isNull);
  });
}
