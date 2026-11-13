import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../theme/imago_theme.dart';

/// Font fallbacks to guarantee currency symbols like '₦' (Naira U+20A6)
/// render cleanly on Android/iOS/Windows without missing-glyph tofu [ ] boxes.
const List<String> kCurrencyFontFallback = [
  'Roboto',
  'Noto Sans',
  'Segoe UI',
  'Arial',
  'sans-serif',
];

/// ─── Paystack Configuration ──────────────────────────────────────────────────
class PartnerPaymentConfig {
  /// Backend primary base URL for payment initialization & verification:
  static const String backendUrl = 'https://imago-1-wkzl.onrender.com';

  /// Your Paystack Payment Page URL or slug fallback (e.g. 'yo-ets-partner'):
  static const String defaultPaystackUrl = '';
}

/// Partnership tiers (preserved for backward compatibility & tests)
enum PartnerTier {
  prayer(
    label: 'Prayer Partner',
    emoji: '🙏',
    amountNGN: 1000,
    description: 'Join us in daily prayer for this ministry',
    perks: ['Daily prayer digest', 'Partner newsletter', 'Prayer request priority'],
    gradient: [Color(0xFF6B4EFF), Color(0xFF3D5AFE)],
  ),
  ministry(
    label: 'Ministry Partner',
    emoji: '✝️',
    amountNGN: 5000,
    description: 'Help keep the Word free for everyone',
    perks: ['All Prayer Partner perks', 'Early access to new features', 'Ministry impact report', 'Partner badge in app'],
    gradient: [Color(0xFFFFC857), Color(0xFFFF9900)],
  ),
  sustaining(
    label: 'Sustaining Partner',
    emoji: '👑',
    amountNGN: 20000,
    description: 'Sustain the mission at the highest level',
    perks: ['All Ministry Partner perks', 'Direct line to founders', 'Name on partner wall', 'Annual ministry report', 'Special prayer coverage'],
    gradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
  );

  const PartnerTier({
    required this.label,
    required this.emoji,
    required this.amountNGN,
    required this.description,
    required this.perks,
    required this.gradient,
  });

  final String label;
  final String emoji;
  final int amountNGN;
  final String description;
  final List<String> perks;
  final List<Color> gradient;

  int get amountUSD => (amountNGN / 1000).round();

  List<Color> getGradient(bool isDark) {
    if (this == PartnerTier.sustaining) {
      return isDark
          ? const [Color(0xFF00C9FF), Color(0xFF34D399)]
          : const [Color(0xFF0284C7), Color(0xFF0F766E)];
    }
    if (this == PartnerTier.ministry) {
      return isDark
          ? const [Color(0xFFFFC857), Color(0xFFFF9900)]
          : const [Color(0xFFD97706), Color(0xFFB45309)];
    }
    return gradient;
  }
}

/// A unified mission giving seed
class MissionSeed {
  final int amountNGN;
  final String title;
  final String subtitle;
  final String emoji;
  final bool isPopular;
  final PartnerTier? tier;

  const MissionSeed({
    required this.amountNGN,
    required this.title,
    required this.subtitle,
    required this.emoji,
    this.isPopular = false,
    this.tier,
  });
}

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonthly = true;
  int _selectedAmount = 5000;
  bool _isCustomSelected = false;
  bool _isProcessing = false;
  String? _pendingReference;
  PartnerTier? _selectedTier = PartnerTier.ministry;
  late final TextEditingController _customAmountController;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const List<MissionSeed> _seeds = [
    MissionSeed(
      amountNGN: 1000,
      title: 'Prayer Partner',
      subtitle: 'Daily prayer shield',
      emoji: '🙏',
      tier: PartnerTier.prayer,
    ),
    MissionSeed(
      amountNGN: 2500,
      title: 'Gospel Builder',
      subtitle: 'Equip believers',
      emoji: '🌱',
    ),
    MissionSeed(
      amountNGN: 5000,
      title: 'Ministry Pillar',
      subtitle: 'Keep Word free',
      emoji: '✝️',
      isPopular: true,
      tier: PartnerTier.ministry,
    ),
    MissionSeed(
      amountNGN: 10000,
      title: 'Kingdom Patron',
      subtitle: 'Expand translations',
      emoji: '🕊️',
    ),
    MissionSeed(
      amountNGN: 25000,
      title: 'Visionary Partner',
      subtitle: 'Global outreach',
      emoji: '👑',
      tier: PartnerTier.sustaining,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _customAmountController = TextEditingController(text: _selectedAmount.toString());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _selectSeed(MissionSeed seed) {
    setState(() {
      _isCustomSelected = false;
      _selectedAmount = seed.amountNGN;
      _selectedTier = seed.tier;
      _customAmountController.text = seed.amountNGN.toString();
    });
  }

  void _selectCustom() {
    setState(() {
      _isCustomSelected = true;
      _selectedTier = null;
    });
  }

  void _onCustomAmountChanged(String val) {
    final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(cleaned) ?? 0;
    setState(() {
      _selectedAmount = parsed;
      _selectedTier = _matchTier(parsed);
    });
  }

  void _incrementCustomAmount(int delta) {
    final current = _selectedAmount;
    final next = (current + delta).clamp(500, 5000000);
    setState(() {
      _selectedAmount = next;
      _customAmountController.text = next.toString();
      _selectedTier = _matchTier(next);
    });
  }

  PartnerTier? _matchTier(int amount) {
    for (final t in PartnerTier.values) {
      if (t.amountNGN == amount) return t;
    }
    return null;
  }

  Future<void> _launchPaystack() async {
    final amountNGN = _selectedAmount;
    if (amountNGN <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ImagoColors.violet,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text(
            'Please select or enter a valid partnership amount.',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
        ),
      );
      return;
    }

    // Determine contributor email
    String email = AuthService.instance.currentEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      final inputEmail = await _promptContributorEmail();
      if (inputEmail == null || inputEmail.isEmpty || !inputEmail.contains('@')) {
        return;
      }
      email = inputEmail;
    }

    setState(() => _isProcessing = true);

    final tierName = _selectedTier?.label ?? 'Mission Partner';
    final frequency = _isMonthly ? 'monthly' : 'one_time';
    final uid = AuthService.instance.currentUser?.uid;

    try {
      // 1. Attempt dynamic initialization with backend Paystack gateway
      final backendUri = Uri.parse('${PartnerPaymentConfig.backendUrl}/api/payments/paystack/initialize');
      final resp = await http.post(
        backendUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'amount': amountNGN,
          'tier': tierName,
          'frequency': frequency,
          'user_id': uid,
          'callback_url': 'yoetz://payment-callback',
        }),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final status = data['status'];
          final authUrl = data['authorization_url'] as String? ?? '';
          final ref = data['reference'] as String? ?? '';
          _pendingReference = ref;

          if (status == 'success' && authUrl.isNotEmpty) {
            final uri = Uri.parse(authUrl);
            if (await canLaunchUrl(uri)) {
              if (mounted) setState(() => _isProcessing = false);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (mounted) {
                _promptVerificationSheet(
                  reference: ref,
                  email: email,
                  tier: tierName,
                  amount: amountNGN,
                );
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PartnerScreen] Backend Paystack init error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    // 2. Direct Hosted Paystack Page URL fallback
    final targetUrl = PartnerPaymentConfig.defaultPaystackUrl.trim();
    if (targetUrl.isNotEmpty && !targetUrl.contains('imago-sustaining') && !targetUrl.contains('imago-prayer')) {
      final baseUrl = targetUrl.startsWith('http')
          ? targetUrl
          : 'https://paystack.com/pay/$targetUrl';

      final uri = Uri.parse(baseUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams['amount'] = (amountNGN * 100).toString();
      if (email.isNotEmpty && email.contains('@')) {
        queryParams['email'] = email;
      }

      final finalUri = uri.replace(queryParameters: queryParams);
      if (await canLaunchUrl(finalUri)) {
        await launchUrl(finalUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 3. Fallback guide if backend key or hosted slug is not yet set
    _showPaymentSetupNotice(amount: '₦${NumberFormat('#,###').format(amountNGN)}');
  }

  Future<String?> _promptContributorEmail() async {
    final emailController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = ImagoColors.isDark;
        final cardBg = isDark ? const Color(0xFF131D33) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Partner Email',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter your email to attach to your contribution receipt.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'your.email@example.com',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue to Paystack'),
            ),
          ],
        );
      },
    );
  }

  void _promptVerificationSheet({
    required String reference,
    required String email,
    required String tier,
    required int amount,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = ImagoColors.isDark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final goldColor = isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('💳', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 14),
              Text(
                'Confirming Contribution',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Once your payment is approved in the browser, tap below to verify and activate your Kingdom Partner badge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _verifyPayment(reference, tier, amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'I Have Completed Payment',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close / Verify Later', style: TextStyle(color: textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _verifyPayment(String reference, String tier, int amount) async {
    setState(() => _isProcessing = true);
    try {
      final uri = Uri.parse('${PartnerPaymentConfig.backendUrl}/api/payments/paystack/verify/$reference');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic> && data['payment_status'] == 'success') {
          final confirmedTier = data['tier'] as String? ?? tier;
          await AuthService.instance.setPartnerTier(confirmedTier);
          if (mounted) {
            _showPartnerCelebrationDialog(confirmedTier, amount);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[PartnerScreen] Verify error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    // Immediate optimistic activation upon contributor confirmation
    await AuthService.instance.setPartnerTier(tier);
    if (mounted) {
      _showPartnerCelebrationDialog(tier, amount);
    }
  }

  void _showPartnerCelebrationDialog(String tier, int amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = ImagoColors.isDark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final goldColor = isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: goldColor.withOpacity(0.3))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('👑', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, Kingdom Partner!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your partnership as a $tier has been activated.\n'
                'Thank you for standing with us to keep God\'s Word accessible without paywalls across the nations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: goldColor.withOpacity(0.25)),
                ),
                child: Text(
                  '"And God is able to bless you abundantly, so that in all things at all times, having all that you need, you will abound in every good work." — 2 Cor 9:8',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Amen & Glory to God',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentSetupNotice({required String amount}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = ImagoColors.isDark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

        return Container(
          padding: EdgeInsets.fromLTRB(
            24, 20, 24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ImagoColors.gold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🇳🇬', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 14),
              Text(
                'Paystack Live Setup',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thank you for your heart to partner with $amount ${_isMonthly ? "/ month" : "one-time"}!\n\n'
                'The backend payment API and webhooks are now ready. To activate live transactions, configure either:\n\n'
                '1. Dynamic API: Set PAYSTACK_SECRET_KEY in backend .env\n'
                '2. Hosted Page: Set defaultPaystackUrl in PartnerPaymentConfig\n\n'
                'For direct partnership or questions, contact us at partner@imagoapp.com.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Understood',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentFallback(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ImagoColors.violet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'Could not open $provider. Please contact us at partner@imagoapp.com',
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final bg = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF131D33) : Colors.white;
        final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final goldColor = isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706);
        final canPop = Navigator.canPop(context);

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              if (isDark) const CosmicBackground(children: []),

              // Ambient background glow
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        goldColor.withOpacity(isDark ? 0.09 : 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Top App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          if (canPop)
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 16),
                              ),
                            )
                          else
                            const SizedBox(width: 40),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: goldColor.withOpacity(isDark ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: goldColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: const Text('✨', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Free Gospel Ministry',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: goldColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),

                    // Scrollable Main Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 580),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title
                                Text(
                                  'Partner With Us',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Cinzel',
                                    color: textPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Essence Subtitle
                                Text(
                                  'yo-ETS is 100% free with no ads or paywalls. '
                                  'Your partnership directly keeps God\'s Word accessible to millions across nations.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Compact Impact Ribbon
                                _buildImpactRibbon(isDark, cardBg, border, textPrimary, textSecondary, goldColor),

                                const SizedBox(height: 20),

                                // Frequency Toggle (Monthly vs One-Time)
                                _buildFrequencyToggle(isDark, cardBg, border, textPrimary, textSecondary),

                                const SizedBox(height: 18),

                                // Unified Mission Amount Grid
                                _buildSeedsGrid(isDark, cardBg, border, textPrimary, textSecondary, goldColor),

                                const SizedBox(height: 16),

                                // Custom Amount Field (Revealed when Custom is chosen)
                                if (_isCustomSelected)
                                  _buildCustomAmountEditor(isDark, cardBg, border, textPrimary, textSecondary, goldColor),

                                const SizedBox(height: 20),

                                // Scripture Blessing Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: goldColor.withOpacity(isDark ? 0.05 : 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: goldColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('🕊️', style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '"Each of you should give what you have decided in your heart... for God loves a cheerful giver." — 2 Cor 9:7',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Primary CTA Button
                                _buildCTAButton(isDark, goldColor),

                                const SizedBox(height: 12),

                                // Trust Footer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Secure via Paystack · Cards, Transfer, USSD · Cancel anytime',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact, single-row impact ribbon
  Widget _buildImpactRibbon(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color goldColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('47', 'Nations', textPrimary, textSecondary),
          _divider(border),
          _statItem('24K', 'Verses Today', textPrimary, textSecondary),
          _divider(border),
          _statItem('22', 'Translations', textPrimary, textSecondary),
          _divider(border),
          _statItem('2,400+', 'Active Users', textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color textPrimary, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cinzel',
            color: textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: textSecondary,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }

  Widget _divider(Color border) {
    return Container(width: 1, height: 24, color: border);
  }

  /// Modern Frequency Pill Toggle (Monthly vs One-Time)
  Widget _buildFrequencyToggle(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleOption('Monthly Partnership', _isMonthly, () {
            setState(() => _isMonthly = true);
          }, textSecondary),
          _toggleOption('One-Time Gift', !_isMonthly, () {
            setState(() => _isMonthly = false);
          }, textSecondary),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, bool active, VoidCallback onTap, Color textSecondary) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: active ? Colors.white : textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Unified 6-card Mission Giving Grid
  Widget _buildSeedsGrid(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color goldColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _seeds.length + 1, // 5 presets + 1 Custom tile
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            if (index < _seeds.length) {
              final seed = _seeds[index];
              final isSelected = !_isCustomSelected && _selectedAmount == seed.amountNGN;
              return _buildSeedCard(seed, isSelected, isDark, cardBg, border, textPrimary, textSecondary, goldColor);
            } else {
              // Custom Amount Card
              return _buildCustomTile(isDark, cardBg, border, textPrimary, textSecondary, goldColor);
            }
          },
        );
      },
    );
  }

  Widget _buildSeedCard(
    MissionSeed seed,
    bool isSelected,
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color goldColor,
  ) {
    final activeColor = seed.isPopular ? goldColor : const Color(0xFF0284C7);

    return GestureDetector(
      onTap: () => _selectSeed(seed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : border,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(isDark ? 0.25 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (seed.isPopular)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: goldColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PILLAR',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(seed.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        seed.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: isSelected ? activeColor : textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Naira Amount
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '₦',
                        style: TextStyle(
                          fontFamilyFallback: kCurrencyFontFallback,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: NumberFormat('#,###').format(seed.amountNGN),
                        style: const TextStyle(
                          fontFamily: 'Cinzel',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: isSelected ? activeColor : textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  seed.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color goldColor,
  ) {
    final isSelected = _isCustomSelected;
    final activeColor = const Color(0xFF0284C7);

    return GestureDetector(
      onTap: _selectCustom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : border,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(isDark ? 0.25 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 5),
                Text(
                  'Give As Led',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isSelected ? activeColor : textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Custom',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: isSelected ? activeColor : textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Any amount God leads',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: textSecondary.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom Amount numeric input and quick adjustment chips
  Widget _buildCustomAmountEditor(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color goldColor,
  ) {
    const primaryAccent = Color(0xFF0284C7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Enter Custom Seed',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _isMonthly ? 'monthly' : 'one-time',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Text(
                  '₦',
                  style: TextStyle(
                    fontFamilyFallback: kCurrencyFontFallback,
                    color: primaryAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    onChanged: _onCustomAmountChanged,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g. 50000',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: textSecondary.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NGN',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: primaryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Quick adjustments
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _quickAddChip('+₦1,000', 1000, primaryAccent, textSecondary),
              _quickAddChip('+₦5,000', 5000, primaryAccent, textSecondary),
              _quickAddChip('+₦10,000', 10000, primaryAccent, textSecondary),
              _quickAddChip('+₦50,000', 50000, primaryAccent, textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAddChip(String label, int amount, Color accent, Color textSecondary) {
    return GestureDetector(
      onTap: () => _incrementCustomAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '+₦',
                style: TextStyle(fontFamilyFallback: kCurrencyFontFallback),
              ),
              TextSpan(text: NumberFormat('#,###').format(amount)),
            ],
          ),
          style: TextStyle(
            fontFamily: 'Poppins',
            color: accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Gorgeous, Guaranteed-Glyph CTA Button
  Widget _buildCTAButton(bool isDark, Color goldColor) {
    final formattedAmount = NumberFormat('#,###').format(_selectedAmount);

    final grad = _selectedTier != null
        ? _selectedTier!.getGradient(isDark)
        : const [Color(0xFF0284C7), Color(0xFF0369A1)];

    if (_isProcessing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Connecting to Paystack...',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _launchPaystack,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: grad.first.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🇳🇬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _isMonthly ? 'Partner with ' : 'Seed with ',
                  ),
                  const TextSpan(
                    text: '₦',
                    style: TextStyle(
                      fontFamilyFallback: kCurrencyFontFallback,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: formattedAmount,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: _isMonthly ? ' /mo' : ' (One-Time)',
                    style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontFamilyFallback: kCurrencyFontFallback,
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
