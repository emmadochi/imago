import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'bible_screen.dart';
import 'prayer_screen.dart';
import 'profile_screen.dart';
import 'desktop_shell.dart';
import '../services/notification_service.dart';
import '../services/lcm_bridge.dart';
import '../theme/imago_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LcmBridge.checkForUpdates(context);
      }
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  Widget _buildTab(int index, Widget child) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return TickerMode(
      enabled: _currentIndex == index,
      child: child,
    );
  }

  // 5 tabs: Home(0) | Bible(1) | Chat/Imago(2) | Prayer(3) | Profile(4)
  List<Widget> get _screens => [
    _buildTab(0, HomeScreen(onNavigate: (i) => _onTabSelected(i))),
    _buildTab(1, const BibleScreen()),
    _buildTab(2, const ChatScreen()),
    _buildTab(3, const PrayerScreen()),
    _buildTab(4, const ProfileScreen()),
  ];

  Future<bool> _showExitDialog() async {
    final isDark = ImagoColors.isDark;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Exit Imago?',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
            color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569),
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
                color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Exit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) {
      return const DesktopShell();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
          return const DesktopShell();
        }

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
          child: ListenableBuilder(
            listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
            builder: (context, _) {
              final isDark = ImagoColors.isDark;

              final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
              return Scaffold(
                backgroundColor: isDark
                    ? ImagoColors.deepSpace
                    : (isParchment ? const Color(0xFFF7F2E7) : const Color(0xFFF8FAFC)),
                extendBody: true,
                body: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
                bottomNavigationBar: ValueListenableBuilder<bool>(
                  valueListenable: BibleScreen.distractionFreeNotifier,
                  builder: (context, isDistractionFree, child) {
                    if (isDistractionFree) return const SizedBox.shrink();
                    return _buildFloatingNav(isDark);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFloatingNav(bool isDark) {
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
    final navBg = isDark
        ? const Color(0xFF0C1322).withOpacity(0.88)
        : (isParchment ? const Color(0xFFFAF6EE).withOpacity(0.92) : Colors.white.withOpacity(0.92));
    final navBorder = isDark
        ? const Color(0xFF334155).withOpacity(0.45)
        : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: navBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: navBorder,
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(0, Icons.home_rounded, 'Home', isDark),
                      _navItem(1, Icons.menu_book_rounded, 'Bible', isDark),
                      _centralYoetsButton(isDark),
                      _navItem(3, Icons.volunteer_activism_rounded, 'Prayer', isDark),
                      _navItem(4, Icons.person_rounded, 'Profile', isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
    final activeColor = isDark
        ? ImagoColors.gold
        : (isParchment ? const Color(0xFF9A6B2F) : const Color(0xFF4F46E5));
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));
    final textActive = isDark
        ? Colors.white
        : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabSelected(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? textActive : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centralYoetsButton(bool isDark) {
    final isSelected = _currentIndex == 2;
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final textActive = isDark ? Colors.white : const Color(0xFF0F172A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabSelected(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 29,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF818CF8)
                      : (isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: isSelected ? Colors.white : inactiveColor,
                size: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Yoets',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? textActive : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
