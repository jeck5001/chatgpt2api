import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/app/image_studio_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts at onboarding screen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ImageStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('连接你的工作室'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('http://192.168.5.35:3030'), findsOneWidget);
  });
}
