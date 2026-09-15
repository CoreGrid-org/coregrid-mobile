import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coregrid_mobile/app/app.dart';

void main() {
  testWidgets('first launch shows onboarding, not sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: CoreGridApp()));
    await tester.pumpAndSettle();

    expect(find.text('Scan & Identify'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsNothing);
  });

  testWidgets('skipping onboarding marks it seen and reaches sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: CoreGridApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.text('CoreGrid'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('boots straight to sign-in once onboarding has been seen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await tester.pumpWidget(const ProviderScope(child: CoreGridApp()));
    await tester.pumpAndSettle();

    expect(find.text('CoreGrid'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });
}
