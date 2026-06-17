// lib/utils/constants.dart
//
// Global design tokens and configuration for the Peblo Story Buddy feature.
//
// ARCHITECTURE NOTE:
//   This file contains ONLY primitive constants (colors, numbers, strings,
//   durations). It has zero dependencies on other Peblo files, making it
//   safe to import from any layer without creating circular dependencies.
//
//   Models, services, and providers must NOT be imported here.

import 'package:flutter/material.dart';

/// Global design tokens, copy strings, and configuration values for Peblo.
///
/// All values are compile-time constants. This class is never instantiated.
abstract final class AppConstants {
  // ─── Brand Color Palette ────────────────────────────────────────────────────
  //
  // These are the canonical Peblo colors. Never use raw hex codes in widgets —
  // always reference these named constants.

  /// Peblo primary warm coral — dominant brand color, CTAs, highlights.
  static const Color primaryCoral = Color(0xFFFF6B4A);

  /// Peblo secondary sky blue — paired with coral for energy and contrast.
  static const Color skyBlue = Color(0xFF4ABEFF);

  /// Sunny yellow — star ratings, accents, quiz highlights.
  static const Color sunnyYellow = Color(0xFFFFD740);

  /// Soft mint — success states, correct-answer feedback.
  static const Color softMint = Color(0xFFA8E6CF);

  /// Light lavender — app scaffold background; never pure white.
  static const Color backgroundLavender = Color(0xFFF5F0FF);

  /// Deep indigo — primary text color; never pure black.
  static const Color deepIndigo = Color(0xFF2D2867);

  /// Muted indigo — secondary text, captions, placeholder content.
  static const Color mutedIndigo = Color(0xFF6B6499);

  /// Soft peach — idle surfaces, gentle card tints.
  static const Color softPeach = Color(0xFFFFE5DC);

  /// Error soft red — friendly, not alarming. Child-safe error indicator.
  static const Color errorSoft = Color(0xFFFF8A80);

  // ─── Quiz Option Pastel Colors ───────────────────────────────────────────────
  //
  // Each quiz option receives a unique pastel to improve scannability for
  // young children who may not yet read fluently.

  /// Four unique pastels for quiz options A, B, C, D respectively.
  static const List<Color> quizOptionColors = [
    Color(0xFFFFE0B2), // A — Warm amber
    Color(0xFFB3E5FC), // B — Light blue
    Color(0xFFDCEDC8), // C — Pale green
    Color(0xFFF8BBD0), // D — Blush pink
  ];

  // ─── State-Based Background Gradients ───────────────────────────────────────
  //
  // These are CONST lists — Dart canonicalises them, so identical() checks in
  // Riverpod select() work correctly and avoid spurious rebuilds.

  /// Idle state: soft warm off-white to lavender.
  static const List<Color> gradientIdle = [
    Color(0xFFFFF8F5),
    Color(0xFFF5F0FF),
  ];

  /// Loading state: warm peach to pale amber.
  static const List<Color> gradientLoading = [
    Color(0xFFFFEDE8),
    Color(0xFFFFF3E0),
  ];

  /// Playing (narration active) state: light blue to soft purple.
  static const List<Color> gradientPlaying = [
    Color(0xFFE8F4FF),
    Color(0xFFEDE8FF),
  ];

  /// Quiz visible / wrong answer state: pale green to sky blue.
  static const List<Color> gradientQuiz = [
    Color(0xFFE8FFEF),
    Color(0xFFE8F4FF),
  ];

  /// Success state: mint green to sunny yellow.
  static const List<Color> gradientSuccess = [
    Color(0xFFE8FFEF),
    Color(0xFFFFF9C4),
  ];

  /// Error state: soft peach to pale red.
  static const List<Color> gradientError = [
    Color(0xFFFFEDE8),
    Color(0xFFFFF0F0),
  ];

  // ─── Spacing System ──────────────────────────────────────────────────────────
  //
  // All spacing values in logical pixels. Use these throughout — never
  // hard-code numeric padding values in widgets.

  /// 4px — tight grouping, icon-label gaps.
  static const double spacingXS = 4.0;

  /// 8px — element-level spacing.
  static const double spacingSM = 8.0;

  /// 16px — section-level spacing; minimum gutter.
  static const double spacingMD = 16.0;

  /// 24px — card internal padding; comfortable section spacing.
  static const double spacingLG = 24.0;

  /// 32px — prominent vertical rhythm; button horizontal padding.
  static const double spacingXL = 32.0;

  /// 48px — section dividers, hero padding.
  static const double spacingXXL = 48.0;

  /// 64px — top/bottom screen breathing room.
  static const double spacingXXXL = 64.0;

  // ─── Border Radius ───────────────────────────────────────────────────────────

  /// 12px — chips, tags, small badges.
  static const double radiusSM = 12.0;

  /// 16px — inner content areas, list tiles.
  static const double radiusMD = 16.0;

  /// 24px — primary content cards. The main Peblo card radius.
  static const double radiusLG = 24.0;

  /// 32px — pill-shaped buttons.
  static const double radiusButton = 32.0;

  /// 40px — buddy container. Near-circular with slight squircle feel.
  static const double radiusBuddy = 40.0;

  // ─── Typography Scale ────────────────────────────────────────────────────────

  /// 12sp — captions, fine print.
  static const double fontSizeCaption = 12.0;

  /// 16sp — body text. Minimum for readability per accessibility spec.
  static const double fontSizeBody = 16.0;

  /// 18sp — prominent body, quiz option text.
  static const double fontSizeBodyLarge = 18.0;

  /// 20sp — card titles, section labels. Minimum heading per spec.
  static const double fontSizeTitle = 20.0;

  /// 24sp — screen headings.
  static const double fontSizeHeading = 24.0;

  /// 32sp — display text; buddy speech bubble headline.
  static const double fontSizeDisplay = 32.0;

  /// 40sp — hero/celebration text.
  static const double fontSizeHero = 40.0;

  /// Body line height — 1.6 for comfortable reading at child pace.
  static const double lineHeightBody = 1.6;

  /// Heading line height — tighter for display impact.
  static const double lineHeightHeading = 1.2;

  // ─── Touch Targets ───────────────────────────────────────────────────────────

  /// Minimum 48×48dp touch target per WCAG 2.5.5 and iOS HIG.
  static const double minTouchTarget = 48.0;

  // ─── Shadow Configuration ────────────────────────────────────────────────────

  /// Soft multi-layered shadow blur radius.
  static const double shadowBlurRadius = 24.0;

  /// Shadow spread — kept at 0 for natural fall-off.
  static const double shadowSpreadRadius = 0.0;

  /// Shadow vertical offset — lifts card off background.
  static const Offset shadowOffset = Offset(0, 8);

  // ─── TTS Configuration ───────────────────────────────────────────────────────

  /// Comfortable narration speed for children aged 4–8.
  /// flutter_tts range: 0.0–1.0 (default 0.5).
  static const double ttsSpeechRate = 0.45;

  /// Slightly elevated pitch for a warm, friendly narrator voice.
  static const double ttsPitch = 1.1;

  /// Full volume by default. Never reduce without explicit user action.
  static const double ttsVolume = 1.0;

  /// American English — consistent and widely supported across TTS engines.
  static const String ttsLanguage = 'en-US';

  /// Fallback locale if en-US is not listed by the device.
  static const String ttsLanguageFallback = 'en';

  // ─── Animation Durations ─────────────────────────────────────────────────────

  /// Buddy idle float cycle: 2s up/down loop.
  static const Duration buddyIdleCycleDuration = Duration(seconds: 2);

  /// CTA button pulse breathe cycle: 1.5s.
  static const Duration ctaPulseDuration = Duration(milliseconds: 1500);

  /// Tap press feedback: 150ms snap-down.
  static const Duration tapFeedbackDuration = Duration(milliseconds: 150);

  /// Story card entrance delay after state change.
  static const Duration storyCardEntranceDelay = Duration(milliseconds: 300);

  /// Story card fade+slide entrance duration.
  static const Duration storyCardEntranceDuration = Duration(milliseconds: 500);

  /// Quiz card reveal: fade + slide + scale.
  static const Duration quizRevealDuration = Duration(milliseconds: 600);

  /// Shake animation for wrong answer: 400ms.
  static const Duration shakeAnimationDuration = Duration(milliseconds: 400);

  /// Confetti emission duration: 3s.
  static const Duration confettiDuration = Duration(seconds: 3);

  /// Success buddy bounce: 600ms elasticOut.
  static const Duration successBounceDuration = Duration(milliseconds: 600);

  /// Animated background gradient cross-fade.
  static const Duration backgroundTransitionDuration =
      Duration(milliseconds: 600);

  /// Speech bubble appearance: scale + fade.
  static const Duration speechBubbleAppearanceDuration =
      Duration(milliseconds: 300);

  /// Single waveform bar animation cycle.
  static const Duration waveformBarCycleDuration = Duration(milliseconds: 800);

  // ─── Animation Values ────────────────────────────────────────────────────────

  /// Buddy idle float distance from rest position (±8px).
  static const double buddyFloatDistance = 8.0;

  /// CTA button max scale during pulse breathe.
  static const double ctaPulseScale = 1.05;

  /// Scale factor when a tappable element is pressed.
  static const double tapPressScale = 0.92;

  /// Quiz card starting scale before reveal animation.
  static const double quizRevealStartScale = 0.95;

  /// Peak scale of buddy bounce on correct answer.
  static const double successBounceScale = 1.3;

  // ─── Layout Constraints ──────────────────────────────────────────────────────

  /// Maximum content width — ensures legible layouts on 430px+ screens.
  static const double maxContentWidth = 430.0;

  /// Minimum story card height to prevent layout collapse.
  static const double storyCardMinHeight = 200.0;

  /// Buddy widget diameter.
  static const double buddySize = 140.0;

  /// Minimum quiz option row height (48dp touch target + padding).
  static const double quizOptionHeight = 60.0;

  /// Number of waveform bars during narration visualization.
  static const int waveformBarCount = 5;

  // ─── UX Copy ─────────────────────────────────────────────────────────────────
  //
  // ALL child-facing strings live here. Never hardcode strings in widgets.
  // In a future i18n pass, this block becomes an ARB file.

  static const String appName = 'Peblo';
  static const String buddyName = 'Peblo';

  /// Primary CTA — triggers story narration.
  static const String ctaButtonText = 'Read Me A Story! 📖';

  /// Shown in the loading overlay while TTS initialises.
  static const String loadingHeadline = 'Preparing your story...';
  static const String loadingSubtext = 'Getting Peblo ready to read!';

  /// Shown in the speech bubble during active narration.
  static const String playingBubbleText = 'Peblo is reading...';

  /// Quiz section header copy.
  static const String quizHeadline = 'Quiz Time! 🧠';
  static const String quizSubtext = 'What did you learn from the story?';

  /// Wrong answer feedback — encouraging, never shaming.
  static const String wrongAnswerMessage = "Oops! Let's try again! 🙈";

  /// Correct answer celebration.
  static const String correctAnswerMessage = 'Awesome! You got it right! 🎉';

  /// Success screen headline.
  static const String successHeadline = 'Amazing Job! 🌟';
  static const String successSubtext = "You're a brilliant listener!";

  /// Restart CTA on success screen.
  static const String restartButtonText = 'Read Another Story!';

  /// Error state — friendly, never shows raw error messages to children.
  static const String ttsErrorTitle = 'Uh oh!';
  static const String ttsErrorMessage =
      'Oops! Something went wrong with the story.\nTap to try again! 🔧';
  static const String ttsErrorRetryText = 'Try Again';

  // ─── Accessibility / Semantics Labels ────────────────────────────────────────

  static const String semanticsBuddy = 'Peblo the AI story buddy character';
  static const String semanticsStoryCard = 'Story card — tap to follow along';
  static const String semanticsCtaButton = 'Read me a story — start narration';
  static const String semanticsRestartButton = 'Read another story';
  static const String semanticsQuizOptionPrefix = 'Answer option';
}
