import 'package:flutter/material.dart';
import '../theme/imago_theme.dart';

class InterlinearVerseWidget extends StatelessWidget {
  final int verseNumber;
  final String text;
  final bool isInterlinearMode;
  final Function(String strongs) onStrongTap;
  final Function(String word)? onWordDefine;
  final VoidCallback? onLongPress;
  
  final double fontSize;
  final String fontFamily;
  final Color textColor;
  final double lineHeight;

  const InterlinearVerseWidget({
    super.key,
    required this.verseNumber,
    required this.text,
    required this.isInterlinearMode,
    required this.onStrongTap,
    this.onWordDefine,
    this.onLongPress,
    this.fontSize = 15.5,
    this.fontFamily = 'Poppins',
    this.textColor = Colors.white,
    this.lineHeight = 1.7,
  });

  static final RegExp _tagRegExp = RegExp(r'\[([GH]\d+)\]');
  static final RegExp _htmlRegExp = RegExp(r'<[^>]*>');

  /// Removes all Strong's tags like [G1234] and HTML tags from plain text
  static String stripTags(String rawText) {
    var text = rawText.replaceAll(_tagRegExp, '');
    text = text.replaceAll(_htmlRegExp, '');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    if (!isInterlinearMode || !_tagRegExp.hasMatch(text)) {
      final cleanText = stripTags(text);
      return GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$verseNumber',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.gold.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  cleanText,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: textColor,
                    fontSize: fontSize,
                    height: lineHeight,
                  ),
                  contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: [
                        ContextMenuButtonItem(
                          label: 'Copy',
                          onPressed: () {
                            editableTextState.copySelection(SelectionChangedCause.toolbar);
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Select All',
                          onPressed: () {
                            editableTextState.selectAll(SelectionChangedCause.toolbar);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Parse into Interlinear tokens
    final tokens = _parseTokens(text);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$verseNumber',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: ImagoColors.gold.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6 * (lineHeight / 1.7),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: tokens.map((t) => _buildTokenChip(t)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenChip(_InterlinearToken token) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (token.strongs != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onStrongTap(token.strongs!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: ImagoColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ImagoColors.gold.withOpacity(0.4), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: ImagoColors.gold.withOpacity(0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  token.strongs!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: ImagoColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            if (token.strongs != null) {
              onStrongTap(token.strongs!);
            } else if (onWordDefine != null) {
              onWordDefine!(token.word);
            }
          },
          child: Text(
            token.word,
            style: TextStyle(
              fontFamily: fontFamily,
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  List<_InterlinearToken> _parseTokens(String raw) {
    final list = <_InterlinearToken>[];
    // Strip out HTML tags (e.g. <em>) before parsing words
    final cleanRaw = raw.replaceAll(_htmlRegExp, '');
    final words = cleanRaw.split(' ');
    
    for (final w in words) {
      if (w.isEmpty) continue;
      // Match word, optional strongs tag like [H1234], and trailing punctuation
      final match = RegExp(r'^([^\s\[\]]+)(?:\[([GH]\d+)\])?(.*)$').firstMatch(w);
      if (match != null) {
        final word = match.group(1)!;
        final strongs = match.group(2);
        final punctuation = match.group(3) ?? '';
        list.add(_InterlinearToken(word: '$word$punctuation', strongs: strongs));
      } else {
        list.add(_InterlinearToken(word: w, strongs: null));
      }
    }
    return list;
  }
}

class _InterlinearToken {
  final String word;
  final String? strongs;
  _InterlinearToken({required this.word, this.strongs});
}
