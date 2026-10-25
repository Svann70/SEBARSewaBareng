import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/data/state.dart';
import 'package:sebar/features/create/create_lobby_screen.dart';

class _FakeVenues extends VenuesNotifier {
  @override
  List<ApiVenue> build() => const [
    ApiVenue(
      id: 'v1',
      name: 'GOR Uji',
      city: 'Bandung',
      courts: [
        ApiCourt(
          id: 'c1',
          name: 'Lapangan Uji',
          sport: Sport.badminton,
          pricePerHour: 100000,
          capacity: 4,
        ),
      ],
    ),
  ];

  @override
  Future<String?> refresh() async => null;
}

void main() {
  testWidgets('back sistem mundur satu langkah, tidak menutup halaman', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [venuesProvider.overrideWith(_FakeVenues.new)],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: Text('beranda')),
          routes: {'/create': (_) => const CreateLobbyScreen()},
        ),
      ),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/create');
    await tester.pumpAndSettle();

    // Langkah 1 -> 2: kartu lapangan tampil.
    await tester.tap(find.text('GOR Uji'));
    await tester.pumpAndSettle();
    expect(find.text('Lapangan Uji'), findsOneWidget);
    expect(find.textContaining('langkah 2 dari 4'), findsOneWidget);

    // Back sistem (Android) kembali ke langkah 1, halaman tetap terbuka.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pilih venue'), findsOneWidget);

    // Di langkah 1, back menutup halaman.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('beranda'), findsOneWidget);
    expect(find.byType(CreateLobbyScreen), findsNothing);
  });
}
