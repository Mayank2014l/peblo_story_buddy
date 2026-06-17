// lib/widgets/quiz_card.dart
//
// Peblo — Comprehension Quiz Card Renderer
//
// ARCHITECTURE:
//   - Consumes currentQuizProvider, selectedOptionIndexProvider, and storyStatusProvider.
//   - Uses AnimatedSwitcher to cross-fade between questions and the success overlay.
//   - Confetti controller and widgets are self-contained here, keeping the shell thin.
//   - Built with strict performance guidelines: RepaintBoundary around each option
//     and the confetti layer, no setState in production tree beyond animation states.
//
// ANIMATIONS:
//   - Card Entrance: Fade + Slide Up + Scale (curves: Curves.easeOutBack, 600ms)
//   - Option Pressed: 3D mechanical press down (offset 4px) and scale feedback.
//   - Correct Answer: Continuous scale pulse (1.0 -> 1.04 -> 1.0) while success is active.
//   - Confetti: Top-center downwards emission using a child-friendly multi-color palette.
//   - Stars Reveal: Elastic scaling of stars in sequence (100ms offset delay).
//   - Sparkle Particles: Positioned drift-and-fade loop using flutter_animate.
//
// ACCESSIBILITY:
//   - WCAG AA compliant contrast ratio, minimum 16sp font sizes.
//   - Semantics labels configured on all interactive buttons and stars.
//   - Touch targets designed to meet the 48x48dp minimum standard.

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../animations/shake_animation.dart';
import '../animations/success_animation.dart';
import '../models/quiz_model.dart';
import '../providers/providers.dart';
import '../providers/story_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Interactive quiz card showing questions, option buttons, and success celebration.
class QuizCard extends ConsumerStatefulWidget {
  const QuizCard({super.key});

  @override
  ConsumerState<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends ConsumerState<QuizCard>
    with TickerProviderStateMixin, ShakeAnimationMixin, SuccessAnimationMixin {
  
  late final ConfettiController _confettiController;
  int _shakingOptionIndex = -1;

  @override
  void initState() {
    super.initState();
    initShakeAnimation(vsync: this);
    initSuccessAnimation(vsync: this);
    _confettiController = ConfettiController(duration: AppConstants.confettiDuration);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    disposeShakeAnimation();
    disposeSuccessAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuizModel? quiz = ref.watch(currentQuizProvider);
    final int? selectedIndex = ref.watch(selectedOptionIndexProvider);
    final StoryState status = ref.watch(storyStatusProvider);
    final int streak = ref.watch(streakProvider);

    // Guard: no quiz loaded
    if (quiz == null) return const SizedBox.shrink();

    // Listen for state transitions to drive haptics, shake, and confetti
    ref.listen<StoryState>(storyStatusProvider, (previous, next) {
      if (next == StoryState.wrongAnswer && selectedIndex != null) {
        setState(() => _shakingOptionIndex = selectedIndex);
        triggerShake();
        HapticFeedback.mediumImpact();
      } else if (next == StoryState.success) {
        setState(() => _shakingOptionIndex = -1);
        _confettiController.play();
        triggerSuccess();
        HapticFeedback.lightImpact();
      } else if (next == StoryState.quizVisible) {
        setState(() => _shakingOptionIndex = -1);
      }
    });

    final bool isSuccess = status == StoryState.success;

    // Outer stack handles main card content, confetti, and floating sparkles
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // ── Main Card Container ─────────────────────────────────────────────
        Container(
          height: double.infinity,
          padding: const EdgeInsets.all(AppConstants.spacingLG),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            boxShadow: AppTheme.cardShadow(
              tintColor: isSuccess ? AppConstants.softMint : AppConstants.skyBlue,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: isSuccess
                        ? _buildSuccessOverlay(context, ref, streak)
                        : _buildQuizContent(context, ref, quiz, status, selectedIndex),
                  ),
                ),
              ),
              
              // Floating decorative stars drift during success
              if (isSuccess) ..._buildFloatingParticles(),
            ],
          ),
        ),

        // ── Confetti Particle Layer ──────────────────────────────────────────
        RepaintBoundary(
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.12,
            numberOfParticles: 35,
            maxBlastForce: 12,
            minBlastForce: 4,
            gravity: 0.25,
            colors: const [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.cyan,
            ],
            shouldLoop: false,
          ),
        ),
      ],
    );
  }

  // ─── Quiz View Builder ─────────────────────────────────────────────────────

  Widget _buildQuizContent(
    BuildContext context,
    WidgetRef ref,
    QuizModel quiz,
    StoryState status,
    int? selectedIndex,
  ) {
    final bool canSelect = status == StoryState.quizVisible || status == StoryState.wrongAnswer;

    return Column(
      key: const ValueKey('quiz_question_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Label
        Text(
          AppConstants.quizHeadline,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppConstants.primaryCoral,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppConstants.spacingXS),
        
        // Question text
        Text(
          quiz.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppConstants.deepIndigo,
                fontSize: AppConstants.fontSizeBodyLarge + 2,
                fontWeight: FontWeight.w700,
              ),
        ),

        // Empathetic wrong answer banner
        if (status == StoryState.wrongAnswer) ...[
          const SizedBox(height: AppConstants.spacingMD),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMD,
              vertical: AppConstants.spacingSM,
            ),
            decoration: BoxDecoration(
              color: AppConstants.errorSoft.withAlpha(30),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Row(
              children: [
                const Text('🙈', style: TextStyle(fontSize: 20)),
                const SizedBox(width: AppConstants.spacingSM),
                Expanded(
                  child: Text(
                    AppConstants.wrongAnswerMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppConstants.deepIndigo,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppConstants.spacingLG),

        // Dynamic Answer Option List (supports 3, 4, or 5 options)
        ...List.generate(quiz.options.length, (int index) {
          final QuizOption option = quiz.options[index];
          final Color pastelColor = AppConstants.quizOptionColors[
              index % AppConstants.quizOptionColors.length];
          final bool isSelected = selectedIndex == index;
          final bool isShaking = _shakingOptionIndex == index;

          Widget optionButton = RepaintBoundary(
            child: _QuizOptionButton(
              key: ValueKey('option_btn_${quiz.id}_$index'),
              option: option,
              pastelColor: pastelColor,
              index: index,
              isSelected: isSelected,
              isCorrect: quiz.correctOptionIndex == index,
              status: status,
              onTap: canSelect
                  ? () {
                      ref.read(storyNotifierProvider.notifier).selectAnswer(index);
                    }
                  : null,
            ),
          );

          if (isShaking) {
            optionButton = ShakeAnimation(
              shakeValue: shakeAnimation,
              child: optionButton,
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingMD),
            child: optionButton,
          );
        }),
      ],
    );
  }

  // ─── Success View Overlay Builder ──────────────────────────────────────────

  Widget _buildSuccessOverlay(BuildContext context, WidgetRef ref, int streak) {
    return Column(
      key: const ValueKey('quiz_success_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppConstants.spacingMD),
        // Bouncing illustrated trophy badge with drop shadows and gold glow
        Center(
          child: SuccessAnimation(
            scaleValue: successAnimation,
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacingLG),
              decoration: BoxDecoration(
                color: AppConstants.sunnyYellow.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppConstants.sunnyYellow,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.sunnyYellow.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 3,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text('🏆', style: TextStyle(fontSize: 64)),
            ),
          ),
        ),
        
        const SizedBox(height: AppConstants.spacingLG),

        // Congratulatory Headline
        Text(
          AppConstants.correctAnswerMessage,
          style: GoogleFonts.fredoka(
            fontSize: AppConstants.fontSizeHeading + 4,
            color: AppConstants.deepIndigo,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.spacingXS),
        
        // Supportive Subtext
        Text(
          AppConstants.successSubtext,
          style: GoogleFonts.nunito(
            fontSize: AppConstants.fontSizeBodyLarge,
            color: AppConstants.mutedIndigo,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.spacingLG),
        
        // Gamified Star Progress Tracker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppConstants.backgroundLavender.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.backgroundLavender, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                'YOUR PROGRESS STARS',
                style: GoogleFonts.fredoka(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryCoral,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSM),
              // Star Progress row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) {
                    final bool isGold = i < streak;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        isGold ? '⭐' : '☆',
                        style: TextStyle(
                          fontSize: 36,
                          color: isGold ? AppConstants.sunnyYellow : AppConstants.deepIndigo.withOpacity(0.12),
                          shadows: isGold
                              ? [
                                  BoxShadow(
                                    color: AppConstants.sunnyYellow.withOpacity(0.6),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      )
                      .animate(delay: Duration(milliseconds: 100 * i))
                      .scale(
                        begin: const Offset(0.0, 0.0),
                        end: const Offset(1.0, 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppConstants.spacingXL),

        // Restart Flow CTA Button (Duolingo style)
        Semantics(
          label: AppConstants.semanticsRestartButton,
          button: true,
          child: Container(
            height: AppConstants.minTouchTarget + 6,
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppConstants.skyBlue.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(storyNotifierProvider.notifier).restartFlow();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.skyBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppConstants.spacingSM),
                  Text(
                    AppConstants.restartButtonText.toUpperCase(),
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSM),
      ],
    );
  }

  // ─── Floating sparkle stars generator ──────────────────────────────────────

  List<Widget> _buildFloatingParticles() {
    return [
      Positioned(
        left: -20,
        top: 10,
        child: const Text('✨', style: TextStyle(fontSize: 24))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.3, end: -0.5, duration: const Duration(seconds: 3))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(seconds: 3)),
      ),
      Positioned(
        right: -20,
        top: 50,
        child: const Text('🎈', style: TextStyle(fontSize: 28))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.2, end: -0.7, duration: const Duration(milliseconds: 3200))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(milliseconds: 3200)),
      ),
      Positioned(
        left: 20,
        bottom: -20,
        child: const Text('⭐', style: TextStyle(fontSize: 22))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.2, end: -0.4, duration: const Duration(seconds: 4))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(seconds: 4)),
      ),
      Positioned(
        right: 30,
        bottom: 20,
        child: const Text('🎉', style: TextStyle(fontSize: 24))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.4, end: -0.3, duration: const Duration(milliseconds: 3500))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(milliseconds: 3500)),
      ),
      Positioned(
        left: -10,
        top: 180,
        child: const Text('🌈', style: TextStyle(fontSize: 26))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.2, end: -0.6, duration: const Duration(seconds: 5))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(seconds: 5)),
      ),
      Positioned(
        right: -5,
        top: 220,
        child: const Text('✨', style: TextStyle(fontSize: 20))
            .animate(onPlay: (c) => c.repeat())
            .slideY(begin: 0.3, end: -0.5, duration: const Duration(milliseconds: 2800))
            .fade(begin: 1.0, end: 0.0, duration: const Duration(milliseconds: 2800)),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _QuizOptionButton — 3D Pressable button with physical depth mechanical click
// ═══════════════════════════════════════════════════════════════════════════════

class _QuizOptionButton extends StatefulWidget {
  final QuizOption option;
  final Color pastelColor;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final StoryState status;
  final VoidCallback? onTap;

  const _QuizOptionButton({
    super.key,
    required this.option,
    required this.pastelColor,
    required this.index,
    required this.isSelected,
    required this.isCorrect,
    required this.status,
    this.onTap,
  });

  @override
  State<_QuizOptionButton> createState() => _QuizOptionButtonState();
}

class _QuizOptionButtonState extends State<_QuizOptionButton>
    with SingleTickerProviderStateMixin {
  
  late final AnimationController _pressController;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppConstants.tapFeedbackDuration, // 150ms
    );
    _pressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _pressController.forward();
      HapticFeedback.selectionClick();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _pressController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = _getSurfaceColor();
    final Color shadowColor = _getShadowColor();
    final Color borderCol = _getBorderColor();

    Widget buttonContent = AnimatedBuilder(
      animation: _pressAnim,
      builder: (context, child) {
        final double pressOffset = _pressAnim.value * 4.0;
        final double scale = 1.0 - (_pressAnim.value * 0.02);

        return Semantics(
          label: '${AppConstants.semanticsQuizOptionPrefix} ${widget.index + 1}: ${widget.option.text}',
          button: true,
          enabled: widget.onTap != null,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 3D Shadow Base
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: shadowColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      ),
                    ),
                  ),
                  // Button Surface
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4 - pressOffset,
                    top: pressOffset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMD,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        border: Border.all(
                          color: borderCol,
                          width: 2.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Pre-reader emoji support
                          Text(
                            widget.option.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: AppConstants.spacingSM),
                          
                          // Option text
                          Expanded(
                            child: Text(
                              widget.option.text,
                              style: GoogleFonts.nunito(
                                fontSize: AppConstants.fontSizeBodyLarge,
                                color: AppConstants.deepIndigo,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          // Selection icons
                          if (widget.status == StoryState.success && widget.isCorrect)
                            const Text('✅', style: TextStyle(fontSize: 22))
                          else if (widget.status == StoryState.wrongAnswer && widget.isSelected)
                            const Text('❌', style: TextStyle(fontSize: 22))
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppConstants.deepIndigo.withOpacity(0.12),
                                  width: 2.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Correct Answer Pulse (animates while celebrating state is active)
    if (widget.status == StoryState.success && widget.isCorrect) {
      buttonContent = buttonContent
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.04, 1.04),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: buttonContent,
    );
  }

  Color _getSurfaceColor() {
    if (widget.status == StoryState.success && widget.isCorrect) {
      return AppConstants.softMint;
    }
    if (widget.status == StoryState.wrongAnswer && widget.isSelected) {
      return AppConstants.errorSoft;
    }
    if (widget.isSelected) {
      return widget.pastelColor.withOpacity(0.95);
    }
    return widget.pastelColor;
  }

  Color _getShadowColor() {
    Color baseColor = widget.pastelColor;
    if (widget.status == StoryState.success && widget.isCorrect) {
      baseColor = AppConstants.softMint;
    } else if (widget.status == StoryState.wrongAnswer && widget.isSelected) {
      baseColor = AppConstants.errorSoft;
    }
    // Darken pastel color slightly for the 3D shadow bottom depth
    final hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }

  Color _getBorderColor() {
    if (widget.status == StoryState.success && widget.isCorrect) {
      return AppConstants.softMint;
    }
    if (widget.status == StoryState.wrongAnswer && widget.isSelected) {
      return AppConstants.errorSoft;
    }
    if (widget.isSelected) {
      return AppConstants.primaryCoral;
    }
    return AppConstants.deepIndigo.withOpacity(0.12);
  }
}
