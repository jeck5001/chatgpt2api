import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/components/press_scale.dart';

void main() {
  testWidgets('press dims the scale and release restores it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressScale(
              scale: 0.9,
              duration: const Duration(milliseconds: 50),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );

    AnimatedScale animatedScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));

    expect(animatedScale().scale, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();

    expect(animatedScale().scale, 0.9);

    await gesture.up();
    await tester.pump();

    expect(animatedScale().scale, 1.0);
  });

  testWidgets('cancelled pointer restores the resting scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressScale(
            scale: 0.8,
            child: Container(
              width: 100,
              height: 100,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.8,
    );

    await gesture.cancel();
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
  });
}
