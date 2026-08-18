import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coregrid_mobile/app/app.dart';

void main() {
  testWidgets('app boots to the sign-in screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CoreGridApp()));
    await tester.pumpAndSettle();

    expect(find.text('CoreGrid'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });
}
