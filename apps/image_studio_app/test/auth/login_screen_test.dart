import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/auth/login_screen.dart';

void main() {
  testWidgets('shows login errors without leaving the form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          baseUrl: Uri.parse('http://192.168.1.20:8000'),
          onLogin: (_) async => throw Exception('Cannot reach backend'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sk-test');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Cannot reach backend'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
