import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Center in bottomNavigationBar causes full-screen expansion', (tester) async {
    const double screenHeight = 800.0;
    const double screenWidth = 400.0;
    tester.view.physicalSize = const Size(screenWidth, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Problematic version with Center
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(key: Key('body_content'), child: Text('Body Content')),
          bottomNavigationBar: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                height: 60,
                color: Colors.blue,
                child: const Text('Nav Bar'),
              ),
            ),
          ),
        ),
      ),
    );

    final bodyFinder = find.byKey(const Key('body_content'));
    final RenderBox bodyBox = tester.renderObject(bodyFinder);
    debugPrint('Body height with Center: ${bodyBox.size.height}');

    // With Center without heightFactor, bottomNavigationBar expands to 800, so body height becomes 0!
    expect(bodyBox.size.height, equals(0.0));
  });

  testWidgets('Align with heightFactor: 1.0 preserves body height', (tester) async {
    const double screenHeight = 800.0;
    const double screenWidth = 400.0;
    tester.view.physicalSize = const Size(screenWidth, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Fixed version with Align(heightFactor: 1.0)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const Center(key: Key('body_content_fixed'), child: Text('Body Content')),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  height: 60,
                  color: Colors.blue,
                  child: const Text('Nav Bar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final bodyFinder = find.byKey(const Key('body_content_fixed'));
    final RenderBox bodyBox = tester.renderObject(bodyFinder);
    debugPrint('Body height with Align(heightFactor: 1.0): ${bodyBox.size.height}');

    expect(bodyBox.size.height, equals(800.0));
    expect(find.text('Body Content'), findsOneWidget);
    expect(find.text('Nav Bar'), findsOneWidget);
  });
}
