import 'package:flutter/material.dart';
import '../theme/imago_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class TypographySettingsSheet extends StatelessWidget {
  final String currentFontFamily;
  final double currentFontSize;
  final double currentLineHeight;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const TypographySettingsSheet({
    super.key,
    required this.currentFontFamily,
    required this.currentFontSize,
    required this.currentLineHeight,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
  });

  static void show(
    BuildContext context, {
    required String currentFontFamily,
    required double currentFontSize,
    required double currentLineHeight,
    required ValueChanged<String> onFontFamilyChanged,
    required ValueChanged<double> onFontSizeChanged,
    required ValueChanged<double> onLineHeightChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TypographySettingsSheet(
        currentFontFamily: currentFontFamily,
        currentFontSize: currentFontSize,
        currentLineHeight: currentLineHeight,
        onFontFamilyChanged: onFontFamilyChanged,
        onFontSizeChanged: onFontSizeChanged,
        onLineHeightChanged: onLineHeightChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'Typography',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: ImagoColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'FONT FAMILY',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildFontOption('Poppins', 'Modern Sans', false),
              SizedBox(width: 12),
              _buildFontOption('Lora', 'Classic Serif', true),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'FONT SIZE',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Slider(
            value: currentFontSize,
            min: 12.0,
            max: 24.0,
            activeColor: ImagoColors.gold,
            inactiveColor: Colors.white12,
            onChanged: onFontSizeChanged,
          ),
          SizedBox(height: 12),
          Text(
            'LINE SPACING',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Slider(
            value: currentLineHeight,
            min: 1.2,
            max: 2.2,
            activeColor: ImagoColors.gold,
            inactiveColor: Colors.white12,
            onChanged: onLineHeightChanged,
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFontOption(String family, String label, bool isGoogleFont) {
    final isSelected = currentFontFamily == family;
    return Expanded(
      child: GestureDetector(
        onTap: () => onFontFamilyChanged(family),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ImagoColors.gold : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: isGoogleFont 
                    ? GoogleFonts.getFont(family, color: isSelected ? ImagoColors.gold : Colors.white, fontSize: 24)
                    : TextStyle(fontFamily: family, color: isSelected ? ImagoColors.gold : Colors.white, fontSize: 24),
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected ? ImagoColors.gold : Colors.white54,
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
