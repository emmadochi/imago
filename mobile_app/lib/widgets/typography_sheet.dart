import 'package:flutter/material.dart';
import '../theme/imago_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class TypographySettingsSheet extends StatelessWidget {
  final ReaderThemeMode currentReaderTheme;
  final String currentFontFamily;
  final double currentFontSize;
  final double currentLineHeight;
  final ValueChanged<ReaderThemeMode> onReaderThemeChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const TypographySettingsSheet({
    super.key,
    required this.currentReaderTheme,
    required this.currentFontFamily,
    required this.currentFontSize,
    required this.currentLineHeight,
    required this.onReaderThemeChanged,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
  });

  static void show(
    BuildContext context, {
    required ReaderThemeMode currentReaderTheme,
    required String currentFontFamily,
    required double currentFontSize,
    required double currentLineHeight,
    required ValueChanged<ReaderThemeMode> onReaderThemeChanged,
    required ValueChanged<String> onFontFamilyChanged,
    required ValueChanged<double> onFontSizeChanged,
    required ValueChanged<double> onLineHeightChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        ReaderThemeMode activeTheme = currentReaderTheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = ReaderTheme.of(activeTheme);
            return Container(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: theme.borderColor),
              ),
              child: TypographySettingsSheet(
                currentReaderTheme: activeTheme,
                currentFontFamily: currentFontFamily,
                currentFontSize: currentFontSize,
                currentLineHeight: currentLineHeight,
                onReaderThemeChanged: (newMode) {
                  setSheetState(() {
                    activeTheme = newMode;
                  });
                  onReaderThemeChanged(newMode);
                },
                onFontFamilyChanged: onFontFamilyChanged,
                onFontSizeChanged: onFontSizeChanged,
                onLineHeightChanged: onLineHeightChanged,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ReaderTheme.of(currentReaderTheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading Display',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: theme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'READING THEME',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: theme.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildThemeOption(
                mode: ReaderThemeMode.night,
                label: 'Midnight',
                icon: Icons.dark_mode_rounded,
                previewBg: const Color(0xFF0B132B),
                previewText: Colors.white,
                accentColor: ImagoColors.gold,
                currentTheme: theme,
              ),
              const SizedBox(width: 10),
              _buildThemeOption(
                mode: ReaderThemeMode.parchment,
                label: 'Parchment',
                icon: Icons.auto_stories_rounded,
                previewBg: const Color(0xFFF7F2E7),
                previewText: const Color(0xFF2C241D),
                accentColor: const Color(0xFF9A6B2F),
                currentTheme: theme,
              ),
              const SizedBox(width: 10),
              _buildThemeOption(
                mode: ReaderThemeMode.day,
                label: 'Alabaster',
                icon: Icons.light_mode_rounded,
                previewBg: const Color(0xFFF5F7FA),
                previewText: const Color(0xFF19202C),
                accentColor: const Color(0xFF3D5AFE),
                currentTheme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'FONT FAMILY',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: theme.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFontOption('Poppins', 'Modern Sans', false, theme),
              const SizedBox(width: 12),
              _buildFontOption('Lora', 'Classic Serif', true, theme),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FONT SIZE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: theme.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${currentFontSize.toStringAsFixed(1)} pt',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: theme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: theme.borderColor,
              thumbColor: theme.accentColor,
              overlayColor: theme.accentColor.withOpacity(0.15),
            ),
            child: Slider(
              value: currentFontSize,
              min: 12.0,
              max: 26.0,
              onChanged: onFontSizeChanged,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LINE SPACING',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: theme.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${currentLineHeight.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: theme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: theme.borderColor,
              thumbColor: theme.accentColor,
              overlayColor: theme.accentColor.withOpacity(0.15),
            ),
            child: Slider(
              value: currentLineHeight,
              min: 1.2,
              max: 2.4,
              onChanged: onLineHeightChanged,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required ReaderThemeMode mode,
    required String label,
    required IconData icon,
    required Color previewBg,
    required Color previewText,
    required Color accentColor,
    required ReaderTheme currentTheme,
  }) {
    final isSelected = currentReaderTheme == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onReaderThemeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : currentTheme.borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? accentColor : previewText.withOpacity(0.7), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: previewText,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontOption(String family, String label, bool isGoogleFont, ReaderTheme theme) {
    final isSelected = currentFontFamily == family;
    return Expanded(
      child: GestureDetector(
        onTap: () => onFontFamilyChanged(family),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor.withOpacity(0.12) : theme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.accentColor : theme.borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: isGoogleFont
                    ? GoogleFonts.getFont(family, color: isSelected ? theme.accentColor : theme.primaryText, fontSize: 22)
                    : TextStyle(fontFamily: family, color: isSelected ? theme.accentColor : theme.primaryText, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected ? theme.accentColor : theme.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
