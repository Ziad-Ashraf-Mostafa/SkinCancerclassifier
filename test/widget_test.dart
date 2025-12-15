// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:skin_cancer_detector/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SkinCancerDetectorApp());

    // Verify that the app starts up
    expect(find.text('Skin Scanner'), findsOneWidget);
  });
}
