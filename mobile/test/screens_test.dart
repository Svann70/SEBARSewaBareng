import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/features/booking/ticket_screen.dart';
import 'package:sebar/features/booking/tickets_screen.dart';
import 'package:sebar/features/community/community_screen.dart';
import 'package:sebar/features/create/create_lobby_screen.dart';
import 'package:sebar/features/home/home_screen.dart';
import 'package:sebar/features/profile/profile_screen.dart';
import 'package:sebar/features/venue/venue_shell.dart';
import 'package:sebar/features/wallet/wallet_screen.dart';

/// Smoke test semua layar utama: tidak ada exception/overflow pada
/// ukuran ponsel kecil (360x740) — target aksesibilitas §7.4.
void main() {
  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'tickets': const TicketsScreen(),
    'wallet': const WalletScreen(),
    'profile': const ProfileScreen(),
    'ticket': const TicketScreen(id: 'bk1'),
    'create': const CreateLobbyScreen(),
    'community': const CommunityScreen(),
    'venue': const VenueShell(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} render 360x740', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: buildTheme(), home: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
