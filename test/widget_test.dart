// test/widget_test.dart
//
// Widget test for PebloApp.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peblo_story_buddy/main.dart';

void main() {
  testWidgets('PebloApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame inside ProviderScope.
    await tester.pumpWidget(
      const ProviderScope(
        child: PebloApp(),
      ),
    );

    // Verify that PebloApp compiles and mounts successfully.
    expect(find.byType(PebloApp), findsOneWidget);
  });
}
