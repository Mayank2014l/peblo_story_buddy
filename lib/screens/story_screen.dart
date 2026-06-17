// lib/screens/story_screen.dart
//
// Peblo — Primary Story Screen
//
// ARCHITECTURE:
//   StoryScreen       → ConsumerWidget (thin shell: gradient + routing only)
//   _IdleView         → StatelessWidget: buddy + teaser card + CTA
//   _CtaButton        → ConsumerStatefulWidget: pulse + press animations
//   _LoadingView      → StatelessWidget: delegates to LoadingWidget
//   _PlayingView      → StatelessWidget: buddy (reading) + StoryCard
//   _QuizView         → StatelessWidget: buddy (thinking) + QuizCard
//   _SuccessView      → ConsumerWidget: celebration + restart
//   _ErrorView        → ConsumerWidget: child-safe recovery
//
// ANIMATION PIPELINE:
//   Background → AnimatedContainer (Decoration.lerp)
//   State transitions → AnimatedSwitcher (fade + slide)
//   CTA pulse  → flutter_animate repeat(reverse:true) scale 1.0→1.05
//   CTA press  → AnimationController scale 1.0→0.92 + spring reverse
//   Story teaser → flutter_animate fade+slideY (delay: 300ms)
//
// PERFORMANCE:
//   • backgroundGradientProvider uses select() — rebuilds only on gradient change
//   • storyStatusProvider uses select() — rebuilds only on state change
//   • BuddyWidget is internally RepaintBoundary-wrapped
//   • AnimatedSwitcher clips and isolates outgoing/incoming children

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:peblo_story_buddy/models/story_content.dart';

import '../data/sample_stories.dart';
import '../providers/providers.dart';
import '../providers/story_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/buddy_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/quiz_card.dart';
import '../widgets/story_card.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// StoryScreen — root shell
// ═══════════════════════════════════════════════════════════════════════════════

/// The single entry-point screen for the Peblo Story Buddy & Quiz experience.
///
/// Owns:
///   • Animated gradient background (driven by [backgroundGradientProvider])
///   • AnimatedSwitcher for state-driven layout transitions
///   • Safe area + max-width constraint
///
/// Zero business logic lives here — all logic is in [StoryNotifier].
class StoryScreen extends ConsumerWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StoryState status = ref.watch(storyStatusProvider);
    final StoryContent? story = ref.watch(currentStoryProvider);
    final List<Color> gradient = _getThemeGradient(status, story);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedContainer(
        duration: AppConstants.backgroundTransitionDuration,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: Stack(
          children: [
            // Ambient dynamic story world background elements
            Positioned.fill(child: const _BackgroundDecorations()),
            
            // Core screen content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    transitionBuilder: _stateTransition,
                    child: KeyedSubtree(
                      key: ValueKey<StoryState>(status),
                      child: _buildStateContent(status),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getThemeGradient(StoryState status, StoryContent? story) {
    if (status == StoryState.success) {
      return AppConstants.gradientSuccess;
    }
    if (status == StoryState.error) {
      return AppConstants.gradientError;
    }
    if (story != null) {
      switch (story.id) {
        case 'peblo_story_pip_v1': // Spring Forest
          return const [Color(0xFFB2EBF2), Color(0xFFC8E6C9)]; // Ice blue sky to fresh grass green
        case 'peblo_story_sunflower_v1': // Rainy Garden
          return const [Color(0xFFCFD8DC), Color(0xFFD1C4E9)]; // Raincloud slate grey to lavender
        case 'peblo_story_dragon_v1': // Winter Glacier
          return const [Color(0xFFE0F7FA), Color(0xFFBBDEFB)]; // Glacier cyan to snow sky blue
        case 'peblo_story_ocean_v1': // Ocean floor
          return const [Color(0xFF00E5FF), Color(0xFF1A237E)]; // Seafoam cyan to deep marine indigo
      }
    }
    // Fallback/Idle gradient
    return switch (status) {
      StoryState.idle => AppConstants.gradientIdle,
      StoryState.loading => AppConstants.gradientLoading,
      StoryState.playing => AppConstants.gradientPlaying,
      StoryState.quizVisible || StoryState.wrongAnswer => AppConstants.gradientQuiz,
      StoryState.success => AppConstants.gradientSuccess,
      StoryState.error => AppConstants.gradientError,
    };
  }

  /// Fade + subtle upward slide — feels natural for content reveals.
  static Widget _stateTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  Widget _buildStateContent(StoryState status) {
    return switch (status) {
      StoryState.idle => const _IdleView(),
      StoryState.loading => const _LoadingView(),
      StoryState.playing => const _PlayingView(),
      StoryState.quizVisible || StoryState.wrongAnswer || StoryState.success => const _QuizView(),
      StoryState.error => const _ErrorView(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Idle View
// ═══════════════════════════════════════════════════════════════════════════════

Widget _buildPeakingMascotStack(Widget card, WidgetRef ref) {
  final StoryState status = ref.watch(storyStatusProvider);
  final bool showHands = status != StoryState.success;

  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      Positioned(
        top: -350,
        child: const BuddyWidget(),
      ),
      card,
      if (showHands)
        Positioned(
          top: -12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2D2867), width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 55),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2D2867), width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  )
  .animate(key: ValueKey('peaking_stack_${card.key ?? card.runtimeType}'))
  .fade(delay: 300.ms, duration: 500.ms)
  .slideY(
    begin: 0.08,
    end: 0.0,
    delay: 300.ms,
    duration: 500.ms,
    curve: Curves.easeOutCubic,
  );
}

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left: AppConstants.spacingLG,
        right: AppConstants.spacingLG,
        top: 150,
        bottom: AppConstants.spacingXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPeakingMascotStack(const _StoryTeaserCard(), ref),
          const SizedBox(height: AppConstants.spacingXL),
          const _CtaButton(),
          const SizedBox(height: AppConstants.spacingXXL),
        ],
      ),
    );
  }
}

// ─── Story Teaser Card ────────────────────────────────────────────────────────

/// Decorative pre-story card shown in idle state.
/// Shows the next queued story title and metadata chips.
class _StoryTeaserCard extends StatelessWidget {
  const _StoryTeaserCard();

  @override
  Widget build(BuildContext context) {
    // Show the first (featured) story as the teaser.
    final story = SampleStories.all.first;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        boxShadow: AppTheme.cardShadow(tintColor: story.accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(story.themeEmoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: AppConstants.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Story',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: story.accentColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      story.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingMD),

          Text(
            'Tap the button below and let Peblo read you an exciting adventure! '
            'A fun quiz waits at the end. 🌟',
            style: Theme.of(context).textTheme.bodyLarge,
          ),

          const SizedBox(height: AppConstants.spacingMD),

          // Metadata chips
          Wrap(
            spacing: AppConstants.spacingSM,
            runSpacing: AppConstants.spacingXS,
            children: const [
              _MetaChip(label: '🎧 Audio Story'),
              _MetaChip(label: '🧩 Quiz Inside'),
              _MetaChip(label: '✨ Ages 4–8'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSM,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLavender,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppConstants.mutedIndigo,
        ),
      ),
    );
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────

/// "Read Me A Story" button with:
///   • Continuous scale pulse (1.0 → 1.05 → 1.0, 1.5s, easeInOut) via flutter_animate
///   • Press feedback (scale → 0.92, spring reverse) via AnimationController
///
/// Both effects stack: total scale = pressAnim.value × pulseAnim.value
class _CtaButton extends ConsumerStatefulWidget {
  const _CtaButton();

  @override
  ConsumerState<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends ConsumerState<_CtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppConstants.tapFeedbackDuration,
    );
    _pressAnim = Tween<double>(begin: 1.0, end: AppConstants.tapPressScale)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_handling) return;
    _handling = true;
    HapticFeedback.lightImpact();
    await _pressCtrl.forward();
    ref.read(storyNotifierProvider.notifier).startStory();
    if (mounted) {
      await _pressCtrl.reverse();
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppConstants.semanticsCtaButton,
      button: true,
      child: SizedBox(
        height: AppConstants.minTouchTarget + 8, // comfortable target
        child: ScaleTransition(
          scale: _pressAnim,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => unawaited(_onTap()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryCoral,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 6,
                shadowColor: AppConstants.primaryCoral.withAlpha(100),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXL,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: AppConstants.spacingSM),
                  Text(
                    AppConstants.ctaButtonText,
                    style: GoogleFonts.fredoka(
                      fontSize: AppConstants.fontSizeBodyLarge,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
            // Continuous scale pulse via flutter_animate
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(AppConstants.ctaPulseScale, AppConstants.ctaPulseScale),
              duration: AppConstants.ctaPulseDuration,
              curve: Curves.easeInOut,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loading View
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// Loading View
// ═══════════════════════════════════════════════════════════════════════════════

class _LoadingView extends ConsumerWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = (screenHeight * 0.20).clamp(100.0, 150.0);
    final double cardHeight = (screenHeight - topPadding - 60.0).clamp(280.0, 560.0);

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLG,
        right: AppConstants.spacingLG,
        top: topPadding,
        bottom: AppConstants.spacingLG,
      ),
      child: Center(
        child: SizedBox(
          height: cardHeight,
          child: _buildPeakingMascotStack(const LoadingWidget(), ref),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Playing View
// ═══════════════════════════════════════════════════════════════════════════════

class _PlayingView extends ConsumerWidget {
  const _PlayingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = (screenHeight * 0.20).clamp(100.0, 150.0);
    final double cardHeight = (screenHeight - topPadding - 60.0).clamp(280.0, 560.0);

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLG,
        right: AppConstants.spacingLG,
        top: topPadding,
        bottom: AppConstants.spacingLG,
      ),
      child: Center(
        child: SizedBox(
          height: cardHeight,
          child: _buildPeakingMascotStack(const StoryCard(), ref),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Quiz View
// ═══════════════════════════════════════════════════════════════════════════════

class _QuizView extends ConsumerWidget {
  const _QuizView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = (screenHeight * 0.20).clamp(100.0, 150.0);
    final double cardHeight = (screenHeight - topPadding - 60.0).clamp(280.0, 560.0);

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLG,
        right: AppConstants.spacingLG,
        top: topPadding,
        bottom: AppConstants.spacingLG,
      ),
      child: Center(
        child: SizedBox(
          height: cardHeight,
          child: _buildPeakingMascotStack(const QuizCard(), ref),
        ),
      ),
    );
  }
}



// ═══════════════════════════════════════════════════════════════════════════════
// Error View
// ═══════════════════════════════════════════════════════════════════════════════

/// Child-safe error recovery. Never displays raw exception messages.
class _ErrorView extends ConsumerWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? msg = ref.watch(errorMessageProvider);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = (screenHeight * 0.20).clamp(100.0, 150.0);
    final double cardHeight = (screenHeight - topPadding - 60.0).clamp(280.0, 560.0);

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLG,
        right: AppConstants.spacingLG,
        top: topPadding,
        bottom: AppConstants.spacingLG,
      ),
      child: Center(
        child: SizedBox(
          height: cardHeight,
          child: _buildPeakingMascotStack(
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingLG),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                boxShadow: AppTheme.cardShadow(tintColor: AppConstants.errorSoft),
              ),
              child: Column(
                children: [
                  const Text('🔧', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppConstants.spacingMD),
                  Text(
                    AppConstants.ttsErrorTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingSM),
                  Text(
                    msg ?? AppConstants.ttsErrorMessage,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingLG),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(storyNotifierProvider.notifier).retryFromError(),
                    child: Text(AppConstants.ttsErrorRetryText),
                  ),
                ],
              ),
            ),
            ref,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _BackgroundDecorations — Drift clouds and twinkling stars in back
// ═══════════════════════════════════════════════════════════════════════════════

class _BackgroundDecorations extends ConsumerStatefulWidget {
  const _BackgroundDecorations();

  @override
  ConsumerState<_BackgroundDecorations> createState() => _BackgroundDecorationsState();
}

class _BackgroundDecorationsState extends ConsumerState<_BackgroundDecorations>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StoryContent? story = ref.watch(currentStoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double width = screenWidth > 0 ? screenWidth : 400.0;
    final double height = screenHeight > 0 ? screenHeight : 800.0;

    final String storyId = story?.id ?? '';

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Ambient drift clouds for all non-ocean themes
              if (storyId != 'peblo_story_ocean_v1') ...[
                Positioned(
                  top: 70,
                  child: const Text('☁️', style: TextStyle(fontSize: 80, color: Colors.white))
                      .animate(onPlay: (c) => c.repeat())
                      .moveX(begin: -100, end: width + 100, duration: 40.seconds)
                      .fade(begin: 0.15, end: 0.15),
                ),
                Positioned(
                  top: 190,
                  child: const Text('☁️', style: TextStyle(fontSize: 110, color: Colors.white))
                      .animate(onPlay: (c) => c.repeat())
                      .moveX(begin: -140, end: width + 140, duration: 60.seconds)
                      .fade(begin: 0.10, end: 0.10),
                ),
              ],
              
              // Dynamic seasonal painting layer
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _getPainterForStory(storyId, _animCtrl.value),
                  ),
                ),
              ),
              
              // Sprites for birds hovering to the left and right of the mascot
              if (storyId == 'peblo_story_pip_v1' || storyId == '') ...[
                _buildHoverBird(width, height, 0.14, 0.15, '🐦', false, 0.0), // Left Blue Bird
                _buildHoverBird(width, height, 0.26, 0.22, '🦩', false, 0.45), // Left Pink Bird
                _buildHoverBird(width, height, 0.85, 0.18, '🐤', true, 0.25), // Right Yellow Bird
                _buildHoverButterfly(width, height, 0.18, 0.35, 0.1), // Left Yellow Butterfly
                _buildHoverButterfly(width, height, 0.08, 0.45, 0.6), // Left Pink Butterfly
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHoverBird(
    double width,
    double height,
    double baseXPercent,
    double baseYPercent,
    String emoji,
    bool isFacingLeft,
    double phaseOffset,
  ) {
    final double t = (_animCtrl.value + phaseOffset) * 2 * math.pi;
    
    // Smooth figure-8 bobbing motion
    final double dx = math.cos(t) * 8;
    final double dy = math.sin(t * 2) * 10;
    
    final double x = width * baseXPercent + dx;
    final double y = height * baseYPercent + dy;
    
    final double wingFlap = math.sin(t * 15);
    
    return Positioned(
      left: x,
      top: y,
      child: Transform.scale(
        scaleX: isFacingLeft ? -1.0 : 1.0,
        scaleY: wingFlap > 0 ? 1.0 : 0.88,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28), // Larger size for visibility
        ),
      ),
    );
  }

  Widget _buildHoverButterfly(
    double width,
    double height,
    double baseXPercent,
    double baseYPercent,
    double phaseOffset,
  ) {
    final double t = (_animCtrl.value + phaseOffset) * 2 * math.pi;
    
    // Faster erratic flutter bobbing
    final double dx = math.sin(t * 3) * 6;
    final double dy = math.cos(t * 2.5) * 10;
    
    final double x = width * baseXPercent + dx;
    final double y = height * baseYPercent + dy;
    
    final double rotation = math.sin(t * 4) * 0.15;
    
    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: rotation,
        child: const Text('🦋', style: TextStyle(fontSize: 24)),
      ),
    );
  }

  CustomPainter _getPainterForStory(String storyId, double value) {
    switch (storyId) {
      case 'peblo_story_pip_v1':
        return _SpringForestPainter(value);
      case 'peblo_story_sunflower_v1':
        return _RainyGardenPainter(value);
      case 'peblo_story_dragon_v1':
        return _WinterGlacierPainter(value);
      case 'peblo_story_ocean_v1':
        return _WindyOceanPainter(value);
      default:
        return _SpringForestPainter(value); // Fallback / Idle
    }
  }
}

/// 🌲 Spring Forest Painter (Pip's Story & Idle)
class _SpringForestPainter extends CustomPainter {
  final double animValue;
  _SpringForestPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(54321);

    // 1. Draw Mountains in the background
    final mountainPaint = Paint()..color = const Color(0xFF9FA8DA).withOpacity(0.35); // Soft purple-indigo
    final mountainPath1 = Path()
      ..moveTo(0, size.height * 0.76)
      ..lineTo(size.width * 0.35, size.height * 0.50)
      ..lineTo(size.width * 0.70, size.height * 0.76)
      ..close();
    final mountainPath2 = Path()
      ..moveTo(size.width * 0.35, size.height * 0.76)
      ..lineTo(size.width * 0.72, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.76)
      ..close();
    canvas.drawPath(mountainPath1, mountainPaint);
    canvas.drawPath(mountainPath2, mountainPaint);

    // Snow caps
    final snowCapPaint = Paint()..color = Colors.white.withOpacity(0.70);
    final cap1 = Path()
      ..moveTo(size.width * 0.29, size.height * 0.54)
      ..lineTo(size.width * 0.35, size.height * 0.50)
      ..lineTo(size.width * 0.41, size.height * 0.54)
      ..close();
    final cap2 = Path()
      ..moveTo(size.width * 0.65, size.height * 0.49)
      ..lineTo(size.width * 0.72, size.height * 0.44)
      ..lineTo(size.width * 0.79, size.height * 0.49)
      ..close();
    canvas.drawPath(cap1, snowCapPaint);
    canvas.drawPath(cap2, snowCapPaint);

    // 2. Draw glowing Sun in the top-left corner
    final sunCenter = Offset(size.width * 0.08, size.height * 0.08);
    canvas.drawCircle(sunCenter, 20.0, Paint()..color = const Color(0xFFFFF176));
    final rayPaint = Paint()
      ..color = const Color(0xFFFFF176).withOpacity(0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + animValue * math.pi * 0.15;
      final start = Offset(sunCenter.dx + math.cos(angle) * 25, sunCenter.dy + math.sin(angle) * 25);
      final end = Offset(sunCenter.dx + math.cos(angle) * 36, sunCenter.dy + math.sin(angle) * 36);
      canvas.drawLine(start, end, rayPaint);
    }

    // 3. Draw Hills
    final p1 = Paint()..color = const Color(0xFF81C784).withOpacity(0.35); // Light back hill
    final p2 = Paint()..color = const Color(0xFF66BB6A).withOpacity(0.45); // Medium mid hill
    final p3 = Paint()..color = const Color(0xFF4CAF50).withOpacity(0.55); // Dark front hill
    
    final path1 = Path()
      ..moveTo(0, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.66, size.width * 0.6, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.81, size.width, size.height * 0.71)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    final path2 = Path()
      ..moveTo(0, size.height * 0.83)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.88, size.width * 0.5, size.height * 0.81)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.74, size.width, size.height * 0.83)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, p1);
    canvas.drawPath(path2, p2);

    // 4. Draw winding path (like in the reference design)
    final pathPaint = Paint()
      ..color = const Color(0xFFFFECC8)
      ..style = PaintingStyle.fill;
    final windingPath = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.90, size.width * 0.38, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.74, size.width * 0.48, size.height * 0.68)
      ..lineTo(size.width * 0.52, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.74, size.width * 0.44, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.90, size.width * 0.54, size.height)
      ..close();
    canvas.drawPath(windingPath, pathPaint);

    // 5. Waterfall & River on the right side
    final rockPaint = Paint()..color = const Color(0xFF78909C); // Slate grey rocks
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.78), 16.0, rockPaint);
    canvas.drawCircle(Offset(size.width * 0.77, size.height * 0.82), 12.0, rockPaint);
    
    // Waterfall stream
    final waterfallPaint = Paint()..color = const Color(0xFF80DEEA); // Light cyan water
    final waterPath = Path()
      ..moveTo(size.width * 0.81, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.83, size.height * 0.82, size.width * 0.82, size.height * 0.86)
      ..lineTo(size.width * 0.88, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.87, size.height * 0.82, size.width * 0.86, size.height * 0.76)
      ..close();
    canvas.drawPath(waterPath, waterfallPaint);
    
    // Waterfall foam splash
    final splashPaint = Paint()..color = Colors.white.withOpacity(0.75);
    final splashT = animValue * math.pi * 12;
    for (int i = 0; i < 3; i++) {
      final r = 5.0 + math.sin(splashT + i) * 1.5;
      canvas.drawCircle(Offset(size.width * (0.82 + i * 0.025), size.height * 0.86), r, splashPaint);
    }
    
    // River stream
    final riverPath = Path()
      ..moveTo(size.width * 0.79, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.73, size.height * 0.88, size.width * 0.68, size.height * 0.94)
      ..lineTo(size.width * 0.83, size.height * 0.96)
      ..quadraticBezierTo(size.width * 0.86, size.height * 0.90, size.width * 0.89, size.height * 0.86)
      ..close();
    canvas.drawPath(riverPath, Paint()..color = const Color(0xFF4DD0E1)); // Flowing river blue-cyan

    // Front hill
    final path3 = Path()
      ..moveTo(0, size.height * 0.90)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.82, size.width * 0.7, size.height * 0.89)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.93, size.width, size.height * 0.87)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path3, p3);

    // 6. Draw Swaying Trees on the sides (scaled up to match reference image)
    final treeSway = math.sin(animValue * math.pi * 2) * 0.025;
    
    // Left Tree (Huge oak framing the left margin)
    canvas.save();
    canvas.translate(size.width * 0.0, size.height * 0.90);
    canvas.rotate(treeSway);
    canvas.drawRect(Rect.fromLTWH(-12, -120, 24, 120), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(Offset(0, -120), 55, Paint()..color = const Color(0xFF4CAF50));
    canvas.drawCircle(Offset(-35, -150), 45, Paint()..color = const Color(0xFF388E3C));
    canvas.drawCircle(Offset(35, -145), 45, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawCircle(Offset(0, -175), 50, Paint()..color = const Color(0xFF43A047));
    canvas.restore();

    // Right Tree (Large deciduous tree framing the right margin)
    canvas.save();
    canvas.translate(size.width * 0.95, size.height * 0.92);
    canvas.rotate(-treeSway * 1.2); 
    canvas.drawRect(Rect.fromLTWH(-9, -90, 18, 90), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(Offset(0, -90), 42, Paint()..color = const Color(0xFF66BB6A));
    canvas.drawCircle(Offset(-25, -115), 32, Paint()..color = const Color(0xFF4CAF50));
    canvas.drawCircle(Offset(25, -112), 32, Paint()..color = const Color(0xFF388E3C));
    canvas.drawCircle(Offset(0, -135), 38, Paint()..color = const Color(0xFF81C784));
    canvas.restore();

    // 7. Draw Swaying Flowers in foreground
    final flowerSway = math.sin(animValue * math.pi * 2) * 0.08;
    
    void drawFlower(double x, double y, Color petalColor, double scale) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      canvas.rotate(flowerSway);
      
      // Stem
      canvas.drawLine(Offset.zero, const Offset(0, 30), Paint()..color = const Color(0xFF81C784)..strokeWidth = 3..strokeCap = StrokeCap.round);
      
      // Petals
      final petalPaint = Paint()..color = petalColor;
      for (int i = 0; i < 5; i++) {
        final angle = (i * math.pi * 2) / 5;
        final px = math.cos(angle) * 8;
        final py = math.sin(angle) * 8;
        canvas.drawCircle(Offset(px, py), 6, petalPaint);
      }
      // Center
      canvas.drawCircle(Offset.zero, 5, Paint()..color = const Color(0xFFFFD54F));
      canvas.restore();
    }

    drawFlower(size.width * 0.08, size.height * 0.94, const Color(0xFFEC407A), 1.2); 
    drawFlower(size.width * 0.22, size.height * 0.96, const Color(0xFFAB47BC), 1.0); 
    drawFlower(size.width * 0.78, size.height * 0.95, const Color(0xFFFF7043), 1.1); 
    drawFlower(size.width * 0.92, size.height * 0.93, const Color(0xFF29B6F6), 1.2); 

    // 8. Fireflies / Sparkles
    for (int i = 0; i < 8; i++) {
      final bx = rand.nextDouble() * size.width;
      final by = rand.nextDouble() * size.height * 0.6;
      final t = animValue * math.pi * 2 + i;
      final x = (bx + math.sin(t) * 15) % size.width;
      final y = (by + math.cos(t * 1.5) * 15) % size.height;
      final alpha = ((math.sin(t * 2) + 1) / 2 * 180 + 75).toInt().clamp(0, 255);
      
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = const Color(0xFFFFEE58).withAlpha(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // 9. Animated falling leaves
    final leafPaint = Paint()..color = const Color(0xFF81C784);
    final leafRng = math.Random(13579);
    for (int i = 0; i < 6; i++) {
      final double bx = leafRng.nextDouble() * size.width;
      final double by = leafRng.nextDouble() * size.height;
      
      final double y = (by + animValue * 250) % size.height;
      final double x = (bx + math.sin(animValue * 2 * math.pi * 2 + i) * 20) % size.width;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(animValue * 2 * math.pi + i);
      
      final leafPath = Path()
        ..moveTo(0, -6)
        ..quadraticBezierTo(5, 0, 0, 6)
        ..quadraticBezierTo(-5, 0, 0, -6)
        ..close();
      canvas.drawPath(leafPath, leafPaint);
      canvas.drawPath(leafPath, Paint()..color = const Color(0xFF2E7D32)..style = PaintingStyle.stroke..strokeWidth = 1.0);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpringForestPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

/// 🌧️ Rainy Garden Painter (The Little Sunflower)
class _RainyGardenPainter extends CustomPainter {
  final double animValue;
  _RainyGardenPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(12345);

    // 1. Draw glowing Rainbow in the sky
    final rainbowCenter = Offset(size.width / 2, size.height * 0.8);
    final colors = [
      const Color(0x33FF1744), // Red
      const Color(0x33FF9100), // Orange
      const Color(0x33FFEA00), // Yellow
      const Color(0x3300E676), // Green
      const Color(0x3300B0FF), // Blue
      const Color(0x33D500F9), // Violet
    ];
    for (int i = 0; i < colors.length; i++) {
      final radius = size.width * 0.45 + i * 7;
      canvas.drawArc(
        Rect.fromCircle(center: rainbowCenter, radius: radius),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
    }

    // 2. Draw Lavender/Slate Hills
    final p1 = Paint()..color = const Color(0xFF9FA8DA).withOpacity(0.35); 
    final p2 = Paint()..color = const Color(0xFFB39DDB).withOpacity(0.45); 
    final p3 = Paint()..color = const Color(0xFF7E57C2).withOpacity(0.50); 

    final path1 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.70, size.width * 0.65, size.height * 0.80)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.85, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    final path2 = Path()
      ..moveTo(0, size.height * 0.85)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.90, size.width * 0.5, size.height * 0.83)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.77, size.width, size.height * 0.86)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path3 = Path()
      ..moveTo(0, size.height * 0.91)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.84, size.width * 0.6, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.96, size.width, size.height * 0.90)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, p1);
    canvas.drawPath(path2, p2);
    canvas.drawPath(path3, p3);

    // 3. Draw Swaying Sunflowers bending with rain/wind
    final windSway = math.sin(animValue * math.pi * 2) * 0.06 - 0.04;

    void drawSunflower(double x, double y, double scale) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      canvas.rotate(windSway);
      
      // Stem
      canvas.drawLine(Offset.zero, const Offset(0, 45), Paint()..color = const Color(0xFF66BB6A)..strokeWidth = 4..strokeCap = StrokeCap.round);
      
      // Yellow petals
      final petalPaint = Paint()..color = const Color(0xFFFFD54F);
      for (int i = 0; i < 8; i++) {
        final angle = (i * math.pi * 2) / 8;
        final px = math.cos(angle) * 12;
        final py = math.sin(angle) * 12;
        canvas.drawCircle(Offset(px, py), 6, petalPaint);
      }
      // Center
      canvas.drawCircle(Offset.zero, 9, Paint()..color = const Color(0xFF5D4037));
      canvas.restore();
    }

    drawSunflower(size.width * 0.15, size.height * 0.91, 1.1);
    drawSunflower(size.width * 0.85, size.height * 0.93, 1.2);

    // 4. Draw Falling Raindrops
    final rainPaint = Paint()
      ..color = const Color(0x7F90CAF9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    for (int i = 0; i < 40; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      
      final x = (baseX - animValue * 150) % size.width;
      final y = (baseY + animValue * 600) % size.height;
      
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 20), rainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainyGardenPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

/// ❄️ Winter Glacier Painter (Dino the Friendly Dragon)
class _WinterGlacierPainter extends CustomPainter {
  final double animValue;
  _WinterGlacierPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(98765);

    // 1. Draw snow covered hills
    final p1 = Paint()..color = const Color(0xFFE0F7FA).withOpacity(0.5); 
    final p2 = Paint()..color = const Color(0xFFE1F5FE).withOpacity(0.6); 
    final p3 = Paint()..color = Colors.white.withOpacity(0.8); 

    final path1 = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.66, size.width * 0.55, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.82, size.width, size.height * 0.72)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    final path2 = Path()
      ..moveTo(0, size.height * 0.81)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.87, size.width * 0.5, size.height * 0.80)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.73, size.width, size.height * 0.82)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path3 = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.82, size.width * 0.7, size.height * 0.89)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.93, size.width, size.height * 0.86)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, p1);
    canvas.drawPath(path2, p2);
    canvas.drawPath(path3, p3);

    // 2. Draw Icicles at the top edge
    final iciclePaint = Paint()
      ..color = const Color(0x99B2EBF2)
      ..style = PaintingStyle.fill;
    
    for (double x = 0; x < size.width; x += 25) {
      final hOffset = math.sin(x * 0.1 + animValue * math.pi * 2) * 5;
      final height = 12 + hOffset;
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 12.5, height)
        ..lineTo(x + 25, 0)
        ..close();
      canvas.drawPath(p, iciclePaint);
    }

    // 3. Draw a cute snowman on the right hill
    final sx = size.width * 0.78;
    final sy = size.height * 0.84;
    
    canvas.drawCircle(Offset(sx, sy), 22, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(sx, sy), 22, Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(sx, sy - 28), 14, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(sx, sy - 28), 14, Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(sx - 4, sy - 31), 2, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(sx + 4, sy - 31), 2, Paint()..color = Colors.black);
    
    final carrot = Path()
      ..moveTo(sx, sy - 28)
      ..lineTo(sx + 9, sy - 26)
      ..lineTo(sx, sy - 25)
      ..close();
    canvas.drawPath(carrot, Paint()..color = Colors.orange);
    
    canvas.drawRect(Rect.fromLTWH(sx - 14, sy - 42, 28, 3), Paint()..color = Colors.black);
    canvas.drawRect(Rect.fromLTWH(sx - 9, sy - 52, 18, 10), Paint()..color = Colors.black);

    // 4. Draw Snowflakes falling down
    final snowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < 40; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final sizeRadius = rand.nextDouble() * 3 + 1.5;
      final opacity = rand.nextDouble() * 0.6 + 0.4;
      
      final x = (baseX + math.sin(animValue * math.pi * 2 + i) * 12) % size.width;
      final y = (baseY + animValue * 240) % size.height;
      
      canvas.drawCircle(Offset(x, y), sizeRadius, snowPaint..color = Colors.white.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _WinterGlacierPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

/// 🐠 Windy Ocean Painter (Coral's Ocean Adventure)
class _WindyOceanPainter extends CustomPainter {
  final double animValue;
  _WindyOceanPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(13579);

    // 1. Draw God Rays (light shafts) moving across the background
    final rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < 3; i++) {
      final rx = (size.width * 0.3 * i + animValue * 60) % size.width;
      final path = Path()
        ..moveTo(rx, 0)
        ..lineTo(rx + 45, 0)
        ..lineTo(rx + 140, size.height)
        ..lineTo(rx + 20, size.height)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // 2. Sandy Sea Bed
    final bedPaint = Paint()..color = const Color(0xFFFFE082); 
    final bedPath = Path()
      ..moveTo(0, size.height * 0.90)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.85, size.width * 0.6, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.95, size.width, size.height * 0.88)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bedPath, bedPaint);

    // 3. Swaying Seaweed / Kelp
    final kelpPaint = Paint()
      ..color = const Color(0xFF1B5E20).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final bx = (i * size.width * 0.13) + 20;
      final path = Path();
      path.moveTo(bx, size.height);
      
      for (double y = size.height; y > size.height * 0.68; y -= 15) {
        final sway = math.sin((animValue * math.pi * 2) + (y * 0.015) + i) * 12;
        path.lineTo(bx + sway, y);
      }
      canvas.drawPath(path, kelpPaint);
    }

    // 4. Swimming Fish
    for (int i = 0; i < 4; i++) {
      final startOffset = rand.nextDouble() * size.width;
      final fishX = (startOffset + animValue * (size.width + 120)) % (size.width + 120) - 60;
      final fishY = size.height * 0.15 + (rand.nextDouble() * size.height * 0.6);
      final tailFlap = math.sin(animValue * math.pi * 18 + i) * 3;
      
      canvas.save();
      canvas.translate(fishX, fishY);
      
      final fishColor = i % 3 == 0 
          ? const Color(0xFFFF7043) 
          : (i % 3 == 1 ? const Color(0xFFFFCA28) : const Color(0xFFEC407A));
          
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 15),
        Paint()..color = fishColor,
      );
      final tail = Path()
        ..moveTo(-11, 0)
        ..lineTo(-20, -7 + tailFlap)
        ..lineTo(-20, 7 - tailFlap)
        ..close();
      canvas.drawPath(tail, Paint()..color = fishColor);
      canvas.drawCircle(const Offset(7, -2), 2, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(7, -2), 0.8, Paint()..color = Colors.black);
      
      canvas.restore();
    }

    // 5. Rising Water Bubbles
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    for (int i = 0; i < 15; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 5 + 3.0;
      
      final x = (baseX + math.sin(animValue * math.pi * 4 + i) * 8) % size.width;
      final y = (baseY - animValue * 450) % size.height;
      
      canvas.drawCircle(Offset(x, y), radius, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindyOceanPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}
