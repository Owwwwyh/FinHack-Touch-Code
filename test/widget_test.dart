import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tng_finhack_wallet/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TngWalletApp()));
    await tester.pumpAndSettle();
    expect(find.text('eWallet Balance'), findsOneWidget);
  });
}
