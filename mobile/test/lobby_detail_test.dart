import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/features/lobby/lobby_detail_screen.dart';

void main() {
  testWidgets('detail lobby render tanpa exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const LobbyDetailScreen(id: 'lb1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Badminton Sabtu Pagi'), findsWidgets);
  });
}
