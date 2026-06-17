// lib/main.dart
//
// Application entry point for Peblo Story Buddy & Quiz.
//
// ARCHITECTURE NOTE:
//   - ProviderScope wraps the entire app — all Riverpod providers are
//     accessible from any widget in the tree.
//   - Portrait orientation is locked for optimal child experience.
//   - Status bar and navigation bar are styled to match the Peblo palette.
//   - No business logic lives here — this file is bootstrapping only.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/story_screen.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation lock — portrait only for optimal child UX ──────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── System UI overlay styling ───────────────────────────────────────────────
  // Immersive transparent status bar with dark icons (light background).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: AppConstants.backgroundLavender,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(
    // ProviderScope is the root of the Riverpod DI graph.
    // All providers declared in providers.dart are available here.
    const ProviderScope(
      child: PebloApp(),
    ),
  );
}

// ─── PebloApp ────────────────────────────────────────────────────────────────

/// Root widget for the Peblo Story Buddy & Quiz experience.
///
/// Owns [MaterialApp] and applies [AppTheme.theme]. All navigation,
/// routing, and deep-link handling will be added here in Phase 3.
class PebloApp extends StatelessWidget {
  const PebloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // StoryScreen is the single entry point for Phase 1 & 2.
      // Phase 3 will introduce named routes and a Navigator 2.0 router.
      home: const StoryScreen(),
    );
  }
}
