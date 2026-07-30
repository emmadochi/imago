import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'bible_screen.dart';
import 'prayer_screen.dart';
import 'profile_screen.dart';
import '../theme/imago_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 5 tabs: Home(0) | Bible(1) | Chat/Imago(2) | Prayer(3) | Profile(4)
  List<Widget> get _screens => [
    HomeScreen(onNavigate: (i) => setState(() => _currentIndex = i)),
    const BibleScreen(),
    const ChatScreen(),
    const PrayerScreen(),
    const ProfileScreen(),
  ];

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E0B24).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          title: Row(
            children: [
              Icon(Icons.power_settings_new_rounded, color: ImagoColors.gold, size: 24),
              const SizedBox(width: 10),
              Text(
                'Exit Imago?',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: ImagoColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to close the application?',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.8),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ImagoColors.gold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text(
                'Exit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await _showExitDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<AppThemeMode>(
        valueListenable: appThemeNotifier,
        builder: (context, theme, _) {
          return Scaffold(
            backgroundColor: ImagoColors.deepSpace,
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: ValueListenableBuilder<bool>(
              valueListenable: BibleScreen.distractionFreeNotifier,
              builder: (context, isDistractionFree, child) {
                if (isDistractionFree) return const SizedBox.shrink();
                return _buildFloatingNav();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      decoration: BoxDecoration(
        color: ImagoColors.nebula.withOpacity(0.75),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ImagoColors.violet.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: ImagoColors.violet.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, 'Home'),
                _navItem(1, Icons.menu_book_rounded, 'Bible'),
                _centralImagoButton(),
                _navItem(3, Icons.volunteer_activism_rounded, 'Prayer'),
                _navItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ImagoColors.violet.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: ImagoColors.violet.withOpacity(0.4))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? ImagoColors.gold
                  : Colors.white.withOpacity(0.4),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centralImagoButton() {
    final isSelected = _currentIndex == 2;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ImagoColors.violetGradient,
              boxShadow: [
                BoxShadow(
                  color: ImagoColors.violet.withOpacity(isSelected ? 0.7 : 0.4),
                  blurRadius: isSelected ? 20 : 14,
                  spreadRadius: isSelected ? 2 : 1,
                ),
              ],
            ),
            child: const Icon(Icons.church_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'yo-ETS',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? ImagoColors.gold : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
