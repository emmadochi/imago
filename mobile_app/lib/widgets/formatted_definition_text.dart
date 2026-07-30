import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/imago_theme.dart';

class FormattedDefinitionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String reference) onVerseTap;

  const FormattedDefinitionText({
    super.key,
    required this.text,
    this.style,
    required this.onVerseTap,
  });

  // Regex pattern matching Bible references like Ex. 6:20, Rev. 9:11, 1 Chr. 12:27, Matt 5:3-10
  static final RegExp _refRegExp = RegExp(
    r'\b(?:Gen|Genesis|Ex|Exod|Exodus|Lev|Leviticus|Num|Numbers|Deut|Deuteronomy|Josh|Joshua|Judg|Judges|Ruth|1\s*Sam|1\s*Samuel|2\s*Sam|2\s*Samuel|1\s*Kings|2\s*Kings|1\s*Chr|1\s*Chron|1\s*Chronicles|2\s*Chr|2\s*Chron|2\s*Chronicles|Ezra|Neh|Nehemiah|Esth|Esther|Job|Ps|Psa|Psalms|Prov|Proverbs|Eccl|Ecclesiastes|Song|Song\s*of\s*Solomon|Isa|Isaiah|Jer|Jeremiah|Lam|Lamentations|Ezek|Ezekiel|Dan|Daniel|Hos|Hosea|Joel|Amos|Obad|Obadiah|Jonah|Mic|Micah|Nah|Nahum|Hab|Habakkuk|Zeph|Zephaniah|Hag|Haggai|Zech|Zechariah|Mal|Malachi|Matt|Matthew|Mark|Luke|John|Acts|Rom|Romans|1\s*Cor|1\s*Corinthians|2\s*Cor|2\s*Corinthians|Gal|Galatians|Eph|Ephesians|Phil|Philippians|Col|Colossians|1\s*Thess|1\s*Thessalonians|2\s*Thess|2\s*Thessalonians|1\s*Tim|1\s*Timothy|2\s*Tim|2\s*Timothy|Titus|Philem|Philemon|Heb|Hebrews|Jas|James|1\s*Pet|1\s*Peter|2\s*Pet|2\s*Peter|1\s*John|2\s*John|3\s*John|Jude|Rev|Revelation)\.?\s*\d+:\d+(?:-\d+)?\b',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ??
        TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white.withOpacity(0.9),
          fontSize: 14.5,
          height: 1.6,
        );

    final linkStyle = defaultStyle.copyWith(
      color: ImagoColors.gold,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: ImagoColors.gold.withOpacity(0.5),
    );

    final matches = _refRegExp.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      final rawRef = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => onVerseTap(rawRef);

      spans.add(TextSpan(
        text: rawRef,
        style: linkStyle,
        recognizer: recognizer,
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  /// Maps short abbreviations like "Ex." or "1 Chr." to canonical book names
  static String normalizeReference(String ref) {
    var cleaned = ref.trim();
    
    // Map of common abbreviations to full names
    final abbrevMap = <String, String>{
      'gen': 'Genesis',
      'ex': 'Exodus',
      'exod': 'Exodus',
      'lev': 'Leviticus',
      'num': 'Numbers',
      'deut': 'Deuteronomy',
      'josh': 'Joshua',
      'judg': 'Judges',
      '1 sam': '1 Samuel',
      '2 sam': '2 Samuel',
      '1 kings': '1 Kings',
      '2 kings': '2 Kings',
      '1 chr': '1 Chronicles',
      '1 chron': '1 Chronicles',
      '2 chr': '2 Chronicles',
      '2 chron': '2 Chronicles',
      'neh': 'Nehemiah',
      'esth': 'Esther',
      'ps': 'Psalms',
      'psa': 'Psalms',
      'prov': 'Proverbs',
      'eccl': 'Ecclesiastes',
      'song': 'Song of Solomon',
      'isa': 'Isaiah',
      'jer': 'Jeremiah',
      'lam': 'Lamentations',
      'ezek': 'Ezekiel',
      'dan': 'Daniel',
      'hos': 'Hosea',
      'obad': 'Obadiah',
      'mic': 'Micah',
      'nah': 'Nahum',
      'hab': 'Habakkuk',
      'zeph': 'Zephaniah',
      'hag': 'Haggai',
      'zech': 'Zechariah',
      'mal': 'Malachi',
      'matt': 'Matthew',
      'rom': 'Romans',
      '1 cor': '1 Corinthians',
      '2 cor': '2 Corinthians',
      'gal': 'Galatians',
      'eph': 'Ephesians',
      'phil': 'Philippians',
      'col': 'Colossians',
      '1 thess': '1 Thessalonians',
      '2 thess': '2 Thessalonians',
      '1 tim': '1 Timothy',
      '2 tim': '2 Timothy',
      'philem': 'Philemon',
      'heb': 'Hebrews',
      'jas': 'James',
      '1 pet': '1 Peter',
      '2 pet': '2 Peter',
      '1 john': '1 John',
      '2 john': '2 John',
      '3 john': '3 John',
      'rev': 'Revelation',
    };

    final match = RegExp(r'^([1-3]?\s*[A-Za-z]+)\.?\s*(\d+:\d+(?:-\d+)?)$').firstMatch(cleaned);
    if (match != null) {
      final bookPart = match.group(1)!.toLowerCase().replaceAll('.', '').trim();
      final numPart = match.group(2)!;
      if (abbrevMap.containsKey(bookPart)) {
        return '${abbrevMap[bookPart]} $numPart';
      }
    }

    return cleaned;
  }
}
