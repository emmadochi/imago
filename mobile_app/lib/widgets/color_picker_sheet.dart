// lib/widgets/color_picker_sheet.dart

import 'package:flutter/material.dart';
import '../theme/imago_theme.dart';

class ColorPickerSheet extends StatelessWidget {
  final String? initialColor;
  final Function(String colorHex) onColorSelected;
  final VoidCallback onRemoveHighlight;

  const ColorPickerSheet({
    super.key,
    this.initialColor,
    required this.onColorSelected,
    required this.onRemoveHighlight,
  });

  static void show(
    BuildContext context, {
    String? initialColor,
    required Function(String colorHex) onColorSelected,
    required VoidCallback onRemoveHighlight,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ColorPickerSheet(
        initialColor: initialColor,
        onColorSelected: onColorSelected,
        onRemoveHighlight: onRemoveHighlight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A palette of premium highlight colors
    final List<Map<String, String>> colors = [
      {'name': 'Gold', 'hex': '#D4AF37'},
      {'name': 'Emerald', 'hex': '#2ECC71'},
      {'name': 'Sapphire', 'hex': '#3498DB'},
      {'name': 'Amethyst', 'hex': '#9B59B6'},
      {'name': 'Ruby', 'hex': '#E74C3C'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Highlight Verse',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: ImagoColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: colors.map((c) {
              final color = Color(int.parse(c['hex']!.replaceFirst('#', '0xFF')));
              final isSelected = initialColor == c['hex'];

              return GestureDetector(
                onTap: () {
                  onColorSelected(c['hex']!);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : color,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24),
          if (initialColor != null)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  onRemoveHighlight();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Remove Highlight',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.red.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
