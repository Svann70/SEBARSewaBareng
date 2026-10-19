/// Aturan uang SEBAR — cermin dari server (BR-1.1, BR-2.x, §5.6).
/// Klien hanya menampilkan; nilai final tetap dari API.
library;

/// CEIL(price_total / quota), sama dengan generated column di database.
int pricePerPerson(int priceTotal, int quota) =>
    (priceTotal + quota - 1) ~/ quota;

/// Sisa pembulatan yang diteruskan ke venue (BR-1.2).
int roundingSurplus(int priceTotal, int quota) =>
    pricePerPerson(priceTotal, quota) * quota - priceTotal;

class Penalty {
  const Penalty({
    required this.refundPct,
    required this.penaltyPct,
    required this.scoreDelta,
  });

  final int refundPct;
  final int penaltyPct;
  final int scoreDelta;
}

/// Kebijakan pembatalan §5.6. Perbandingan 6 jam dilakukan server;
/// helper ini hanya untuk pratinjau di UI.
Penalty penaltyFor({required Duration untilStart, bool noShow = false}) {
  if (noShow) {
    return const Penalty(refundPct: 0, penaltyPct: 100, scoreDelta: -25);
  }
  if (untilStart >= const Duration(hours: 6)) {
    return const Penalty(refundPct: 100, penaltyPct: 0, scoreDelta: 0);
  }
  return const Penalty(refundPct: 50, penaltyPct: 50, scoreDelta: -10);
}

String rupiah(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}Rp$buffer';
}
