import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/data/state.dart';

void main() {
  final court = ApiCourt(
    id: 'court-1',
    name: 'Lapangan A',
    sport: Sport.badminton,
    pricePerHour: 100000,
    priceWeekend: 120000,
    capacity: 8,
  );

  test('durasi 1 jam sampai 8 jam hitung total tarif dengan benar', () {
    final weekday = DateTime(2026, 10, 23); // Jumat (weekday)
    final weekend = DateTime(2026, 10, 24); // Sabtu (weekend)

    final rateWeekday = court.rateFor(weekday);
    final rateWeekend = court.rateFor(weekend);

    expect(rateWeekday * 1, 100000);
    expect(rateWeekday * 2, 200000);
    expect(rateWeekday * 3, 300000);
    expect(rateWeekday * 4, 400000);
    expect(rateWeekday * 8, 800000);

    expect(rateWeekend * 1, 120000);
    expect(rateWeekend * 2, 240000);
    expect(rateWeekend * 3, 360000);
    expect(rateWeekend * 4, 480000);
    expect(rateWeekend * 8, 960000);
  });
}
