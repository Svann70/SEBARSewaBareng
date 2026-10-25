import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/core/theme.dart';
import 'package:sebar/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('tarik dana flow test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: WalletScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Tarik dana" button
    final tarikDanaBtn = find.text('Tarik dana');
    expect(tarikDanaBtn, findsOneWidget);
    await tester.tap(tarikDanaBtn);
    await tester.pumpAndSettle();

    // The modal bottom sheet should appear with "Lanjutkan"
    final lanjutkanBtn = find.text('Lanjutkan');
    expect(lanjutkanBtn, findsOneWidget);

    // Tap "Lanjutkan" without entering anything
    await tester.tap(lanjutkanBtn);
    await tester.pumpAndSettle();

    // Enter valid details
    await tester.enterText(
      find.widgetWithText(TextField, 'Nominal yang diterima'),
      '50000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nomor rekening'),
      '12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama pemilik rekening'),
      'Budi Santoso',
    );
    await tester.pumpAndSettle();

    await tester.tap(lanjutkanBtn);
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi penarikan'), findsOneWidget);

    // Tap "Tarik dana" in confirmation dialog
    final confirmBtn = find.widgetWithText(FilledButton, 'Tarik dana');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify confirmation closed and success snackbar shown
    expect(find.text('Konfirmasi penarikan'), findsNothing);
    expect(find.textContaining('berhasil diajukan'), findsOneWidget);
  });
}
