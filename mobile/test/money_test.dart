import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/money.dart';

void main() {
  test('split bill membulatkan ke atas (T-01)', () {
    expect(pricePerPerson(400000, 8), 50000);
    expect(pricePerPerson(350000, 3), 116667);
    expect(roundingSurplus(350000, 3), 1);
    expect(roundingSurplus(400000, 8), 0);
  });

  test('kebijakan penalti: denda 15% di bawah 6 jam (T-02)', () {
    final far = penaltyFor(untilStart: const Duration(hours: 48));
    expect(far.refundPct, 100);
    expect(far.penaltyPct, 0);

    final soon = penaltyFor(untilStart: const Duration(hours: 3));
    expect(soon.refundPct, 85);
    expect(soon.penaltyPct, 15);

    final ghost = penaltyFor(
      untilStart: const Duration(hours: 1),
      noShow: true,
    );
    expect(ghost.refundPct, 0);
    expect(ghost.penaltyPct, 100);
  });

  test('rupiah pakai titik ribuan', () {
    expect(rupiah(50000), 'Rp50.000');
    expect(rupiah(18450000), 'Rp18.450.000');
  });
}
