import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/user_data_models.dart';

void main() {
  group('UserDataModels Serialization Tests', () {
    test('BibleHighlight roundtrip serialization', () {
      final highlight = BibleHighlight(
        id: 10,
        book: 43, // John
        chapter: 3,
        verse: 16,
        colorHex: '#FFC857',
      );

      final map = highlight.toMap();
      expect(map['id'], equals(10));
      expect(map['book'], equals(43));
      expect(map['chapter'], equals(3));
      expect(map['verse'], equals(16));
      expect(map['color_hex'], equals('#FFC857'));

      final restored = BibleHighlight.fromMap(map);
      expect(restored.id, equals(highlight.id));
      expect(restored.book, equals(highlight.book));
      expect(restored.chapter, equals(highlight.chapter));
      expect(restored.verse, equals(highlight.verse));
      expect(restored.colorHex, equals(highlight.colorHex));
    });

    test('BibleBookmark roundtrip serialization', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final bookmark = BibleBookmark(
        id: 42,
        book: 19, // Psalms
        chapter: 23,
        verse: 1,
        title: 'The Lord is my shepherd',
        createdAt: now,
      );

      final map = bookmark.toMap();
      expect(map['id'], equals(42));
      expect(map['title'], equals('The Lord is my shepherd'));

      final restored = BibleBookmark.fromMap(map);
      expect(restored.id, equals(bookmark.id));
      expect(restored.title, equals(bookmark.title));
      expect(restored.createdAt, equals(bookmark.createdAt));
    });

    test('BibleNote roundtrip serialization', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final note = BibleNote(
        id: 7,
        book: 45, // Romans
        chapter: 8,
        verse: 28,
        content: 'All things work together for good.',
        createdAt: now,
        updatedAt: now + 5000,
      );

      final map = note.toMap();
      expect(map['content'], contains('All things work together'));

      final restored = BibleNote.fromMap(map);
      expect(restored.id, equals(note.id));
      expect(restored.content, equals(note.content));
      expect(restored.updatedAt, equals(note.updatedAt));
    });

    test('BibleTag roundtrip serialization', () {
      final tag = BibleTag(
        id: 3,
        book: 43,
        chapter: 14,
        verse: 6,
        tag: 'Faith & Courage',
      );

      final map = tag.toMap();
      expect(map['id'], equals(3));
      expect(map['book'], equals(43));
      expect(map['chapter'], equals(14));
      expect(map['verse'], equals(6));
      expect(map['tag'], equals('Faith & Courage'));

      final restored = BibleTag.fromMap(map);
      expect(restored.id, equals(tag.id));
      expect(restored.book, equals(tag.book));
      expect(restored.chapter, equals(tag.chapter));
      expect(restored.verse, equals(tag.verse));
      expect(restored.tag, equals(tag.tag));
    });
  });
}
