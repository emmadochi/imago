import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/theme/imago_theme.dart';
import 'package:imago/widgets/typography_sheet.dart';
import 'package:imago/widgets/color_picker_sheet.dart';
import 'package:imago/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Imago UI Components Widget Tests', () {
    testWidgets('CosmicBackground renders with children inside MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmicBackground(
              children: [
                Text('Test Celestial Content', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Test Celestial Content'), findsOneWidget);
      expect(find.byType(CosmicBackground), findsOneWidget);
    });

    testWidgets('CosmicOrb renders correctly with specific dimensions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmicOrb(
              size: 150,
              color: Color(0xFF3D5AFE),
              opacity: 0.1,
            ),
          ),
        ),
      );

      expect(find.byType(CosmicOrb), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(CosmicOrb),
        matching: find.byType(Container),
      ));
      expect(container.constraints?.maxWidth ?? 150.0, equals(150.0));
    });

    testWidgets('ImagoLogoPainter paints without throwing exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: const ImagoLogoPainter(glowPulse: 0.8),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('TypographySettingsSheet displays reading theme options', (WidgetTester tester) async {
      ReaderThemeMode selectedTheme = ReaderThemeMode.night;
      String selectedFont = 'Poppins';
      double selectedSize = 16.0;
      double selectedHeight = 1.6;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypographySettingsSheet(
              currentReaderTheme: selectedTheme,
              currentFontFamily: selectedFont,
              currentFontSize: selectedSize,
              currentLineHeight: selectedHeight,
              onReaderThemeChanged: (mode) => selectedTheme = mode,
              onFontFamilyChanged: (font) => selectedFont = font,
              onFontSizeChanged: (size) => selectedSize = size,
              onLineHeightChanged: (height) => selectedHeight = height,
            ),
          ),
        ),
      );

      expect(find.text('Reading Display'), findsOneWidget);
      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('Parchment'), findsOneWidget);
      expect(find.text('Alabaster'), findsOneWidget);
      expect(find.text('FONT FAMILY'), findsOneWidget);
      expect(find.text('FONT SIZE'), findsOneWidget);

      // Tap on Parchment mode
      await tester.tap(find.text('Parchment'));
      expect(selectedTheme, equals(ReaderThemeMode.parchment));
    });

    testWidgets('ColorPickerSheet displays palette options', (WidgetTester tester) async {
      String pickedColor = '';
      bool removed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerSheet(
              onColorSelected: (hex) => pickedColor = hex,
              onRemoveHighlight: () => removed = true,
            ),
          ),
        ),
      );

      expect(find.text('Highlight Verse'), findsOneWidget);
      expect(find.byType(ColorPickerSheet), findsOneWidget);
      expect(pickedColor, isEmpty);
      expect(removed, isFalse);
    });

    testWidgets('OnboardingScreen renders lighting mode step and switches themes', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      readerThemeNotifier.value = ReaderThemeMode.night;

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Discover the\nGod in You'), findsOneWidget);

      // Tap Continue 3 times to reach the lighting mode selection page
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your\nAtmosphere'), findsOneWidget);
      expect(find.text('Parchment'), findsOneWidget);
      expect(find.text('Alabaster'), findsOneWidget);

      // Select Parchment mode
      await tester.tap(find.text('Parchment'));
      await tester.pumpAndSettle();
      expect(readerThemeNotifier.value, equals(ReaderThemeMode.parchment));

      // Select Alabaster mode
      await tester.ensureVisible(find.text('Alabaster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alabaster'));
      await tester.pumpAndSettle();
      expect(readerThemeNotifier.value, equals(ReaderThemeMode.day));

      // Reset back to midnight for other tests
      readerThemeNotifier.value = ReaderThemeMode.night;
    });
  });
}
