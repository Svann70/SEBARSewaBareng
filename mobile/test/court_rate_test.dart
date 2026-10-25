import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/data/state.dart';

void main() {
  // T-07 tarif per hari: Sabtu/Minggu memakai priceWeekend, sisanya weekday.
  final court = ApiCourt(
    id: 'c',
    name: 'Lapangan 3',
    sport: Sport.badminton,
    pricePerHour: 160000,
    priceWeekend: 200000,
    capacity: 12,
  );

  test('rateFor pakai harga weekend saat Sabtu/Minggu', () {
    final sabtu = DateTime(2026, 10, 24, 20); // sabtu
    final minggu = DateTime(2026, 10, 25, 8); // minggu
    final jumat = DateTime(2026, 10, 23, 20); // jumat

    expect(court.rateFor(jumat), 160000);
    expect(court.rateFor(sabtu), 200000);
    expect(court.rateFor(minggu), 200000);
  });

  test('rateFor fallback ke weekday bila harga weekend belum diisi', () {
    const plain = ApiCourt(
      id: 'c2',
      name: 'Lapangan 1',
      sport: Sport.badminton,
      pricePerHour: 100000,
      capacity: 8,
    );
    expect(plain.rateFor(DateTime(2026, 10, 24, 20)), 100000);
  });
}
