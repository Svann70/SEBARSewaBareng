import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/money.dart';

void main() {
  test('split bill membulatkan ke atas (T-01)', () {
    expect(pricePerPerson(400000, 8), 50000);
    expect(pricePerPerson(350000, 3), 116667);
    expect(roundingSurplus(350000, 3), 1);
    expect(roundingSurplus(400000, 8), 0);
  });

  test('kebijakan penalti tiga zona (T-02)', () {
    final far = penaltyFor(untilStart: const Duration(hours: 48));
    expect(far.refundPct, 100);
    expect(far.scoreDelta, 0);

    final soon = penaltyFor(untilStart: const Duration(hours: 3));
    expect(soon.refundPct, 50);
    expect(soon.penaltyPct, 50);
    expect(soon.scoreDelta, -10);

    final ghost = penaltyFor(
      untilStart: const Duration(hours: 1),
      noShow: true,
    );
    expect(ghost.refundPct, 0);
    expect(ghost.scoreDelta, -25);
  });

  test('rupiah pakai titik ribuan', () {
    expect(rupiah(50000), 'Rp50.000');
    expect(rupiah(18450000), 'Rp18.450.000');
  });
}
