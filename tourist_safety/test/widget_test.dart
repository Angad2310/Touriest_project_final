// This file is intentionally minimal — widget tests are in test/modules/
// The default Flutter scaffold test is replaced by our module-specific tests.
//
// Run: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourist_safety/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TouristSafetyApp()),
    );
    // App should render the home screen
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
