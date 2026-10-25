// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carecircle_mobile/screens/home_screen.dart';

void main() {
  testWidgets('CareCircle landing screen shows role choices', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loginBuilder: (_) => const SizedBox()),
      ),
    );

    expect(find.text('CareCircle'), findsOneWidget);
    expect(find.text('Choose your view'), findsOneWidget);
    expect(find.text('Elder'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Caregiver'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
