import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/features/venue/venue_shell.dart';
import 'package:sebar/features/venue/venue_tabs.dart';

/// Smoke tab Jadwal venue: buka tab dari dock, pastikan tidak ada
/// exception/overflow pada 360x740.
void main() {
  testWidgets('jadwal tab render 360x740', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildTheme(), home: const VenueShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Buka slot'), findsOneWidget);

    await tester.tap(find.text('Jadwal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tambah'), findsOneWidget);
  });

  testWidgets('jadwal tab standalone 360x740', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: VenueScheduleTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
