import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coregrid_mobile/app/app.dart';
import 'package:coregrid_mobile/shared/connectivity/connectivity_provider.dart';

void main() {
  late StreamController<bool> connectivity;

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    connectivity = StreamController<bool>();
  });

  tearDown(() => connectivity.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => connectivity.stream),
        ],
        child: const CoreGridApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the offline banner, then "Back online", then hides', (
    tester,
  ) async {
    await pumpApp(tester);
    connectivity.add(true);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsNothing);

    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);

    connectivity.add(true);
    await tester.pump(); // deliver the stream event
    await tester.pump(); // rebuild with the new mode
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('Back online'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Back online'), findsNothing);
  });

  testWidgets('starting online shows no banner at all', (tester) async {
    await pumpApp(tester);
    connectivity.add(true);
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('Back online'), findsNothing);
  });

  testWidgets('signing in while offline explains why, on every tap', (
    tester,
  ) async {
    await pumpApp(tester);
    connectivity.add(false);
    await tester.pumpAndSettle();

    final signIn = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signIn);
    await tester.pump();
    expect(find.textContaining('You\'re offline'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(signIn)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pump();
    expect(find.textContaining('You\'re offline'), findsOneWidget);
  });
}
