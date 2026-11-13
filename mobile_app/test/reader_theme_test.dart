import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/theme/imago_theme.dart';

void main() {
  group('ReaderTheme System Unit Tests', () {
    test('Midnight (Night) Theme has proper dark attributes', () {
      final theme = ReaderTheme.of(ReaderThemeMode.night);
      expect(theme.mode, equals(ReaderThemeMode.night));
      expect(theme.isDark, isTrue);
      expect(theme.label, equals('Midnight'));
      expect(theme.background.value, equals(const Color(0xFF0B132B).value));
    });

    test('Parchment (Sepia) Theme has warm papyrus attributes', () {
      final theme = ReaderTheme.of(ReaderThemeMode.parchment);
      expect(theme.mode, equals(ReaderThemeMode.parchment));
      expect(theme.isDark, isFalse);
      expect(theme.label, equals('Parchment'));
      expect(theme.primaryText.value, equals(const Color(0xFF2C241D).value));
      expect(theme.verseNumberColor.value, equals(const Color(0xFF9A6B2F).value));
    });

    test('Alabaster (Day) Theme has clean daylight attributes', () {
      final theme = ReaderTheme.of(ReaderThemeMode.day);
      expect(theme.mode, equals(ReaderThemeMode.day));
      expect(theme.isDark, isFalse);
      expect(theme.label, equals('Alabaster'));
      expect(theme.primaryText.toARGB32(), equals(const Color(0xFF0F172A).toARGB32()));
    });

    test('fromString parses alias strings safely', () {
      expect(ReaderTheme.fromString('night').mode, equals(ReaderThemeMode.night));
      expect(ReaderTheme.fromString('dark').mode, equals(ReaderThemeMode.night));
      expect(ReaderTheme.fromString('parchment').mode, equals(ReaderThemeMode.parchment));
      expect(ReaderTheme.fromString('sepia').mode, equals(ReaderThemeMode.parchment));
      expect(ReaderTheme.fromString('day').mode, equals(ReaderThemeMode.day));
      expect(ReaderTheme.fromString('light').mode, equals(ReaderThemeMode.day));
      expect(ReaderTheme.fromString('unknown_value').mode, equals(ReaderThemeMode.night));
      expect(ReaderTheme.fromString(null).mode, equals(ReaderThemeMode.night));
    });
  });
}
