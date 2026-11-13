import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'theme/imago_theme.dart';
import 'services/auth_service.dart';
import 'services/feedback_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Constrain in-memory decoded image cache to prevent memory bloating
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // 40 MB max
  PaintingBinding.instance.imageCache.maximumSize = 80;

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase desktop initialization note: $e");
  }

  // Pre-load and sync persistent authentication state before rendering
  await AuthService.instance.init();
  
  final prefs = await SharedPreferences.getInstance();
  final savedThemeIndex = prefs.getInt('appTheme') ?? 0;
  if (savedThemeIndex >= 0 && savedThemeIndex < AppThemeMode.values.length) {
    appThemeNotifier.value = AppThemeMode.values[savedThemeIndex];
  }
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  final defaultReaderTheme = isDesktop ? ReaderThemeMode.day.index : ReaderThemeMode.night.index;
  final savedReaderThemeIndex = prefs.getInt('readerTheme') ?? defaultReaderTheme;
  if (savedReaderThemeIndex >= 0 && savedReaderThemeIndex < ReaderThemeMode.values.length) {
    readerThemeNotifier.value = ReaderThemeMode.values[savedReaderThemeIndex];
  }

  // Flush any pending offline user feedback silently
  FeedbackService.instance.syncPendingFeedback();

  runApp(const ImagoApp());
}

class ImagoApp extends StatelessWidget {
  const ImagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        return MaterialApp(
          title: 'yo-ETS — Digital Ministry Platform',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(
              isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
            ),
            scaffoldBackgroundColor: ImagoColors.deepSpace,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          builder: (context, child) {
            ErrorWidget.builder = (FlutterErrorDetails details) {
              return Container(
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Text(
                    'Error: ${details.exceptionAsString()}',
                    style: const TextStyle(color: Color(0xFFF87171), fontSize: 13, fontFamily: 'Poppins'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            };
            return child ?? const SizedBox();
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
