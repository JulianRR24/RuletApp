// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ruleta_aleatoria/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RuletaApp());

    // Verify core UI elements for the Ruleta app exist.
    expect(find.text('Ruleta de Juegos'), findsOneWidget); // AppBar title
    expect(find.text('Girar Ruleta'), findsOneWidget); // Main action button
    expect(find.text('Juegos'), findsOneWidget); // List management button
  });
}
