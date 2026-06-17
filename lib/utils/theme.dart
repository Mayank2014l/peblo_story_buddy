import 'package:flutter/cupertino.dart';
// lib
// /utils/theme.dart
//
// Peblo visual design system — ThemeData, gradients, shadows, and glow helpers.
//
// ARCHITECTURE NOTE:
//   All theme helpers are static methods on an abstract final class.
//   Widgets consume this via Theme.of(context) for Material tokens, and
//   directly via AppTheme.cardShadow() / AppTheme.buddyGlow() for Peblo
//   custom tokens that have no Material equivalent.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

/// Peblo's complete visual design system.
///
/// Provides [ThemeData] for MaterialApp and a suite of helper methods for
/// Peblo-specific visual tokens (gradients, shadows, glows) that extend
/// beyond Material's built-in theming API.
abstract final class AppTheme {
  // ─── Root Theme ─────────────────────────────────────────────────────────────

  /// The root [ThemeData] passed to [MaterialApp.theme].
  ///
  /// Built on Material 3 with a fully customised Peblo colour scheme,
  /// typography, card shape, and button style.
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: _colorScheme,
        textTheme: _textTheme,
        cardTheme: _cardTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        filledButtonTheme: _filledButtonTheme,
        scaffoldBackgroundColor: AppConstants.backgroundLavender,
        splashFactory: InkRipple.splashFactory,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  // ─── Colour Scheme ───────────────────────────────────────────────────────────

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,

    // Primaries
    primary: AppConstants.primaryCoral,
    onPrimary: Colors.white,
    primaryContainer: AppConstants.softPeach,
    onPrimaryContainer: AppConstants.deepIndigo,

    // Secondaries
    secondary: AppConstants.skyBlue,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD6F0FF),
    onSecondaryContainer: AppConstants.deepIndigo,

    // Tertiaries
    tertiary: AppConstants.sunnyYellow,
    onTertiary: AppConstants.deepIndigo,
    tertiaryContainer: Color(0xFFFFF9C4),
    onTertiaryContainer: AppConstants.deepIndigo,

    // Error
    error: AppConstants.errorSoft,
    onError: Colors.white,
    errorContainer: Color(0xFFFFEDE8),
    onErrorContainer: AppConstants.deepIndigo,

    // Surfaces
    surface: Colors.white,
    onSurface: AppConstants.deepIndigo,
    surfaceContainerHighest: AppConstants.backgroundLavender,
    onSurfaceVariant: AppConstants.mutedIndigo,

    // Outline
    outline: Color(0xFFDDD8F5),
    outlineVariant: Color(0xFFEEEBFF),
  );

  // ─── Text Theme ──────────────────────────────────────────────────────────────
  //
  // Fredoka One for display/hero text (rounded, playful, high impact).
  // Nunito for all body/label/caption text (rounded, legible, warm).

  static TextTheme get _textTheme => TextTheme(
        // ── Display (Fredoka One) ─────────────────────────────────────────────
        displayLarge: GoogleFonts.fredoka(
          fontSize: AppConstants.fontSizeHero,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightHeading,
        ),
        displayMedium: GoogleFonts.fredoka(
          fontSize: AppConstants.fontSizeDisplay,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightHeading,
        ),
        displaySmall: GoogleFonts.fredoka(
          fontSize: AppConstants.fontSizeHeading,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightHeading,
        ),

        // ── Headlines (Nunito Bold) ───────────────────────────────────────────
        headlineLarge: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeHeading,
          fontWeight: FontWeight.w800,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightHeading,
        ),
        headlineMedium: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeTitle,
          fontWeight: FontWeight.w700,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightHeading,
        ),
        headlineSmall: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBodyLarge,
          fontWeight: FontWeight.w700,
          color: AppConstants.deepIndigo,
        ),

        // ── Titles (Nunito SemiBold) ──────────────────────────────────────────
        titleLarge: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBodyLarge,
          fontWeight: FontWeight.w700,
          color: AppConstants.deepIndigo,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w600,
          color: AppConstants.deepIndigo,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: AppConstants.mutedIndigo,
        ),

        // ── Body (Nunito Regular / Medium) ────────────────────────────────────
        bodyLarge: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBodyLarge,
          fontWeight: FontWeight.w500,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightBody,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w400,
          color: AppConstants.deepIndigo,
          height: AppConstants.lineHeightBody,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeCaption,
          fontWeight: FontWeight.w400,
          color: AppConstants.mutedIndigo,
          height: AppConstants.lineHeightBody,
        ),

        // ── Labels (Nunito ExtraBold — for buttons and prominent interactive) ─
        labelLarge: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBodyLarge,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w700,
          color: AppConstants.deepIndigo,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: AppConstants.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: AppConstants.mutedIndigo,
          letterSpacing: 0.5,
        ),
      );

  // ─── Card Theme ──────────────────────────────────────────────────────────────

  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(AppConstants.radiusLG),
      ),
    ),
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  );

  // ─── Button Themes ───────────────────────────────────────────────────────────

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryCoral,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          minimumSize: const Size(
            AppConstants.minTouchTarget * 3,
            AppConstants.minTouchTarget,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: AppConstants.fontSizeBodyLarge,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXL,
            vertical: AppConstants.spacingMD,
          ),
        ),
      );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppConstants.primaryCoral,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          minimumSize: const Size(
            AppConstants.minTouchTarget,
            AppConstants.minTouchTarget,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: AppConstants.fontSizeBodyLarge,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXL,
            vertical: AppConstants.spacingMD,
          ),
        ),
      );

  // ─── Gradient Helpers ────────────────────────────────────────────────────────

  /// Returns a [LinearGradient] from a list of [Color] stops.
  ///
  /// Orientation: top-left to bottom-right for warmth and visual depth.
  static LinearGradient backgroundGradient(List<Color> stops) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: stops,
      );

  /// Multi-stop warm gradient for the CTA button surface.
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF6B4A), // primaryCoral
      Color(0xFFFF8E6E), // lighter coral
    ],
  );

  // ─── Shadow Helpers ──────────────────────────────────────────────────────────

  /// Soft, multi-layer coloured card shadow.
  ///
  /// [tintColor] should match or complement the card's dominant color.
  /// [opacity] controls the tint intensity — keep ≤ 0.20 for subtlety.
  static List<BoxShadow> cardShadow({
    Color tintColor = AppConstants.primaryCoral,
    double opacity = 0.15,
  }) =>
      [
        BoxShadow(
          color: tintColor.withAlpha((opacity * 255).round()),
          blurRadius: AppConstants.shadowBlurRadius,
          spreadRadius: AppConstants.shadowSpreadRadius,
          offset: AppConstants.shadowOffset,
        ),
        BoxShadow(
          color: Colors.black.withAlpha(10), // ~0.04 opacity
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Emotion-reactive buddy glow — a coloured radial halo.
  ///
  /// [color]      — derived from the current [BuddyEmotion].
  /// [blurRadius] — increase for celebration state (32→48).
  static List<BoxShadow> buddyGlow({
    required Color color,
    double opacity = 0.35,
    double blurRadius = 32.0,
  }) =>
      [
        BoxShadow(
          color: color.withAlpha((opacity * 255).round()),
          blurRadius: blurRadius,
          spreadRadius: 4,
          offset: Offset.zero,
        ),
      ];

  // ─── Gradient Helpers for Buddy Container ────────────────────────────────────

  /// Diagonal gradient applied to the buddy's circular container.
  ///
  /// [primaryColor] is the emotion-specific accent. The gradient lightens
  /// toward the top-left for a natural, lit feel.
  static LinearGradient buddyContainerGradient(Color primaryColor) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withAlpha(230), // ~0.9 opacity
          primaryColor.withAlpha(153), // ~0.6 opacity
        ],
      );
}
