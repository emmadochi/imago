import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/imago_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _introPages = [
    {
      'icon': Icons.auto_awesome_rounded,
      'iconColor': const Color(0xFF6B4EFF),
      'glowColor': const Color(0xFF6B4EFF),
      'title': 'Discover the\nGod in You',
      'body':
          'yo-ETS is more than an AI. It is your pastor\'s teachings, wisdom, and counseling available to you 24 hours a day — wherever life takes you.',
    },
    {
      'icon': Icons.church_rounded,
      'iconColor': const Color(0xFF00C9FF),
      'glowColor': const Color(0xFF00C9FF),
      'title': 'Your Pastor,\nAlways Available',
      'body':
          'Every answer is drawn strictly from our pastor\'s sermons, books, and teachings — powered by AI that never invents doctrine.',
    },
    {
      'icon': Icons.volunteer_activism_rounded,
      'iconColor': const Color(0xFFB78AFF),
      'glowColor': const Color(0xFFB78AFF),
      'title': 'Counseling.\nPrayer. Growth.',
      'body':
          'Talk to yo-ETS about life\'s struggles, join a prayer session, track your spiritual growth, and explore your pastor\'s sermon archive.',
    },
  ];

  int get _totalPages => _introPages.length + 1; // 3 intro pages + 1 mode selection page

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _selectLightingMode(ReaderThemeMode mode) async {
    readerThemeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readerTheme', mode.index);
    if (mounted) setState(() {});
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded', true);
    await prefs.setInt('readerTheme', readerThemeNotifier.value.index);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
        final primaryText = isDark
            ? Colors.white
            : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));
        final secondaryText = isDark
            ? const Color(0xFF94A3B8)
            : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const CosmicBackground(children: []),

              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        // Skip button
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: TextButton(
                              onPressed: _finishOnboarding,
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: secondaryText.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Page view
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemCount: _totalPages,
                            itemBuilder: (context, index) {
                              if (index < _introPages.length) {
                                return _buildIntroPage(_introPages[index], primaryText, secondaryText);
                              }
                              return _buildModeSelectionPage(primaryText, secondaryText);
                            },
                          ),
                        ),

                        // Bottom area: dots + button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 12, 32, 36),
                          child: Column(
                            children: [
                              // Page indicator dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_totalPages, (i) {
                                  final bool active = i == _currentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: active ? 26 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? (isDark
                                              ? ImagoColors.gold
                                              : (isParchment ? const Color(0xFF9A6B2F) : const Color(0xFF4F46E5)))
                                          : secondaryText.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 24),

                              // Next / Get Started button
                              GestureDetector(
                                onTap: _nextPage,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: isDark
                                        ? ImagoColors.violetGradient
                                        : (isParchment
                                            ? const LinearGradient(
                                                colors: [Color(0xFF9A6B2F), Color(0xFF8B5E28)],
                                              )
                                            : const LinearGradient(
                                                colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                                              )),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? ImagoColors.violet.withOpacity(0.4)
                                            : (isParchment
                                                ? const Color(0xFF9A6B2F).withOpacity(0.3)
                                                : const Color(0xFF4F46E5).withOpacity(0.35)),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentPage < _totalPages - 1
                                          ? 'Continue'
                                          : 'Begin My Journey',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntroPage(Map<String, dynamic> page, Color primaryText, Color secondaryText) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Glowing icon orb
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (page['glowColor'] as Color).withOpacity(0.12),
              border: Border.all(
                color: (page['glowColor'] as Color).withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: (page['glowColor'] as Color).withOpacity(0.22),
                  blurRadius: 36,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Icon(
                  page['icon'] as IconData,
                  size: 48,
                  color: page['iconColor'] as Color,
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Title
          Text(
            page['title'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: primaryText,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 20),

          // Body
          Text(
            page['body'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.5,
              color: secondaryText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionPage(Color primaryText, Color secondaryText) {
    final currentMode = readerThemeNotifier.value;
    final isDark = ImagoColors.isDark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? ImagoColors.violet.withOpacity(0.15) : const Color(0xFFEEF2FF),
              border: Border.all(
                color: isDark ? ImagoColors.violet.withOpacity(0.4) : const Color(0xFFC7D2FE),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? ImagoColors.violet.withOpacity(0.25) : const Color(0xFF4F46E5).withOpacity(0.15),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.brightness_medium_rounded,
              size: 38,
              color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
            ),
          ),

          const SizedBox(height: 22),

          Text(
            'Choose Your\nAtmosphere',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: primaryText,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Select your preferred lighting mode. You can customize this anytime in Profile settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: secondaryText,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // 3 Mode Selection Cards
          _buildModeCard(
            mode: ReaderThemeMode.night,
            title: 'Midnight',
            subtitle: 'Celestial Dark • Deep contemplation',
            icon: Icons.dark_mode_rounded,
            cardBg: const Color(0xFF0B132B),
            cardTextColor: Colors.white,
            accentColor: ImagoColors.gold,
            isSelected: currentMode == ReaderThemeMode.night,
            onTap: () => _selectLightingMode(ReaderThemeMode.night),
          ),

          const SizedBox(height: 12),

          _buildModeCard(
            mode: ReaderThemeMode.parchment,
            title: 'Parchment',
            subtitle: 'Sacred Papyrus • Ancient manuscript warmth',
            icon: Icons.auto_stories_rounded,
            cardBg: const Color(0xFFF7F2E7),
            cardTextColor: const Color(0xFF2C241D),
            accentColor: const Color(0xFF9A6B2F),
            isSelected: currentMode == ReaderThemeMode.parchment,
            onTap: () => _selectLightingMode(ReaderThemeMode.parchment),
          ),

          const SizedBox(height: 12),

          _buildModeCard(
            mode: ReaderThemeMode.day,
            title: 'Alabaster',
            subtitle: 'Clean Linen • Crisp daylight reading',
            icon: Icons.light_mode_rounded,
            cardBg: const Color(0xFFFFFFFF),
            cardTextColor: const Color(0xFF0F172A),
            accentColor: const Color(0xFF4F46E5),
            isSelected: currentMode == ReaderThemeMode.day,
            onTap: () => _selectLightingMode(ReaderThemeMode.day),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required ReaderThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color cardBg,
    required Color cardTextColor,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : cardTextColor.withOpacity(0.18),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? accentColor.withOpacity(0.3) : Colors.black.withOpacity(0.06),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor.withOpacity(0.18) : cardTextColor.withOpacity(0.08),
              ),
              child: Icon(
                icon,
                color: isSelected ? accentColor : cardTextColor.withOpacity(0.85),
                size: 22,
              ),
            ),

            const SizedBox(width: 14),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cardTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      color: cardTextColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : cardTextColor.withOpacity(0.3),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
