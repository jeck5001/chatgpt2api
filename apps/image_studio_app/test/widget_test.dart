import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/app/image_studio_app.dart';

void main() {
  testWidgets('app starts at onboarding screen', (tester) async {
    await tester.pumpWidget(const ImageStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('Connect Image Studio'), findsOneWidget);
    expect(find.text('Backend URL'), findsOneWidget);
    expect(find.text('http://192.168.5.35:3030'), findsOneWidget);
  });
}
