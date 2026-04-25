// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tng_clone_flutter/main.dart';

void main() {
  testWidgets('App renders splash then onboarding',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TngOfflineWalletApp()));

    expect(find.text('Initializing offline wallet'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Offline Wallet Setup'), findsOneWidget);
    expect(find.text('Continue to Home'), findsOneWidget);
  });

  testWidgets('Home screen shows connectivity controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TngOfflineWalletApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Wallet Home'), findsOneWidget);
    expect(find.text('Latest cached balance'), findsOneWidget);
    expect(find.text('Get latest balance'), findsOneWidget);
    expect(find.text('Pay Offline'), findsOneWidget);
    expect(find.text('Receive Offline'), findsOneWidget);
  });

  testWidgets('Pay screen blocks amounts above safe offline balance',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TngOfflineWalletApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Pay Offline'), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-amount-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pay-amount-field')),
      '120.01',
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('exceeds your safe offline balance'),
      findsOneWidget,
    );

    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Hold near receiver'),
    );
    expect(disabledButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('pay-amount-field')),
      '8.50',
    );
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Hold near receiver'),
    );
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('Receive screen adds a pending receipt when simulated',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TngOfflineWalletApp()));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Receive Offline'), findsOneWidget);
    expect(find.text('Simulate incoming tap'), findsOneWidget);

    await tester.tap(find.text('Simulate incoming tap'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pendingSettlement'), findsOneWidget);
    expect(find.textContaining('RM 8.50'), findsOneWidget);
  });
}
