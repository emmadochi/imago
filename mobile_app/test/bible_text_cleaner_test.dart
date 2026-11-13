import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/bible_models.dart';

void main() {
  group('BibleVerse.cleanText Unit Tests', () {
    test('Image 1 - MSG Translation clean up', () {
      const rawMsg1 = "A David psalm<br/>I've already run for dear life<br/>straight to the arms of God.<br/>So why would I run away now<br/ >when you say,<br/>\"Run to the mountains;";
      final cleaned1 = BibleVerse.cleanText(rawMsg1);

      expect(cleaned1, contains("A David psalm"));
      expect(cleaned1, contains("I've already run for dear life"));
      expect(cleaned1, contains("straight to the arms of God."));
      expect(cleaned1, isNot(contains('<br/>')));
      expect(cleaned1, isNot(contains('<br/ >')));
      expect(cleaned1, isNot(contains('<br>')));
      expect(cleaned1, isNot(contains('<')));

      const rawMsg2 = "the evil<br/>bows are bent, the wicked arrows<br/ >Aimed to shoot under cover of darkness<br/>at every heart open to God.";
      final cleaned2 = BibleVerse.cleanText(rawMsg2);
      expect(cleaned2, isNot(contains('<br/>')));
      expect(cleaned2, isNot(contains('<br/ >')));
      expect(cleaned2, contains("the evil\nbows are bent, the wicked arrows\nAimed to shoot under cover of darkness\nat every heart open to God."));
    });

    test('Image 2 - ASV Translation clean up', () {
      const rawAsv1 = "<PI1><FO>For the Chief Musician. <FI>A Psalm<Fi> of David.<Fo><CI><PI1>In Jehovah do I take refuge: How say ye to my soul,<CI><PI1>Flee <RF>Or, <i>ye birds</i><Rf><FI>as<Fi> a bird to your mountain;<CI>";
      final cleaned1 = BibleVerse.cleanText(rawAsv1);

      expect(cleaned1, isNot(contains('<PI1>')));
      expect(cleaned1, isNot(contains('<FO>')));
      expect(cleaned1, isNot(contains('<FI>')));
      expect(cleaned1, isNot(contains('<CI>')));
      expect(cleaned1, isNot(contains('<RF>')));
      expect(cleaned1, isNot(contains('<Rf>')));
      expect(cleaned1, isNot(contains('Or, ye birds'))); // Margin note stripped
      expect(cleaned1, contains("For the Chief Musician. A Psalm of David."));
      expect(cleaned1, contains("In Jehovah do I take refuge: How say ye to my soul,"));
      expect(cleaned1, contains("Flee as a bird to your mountain;"));

      const rawAsv2 = "<PI1>For, lo, the wicked bend the bow,<CI><PI1>They make ready their arrow upon the string,<CI><PI1>That they may shoot in darkness at the upright in heart;<CI>";
      final cleaned2 = BibleVerse.cleanText(rawAsv2);
      expect(cleaned2, isNot(contains('<')));
      expect(cleaned2, contains("For, lo, the wicked bend the bow,\nThey make ready their arrow upon the string,\nThat they may shoot in darkness at the upright in heart;"));

      const rawAsv3 = "<PI1><RF>Or, <i>For the foundations are destroyed; What hath the righteous wrought?</i><Rf>If the foundations be destroyed,<CI><PI1>What can the righteous do?<CI>";
      final cleaned3 = BibleVerse.cleanText(rawAsv3);
      expect(cleaned3, isNot(contains('wrought?')));
      expect(cleaned3, equals("If the foundations be destroyed,\nWhat can the righteous do?"));
    });

    test('Image 3 - NIV Translation clean up', () {
      const rawNiv1 = "<pb/><e>For the director of music. Of David.</e> <pb/><t>In the LORD I take refuge.</t> <t>How then can you say to me:</t> <t>“Flee like a bird to your mountain.</t>";
      final cleaned1 = BibleVerse.cleanText(rawNiv1);

      expect(cleaned1, isNot(contains('<pb/>')));
      expect(cleaned1, isNot(contains('<e>')));
      expect(cleaned1, isNot(contains('</e>')));
      expect(cleaned1, isNot(contains('<t>')));
      expect(cleaned1, isNot(contains('</t>')));
      expect(cleaned1, contains("For the director of music. Of David."));
      expect(cleaned1, contains("In the LORD I take refuge."));
      expect(cleaned1, contains("“Flee like a bird to your mountain."));

      const rawNivFootnote = "Jesus said to them, <J>“I am the light”</J><f>[1]</f>";
      final cleanedFootnote = BibleVerse.cleanText(rawNivFootnote);
      expect(cleanedFootnote, isNot(contains('[1]')));
      expect(cleanedFootnote, isNot(contains('<f>')));
      expect(cleanedFootnote, equals("Jesus said to them, “I am the light”"));
    });

    test('AMP Translation clean up', () {
      const rawAmp = "<e>A Psalm of David.</e> The LORD is my light<f>ⓐ</f> and my salvation;";
      final cleaned = BibleVerse.cleanText(rawAmp);
      expect(cleaned, isNot(contains('<e>')));
      expect(cleaned, isNot(contains('<f>')));
      expect(cleaned, isNot(contains('ⓐ')));
      expect(cleaned, equals("A Psalm of David. The LORD is my light and my salvation;"));
    });

    test('EasyEnglish HTML tags clean up', () {
      const rawEasyEnglish = "<P><B>Introduction</B></P><SPAN class=\"v\">In the beginning<SUP>1</SUP> God created the heaven and the earth.</SPAN>";
      final cleaned = BibleVerse.cleanText(rawEasyEnglish);
      expect(cleaned, isNot(contains('<')));
      expect(cleaned, isNot(contains('>')));
      expect(cleaned, isNot(contains('1'))); // Superscript footnote number removed
      expect(cleaned, equals("Introduction\nIn the beginning God created the heaven and the earth."));
    });

    test('KJV+ Strong Concordance tags preservation', () {
      const rawKjvPlus = "In the beginning <em>was</em>[G2258] the Word[G3056], and the Word[G3056] was with[G4314] God[G2316]";
      final cleaned = BibleVerse.cleanText(rawKjvPlus);

      // Strong's numbers must be preserved
      expect(cleaned, contains('[G2258]'));
      expect(cleaned, contains('[G3056]'));
      expect(cleaned, contains('[G4314]'));
      expect(cleaned, contains('[G2316]'));

      // HTML angle bracket tags must be stripped
      expect(cleaned, isNot(contains('<em>')));
      expect(cleaned, isNot(contains('</em>')));
      expect(cleaned, equals("In the beginning was[G2258] the Word[G3056], and the Word[G3056] was with[G4314] God[G2316]"));
    });

    test('Empty and whitespace-only strings', () {
      expect(BibleVerse.cleanText(''), equals(''));
      expect(BibleVerse.cleanText('   \n  \t '), equals(''));
      expect(BibleVerse.cleanText('<br/><pb/>'), equals(''));
    });
  });
}
