import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/features/venue/venue_tabs.dart';

/// Diagnostik: render tab Jadwal 360x740 dan cetak chain widget penyebab
/// exception (terutama overflow RenderFlex).
void main() {
  testWidgets('jadwal standalone 360x740', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('DETAIL-SUMMARY: ${details.summary.toString(depth: 100)}');
      debugPrint('DETAIL-FULL:\n${details.toString(includeProperties: true)}');
      prev?.call(FlutterErrorDetails(
        exception: details.exception,
        stack: details.stack,
        context: ErrorDescription('(diplester untuk test)'),
      ));
    };

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: VenueScheduleTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = prev;
  });
}
