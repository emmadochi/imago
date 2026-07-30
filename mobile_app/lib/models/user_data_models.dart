// lib/models/user_data_models.dart

class BibleHighlight {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String colorHex;

  BibleHighlight({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.colorHex,
  });

  factory BibleHighlight.fromMap(Map<String, dynamic> map) {
    return BibleHighlight(
      id: map['id'] as int? ?? 0,
      book: map['book'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      colorHex: map['color_hex'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'color_hex': colorHex,
    };
  }
}

class BibleBookmark {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String title;
  final int createdAt;

  BibleBookmark({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.title,
    required this.createdAt,
  });

  factory BibleBookmark.fromMap(Map<String, dynamic> map) {
    return BibleBookmark(
      id: map['id'] as int? ?? 0,
      book: map['book'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      title: map['title'] as String,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'title': title,
      'created_at': createdAt,
    };
  }
}

class BibleNote {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String content;
  final int createdAt;
  final int updatedAt;

  BibleNote({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BibleNote.fromMap(Map<String, dynamic> map) {
    return BibleNote(
      id: map['id'] as int? ?? 0,
      book: map['book'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      content: map['content'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'content': content,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class BibleTag {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String tag;

  BibleTag({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.tag,
  });

  factory BibleTag.fromMap(Map<String, dynamic> map) {
    return BibleTag(
      id: map['id'] as int? ?? 0,
      book: map['book'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      tag: map['tag'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'tag': tag,
    };
  }
}


class JournalEntry {
  final int? id;
  final String title;
  final String content; // JSON string from flutter_quill
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: (map['tags'] as String).isEmpty ? [] : (map['tags'] as String).split(','),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
