// lib/widgets/feedback_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/feedback_model.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../theme/imago_theme.dart';

class FeedbackDialog extends StatefulWidget {
  final String screenContext;
  final Map<String, dynamic>? metadata;
  final FeedbackCategory? initialCategory;

  const FeedbackDialog({
    super.key,
    this.screenContext = 'general',
    this.metadata,
    this.initialCategory,
  });

  static Future<void> show(
    BuildContext context, {
    String screenContext = 'general',
    Map<String, dynamic>? metadata,
    FeedbackCategory? initialCategory,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    if (isDesktop) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: FeedbackDialog(
              screenContext: screenContext,
              metadata: metadata,
              initialCategory: initialCategory,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FeedbackDialog(
            screenContext: screenContext,
            metadata: metadata,
            initialCategory: initialCategory,
          ),
        ),
      );
    }
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late FeedbackCategory _selectedCategory;
  int _selectedRating = 5;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final Map<int, String> _ratingLabels = {
    1: 'Needs Work 😔',
    2: 'Could Be Better 😐',
    3: 'Good Experience 🙂',
    4: 'Great & Helpful! 😊',
    5: 'Life-Changing & Blessed! ✨',
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? FeedbackCategory.general;
    final currentEmail = AuthService.instance.currentEmail;
    if (currentEmail.isNotEmpty) {
      _emailController.text = currentEmail;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please share a few words with your feedback.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FeedbackService.instance.submitFeedback(
        category: _selectedCategory,
        rating: _selectedRating,
        message: message,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        screenContext: widget.screenContext,
        metadata: widget.metadata,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });

        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Text('🙏', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thank you for your feedback! You are actively helping us shape yo-ETS.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving feedback: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ImagoColors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: ImagoColors.surface.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: ImagoColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ImagoColors.secondaryText.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ImagoColors.violetGradient,
                      ),
                      child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shape yo-ETS',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.primaryText,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Early User Validation & Ministry Feedback',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: ImagoColors.secondaryText,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: ImagoColors.secondaryText),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                if (_isSubmitted) ...[
                  const SizedBox(height: 36),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981).withOpacity(0.18),
                            border: Border.all(color: const Color(0xFF10B981), width: 2),
                          ),
                          child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Feedback Received!',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: ImagoColors.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Thank you for partnering with us to build this spiritual haven.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: ImagoColors.secondaryText,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 18),

                  // Screen Context Badge
                  if (widget.screenContext.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ImagoColors.violet.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ImagoColors.violet.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded, size: 13, color: ImagoColors.violet),
                          const SizedBox(width: 4),
                          Text(
                            'Context: ${widget.screenContext.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: ImagoColors.violet,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Rating Section
                  Text(
                    'Overall Experience Rating',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: ImagoColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= _selectedRating;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 180),
                            scale: isSelected ? 1.15 : 1.0,
                            child: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isSelected ? ImagoColors.gold : ImagoColors.secondaryText.withOpacity(0.4),
                              size: 34,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _ratingLabels[_selectedRating] ?? '',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: ImagoColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Category Selector
                  Text(
                    'Feedback Category',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: ImagoColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FeedbackCategory.values.map((cat) {
                      final isCat = _selectedCategory == cat;
                      return ChoiceChip(
                        avatar: Text(cat.iconEmoji, style: const TextStyle(fontSize: 13)),
                        label: Text(
                          cat.label,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: isCat ? Colors.white : ImagoColors.secondaryText,
                            fontWeight: isCat ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        selected: isCat,
                        selectedColor: ImagoColors.violet,
                        backgroundColor: ImagoColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCat ? ImagoColors.violet : ImagoColors.borderColor,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // Message Field
                  Text(
                    'Your Thoughts & Feedback',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: ImagoColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: ImagoColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ImagoColors.borderColor),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.primaryText,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedCategory.defaultPrompt,
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: ImagoColors.secondaryText.withOpacity(0.6),
                          fontSize: 12.5,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Optional Email Field
                  Container(
                    decoration: BoxDecoration(
                      color: ImagoColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ImagoColors.borderColor),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.primaryText,
                        fontSize: 12.5,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: ImagoColors.secondaryText, size: 18),
                        hintText: 'Email for follow-up (optional)',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: ImagoColors.secondaryText.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ImagoColors.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.send_rounded, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Send Validation Feedback',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
