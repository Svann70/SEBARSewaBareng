import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/data/state.dart';

/// Tracking POV venue: label pemesan pada slot jadwal.
void main() {
  ApiSlot slot({String? host, int? joined, int? quota, String? lobbyId}) =>
      ApiSlot(
        id: 's',
        courtId: 'c',
        courtName: 'A',
        sport: Sport.badminton,
        start: DateTime(2026, 10, 24, 19),
        end: DateTime(2026, 10, 24, 21),
        price: 200000,
        status: 'LOBBY_FULL',
        lobbyId: lobbyId,
        hostName: host,
        joined: joined,
        quota: quota,
      );

  test('slot terisi tampil host + jumlah pemain', () {
    expect(
      slot(host: 'Raka', joined: 3, quota: 4, lobbyId: 'l').bookingLabel,
      'Raka · 3/4 pemain',
    );
  });

  test('lobby tanpa host name tetap ditandai terisi', () {
    expect(slot(lobbyId: 'l').bookingLabel, 'Room aktif');
  });

  test('slot kosong tidak punya label', () {
    expect(slot().bookingLabel, isNull);
  });
}
