import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sebar/app.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SebarApp()));
    await tester.pumpAndSettle();
    expect(find.text('SEBAR'), findsOneWidget);
  });
}
