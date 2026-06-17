// lib/widgets/story_card.dart
//
// Peblo — Story Card Widget
//
// ARCHITECTURE:
//   - Consumes currentStoryProvider and storyStatusProvider.
//   - Houses the AnimatedStoryText reveal controller and the VoiceWaveform animator.
//   - Pure presentational shell that responds to global state changes.
//
// ANIMATIONS:
//   - Card Entrance: Fade + Slide Up (delay: 300ms, duration: 500ms, curve: Curves.easeOutCubic).
//   - Text Reveal: Word-by-word reveal in sync with TTS pace, displaying upcoming
//     words in a faded color to guide the child's eyes.
//   - Voice Waveform: 24 vertical bars animating with interactive sine wave offsets.
//   - Rotating Gear: 360-degree continuous rotation for storybook theme.
//
// ACCESSIBILITY:
//   - Mapped with high-contrast readable typography (Google Fonts Nunito, 18sp body).
//   - Semantics label 'semanticsStoryCard' wraps the entire structure.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/story_content.dart';
import '../providers/providers.dart';
import '../providers/story_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Story card displaying the active story's title, text, and waveform.
class StoryCard extends ConsumerWidget {
  const StoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StoryContent? story = ref.watch(currentStoryProvider);
    final StoryState status = ref.watch(storyStatusProvider);

    // Guard: no story loaded yet
    if (story == null) return const SizedBox.shrink();

    final bool isPlaying = status == StoryState.playing;

    // Estimate TTS reading duration based on word count:
    // Pip-speed (0.45) is roughly 1.8 words per second (~550ms per word).
    final int wordCount = story.displayText.split(' ').length;
    final Duration speechDuration = Duration(milliseconds: (wordCount * 550));

    return Semantics(
      label: AppConstants.semanticsStoryCard,
      child: Stack(
        children: [
          // Main Card Body Container
          Container(
            height: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingLG),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7), // Parchment warm paper cream
              borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              border: Border.all(
                color: const Color(0xFFE9DEC4), // Soft golden vintage line border
                width: 2.0,
              ),
              boxShadow: AppTheme.cardShadow(tintColor: story.accentColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Story Header ────────────────────────────────────────────────
                _StoryCardHeader(story: story),

                const SizedBox(height: AppConstants.spacingMD),

                // ── Animated Story Text Reveal ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: AnimatedStoryText(
                      key: ValueKey('story_text_${story.id}'),
                      text: story.displayText,
                      duration: speechDuration,
                      isPlaying: isPlaying,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacingLG),

                // ── Sound Waveform Visualizer ───────────────────────────────────
                VoiceWaveform(
                  key: ValueKey('story_waveform_${story.id}'),
                  isAnimating: isPlaying,
                  color: story.accentColor,
                ),
              ],
            ),
          ),

          // Ornate corners overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const _CornerOrnamentPainter(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _StoryCardHeader — Icon and title header with rotating gear
// ═══════════════════════════════════════════════════════════════════════════════

class _StoryCardHeader extends StatelessWidget {
  final StoryContent story;

  const _StoryCardHeader({required this.story});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Decorative top category ribbon badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: story.accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: story.accentColor.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📚', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    'STORY TIME',
                    style: GoogleFonts.fredoka(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.deepIndigo,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Playful rotating theme gear and sparkles
            Row(
              children: [
                _RotatingGear(color: story.accentColor, size: 28),
                const SizedBox(width: 8),
                const Text('✨', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMD),

        // Main Title Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Illustrated circular emoji badge with border and shadow
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: story.accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: story.accentColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: story.accentColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  story.themeEmoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMD),

            // Title text
            Expanded(
              child: Text(
                story.title,
                style: GoogleFonts.fredoka(
                  fontSize: AppConstants.fontSizeHeading + 2,
                  color: AppConstants.deepIndigo,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSM),
        Divider(color: AppConstants.deepIndigo.withOpacity(0.08), thickness: 2),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AnimatedStoryText — Synced, high-contrast progressive word reveal
// ═══════════════════════════════════════════════════════════════════════════════

class AnimatedStoryText extends StatefulWidget {
  final String text;
  final Duration duration;
  final bool isPlaying;

  const AnimatedStoryText({
    super.key,
    required this.text,
    required this.duration,
    required this.isPlaying,
  });

  @override
  State<AnimatedStoryText> createState() => _AnimatedStoryTextState();
}

class _AnimatedStoryTextState extends State<AnimatedStoryText>
    with SingleTickerProviderStateMixin {
  
  late final AnimationController _controller;
  late List<String> _words;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(' ');
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.isPlaying) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedStoryText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Complete immediately if state advances beyond active playing
    if (!widget.isPlaying && _controller.value < 1.0) {
      _controller.stop();
    } else if (widget.isPlaying && !_controller.isAnimating) {
      _controller.forward();
    }

    if (widget.text != oldWidget.text) {
      _words = widget.text.split(' ');
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TextSpan> _buildRichSpans(String text, bool isRead) {
    if (text.isEmpty) return [];
    final words = text.split(' ');
    final List<TextSpan> spans = [];

    final Color baseColor = isRead ? AppConstants.deepIndigo : AppConstants.deepIndigo.withAlpha(50);

    for (int i = 0; i < words.length; i++) {
      final wordWithPunctuation = words[i];
      final cleanWord = wordWithPunctuation.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      
      Color? wordColor;
      FontWeight fontWeight = FontWeight.w700;
      
      if (cleanWord == 'trees' || cleanWord == 'woods' || cleanWord == 'sprout' || cleanWord == 'soil' || cleanWord == 'oak') {
        wordColor = const Color(0xFF2E7D32); // Forest green
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'streams' || cleanWord == 'water' || cleanWord == 'rivers' || cleanWord == 'rain' || cleanWord == 'sparkling') {
        wordColor = const Color(0xFF0288D1); // Bright blue
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'mountains' || cleanWord == 'valley' || cleanWord == 'hills' || cleanWord == 'rocks') {
        wordColor = const Color(0xFF5E35B1); // Purple-blue
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'gear' || cleanWord == 'sunflower' || cleanWord == 'sun' || cleanWord == 'sunshine') {
        wordColor = const Color(0xFFF57C00); // Golden yellow
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'friend' || cleanWord == 'fizz' || cleanWord == 'lily' || cleanWord == 'shelly' || cleanWord == 'coral') {
        wordColor = const Color(0xFFD81B60); // Soft pink/red
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'dragon' || cleanWord == 'dino' || cleanWord == 'fire') {
        wordColor = const Color(0xFFD84315); // Red/Orange
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'bubbles' || cleanWord == 'shimmering' || cleanWord == 'shells' || cleanWord == 'treasure') {
        wordColor = const Color(0xFF00897B); // Teal
        fontWeight = FontWeight.w900;
      } else if (cleanWord == 'bee' || cleanWord == 'butterfly' || cleanWord == 'octopus' || cleanWord == 'fish') {
        wordColor = const Color(0xFF8E24AA); // Purple
        fontWeight = FontWeight.w900;
      }
      
      if (wordColor != null && !isRead) {
        wordColor = wordColor.withAlpha(80); // Faded version for upcoming text
      }

      spans.add(
        TextSpan(
          text: wordWithPunctuation + (i == words.length - 1 ? '' : ' '),
          style: TextStyle(
            color: wordColor ?? baseColor,
            fontWeight: fontWeight,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final int visibleCount = (_words.length * _controller.value).round();
        final String visibleText = _words.take(visibleCount).join(' ');
        final String remainingText = _words.skip(visibleCount).join(' ');

        return RichText(
          text: TextSpan(
            style: GoogleFonts.nunito(
              fontSize: AppConstants.fontSizeBodyLarge,
              height: AppConstants.lineHeightBody,
              fontWeight: FontWeight.w600,
            ),
            children: [
              ..._buildRichSpans(visibleText, true),
              if (remainingText.isNotEmpty) ...[
                const TextSpan(text: ' '),
                ..._buildRichSpans(remainingText, false),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VoiceWaveform — 24 bar sound visualizer
// ═══════════════════════════════════════════════════════════════════════════════

class VoiceWaveform extends StatefulWidget {
  final bool isAnimating;
  final Color color;

  const VoiceWaveform({
    super.key,
    required this.isAnimating,
    required this.color,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (int index) {
              double scale = 0.1;
              if (widget.isAnimating) {
                // Generates smooth offset sine wave bars
                final double phase = _controller.value * 2 * math.pi;
                scale = 0.15 + 0.85 * (0.5 * (math.sin(phase + index * 0.45) + 1.0));
              }

              // Variance in baseline height for a natural, premium visual structure
              final double baselineHeight = 10.0 + (index % 5) * 6.0;
              final double barHeight = baselineHeight * scale;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Container(
                  width: 4,
                  height: barHeight.clamp(4.0, 32.0),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(widget.isAnimating ? 255 : 80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _CornerOrnamentPainter — Draws gold vintage ornate brackets at the 4 corners
// ═══════════════════════════════════════════════════════════════════════════════

class _CornerOrnamentPainter extends CustomPainter {
  final Color color;
  const _CornerOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const double len = 16.0;
    const double pad = 12.0;

    // Top-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(pad, pad + len)
        ..lineTo(pad, pad)
        ..lineTo(pad + len, pad),
      paint,
    );
    // Top-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad, pad + len)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad - len, pad),
      paint,
    );
    // Bottom-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(pad, size.height - pad - len)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad + len, size.height - pad),
      paint,
    );
    // Bottom-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad, size.height - pad - len)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad - len, size.height - pad),
      paint,
    );
    
    // Tiny decorative solid gold dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(pad, pad), 3.0, dotPaint);
    canvas.drawCircle(Offset(size.width - pad, pad), 3.0, dotPaint);
    canvas.drawCircle(Offset(pad, size.height - pad), 3.0, dotPaint);
    canvas.drawCircle(Offset(size.width - pad, size.height - pad), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _RotatingGear — Vector animated gear shown in the storybook header
// ═══════════════════════════════════════════════════════════════════════════════

class _RotatingGear extends StatefulWidget {
  final Color color;
  final double size;
  const _RotatingGear({required this.color, required this.size});

  @override
  State<_RotatingGear> createState() => _RotatingGearState();
}

class _RotatingGearState extends State<_RotatingGear> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: child,
        );
      },
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _GearPainter(color: widget.color),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  final Color color;
  const _GearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.6;
    final double holeRadius = outerRadius * 0.25;

    // Center disc
    canvas.drawCircle(Offset(cx, cy), innerRadius, paint);

    // Inner hole (drawn in parchment background color for transparency effect)
    canvas.drawCircle(
      Offset(cx, cy),
      holeRadius,
      Paint()..color = const Color(0xFFFDFBF7),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      holeRadius,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Draw 8 gear teeth
    const int teethCount = 8;
    final double teethWidth = outerRadius * 0.35;

    for (int i = 0; i < teethCount; i++) {
      final double angle = (i * 2 * math.pi) / teethCount;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      
      final path = Path()
        ..moveTo(-teethWidth / 2, -innerRadius + 1)
        ..lineTo(-teethWidth * 0.75 / 2, -outerRadius)
        ..lineTo(teethWidth * 0.75 / 2, -outerRadius)
        ..lineTo(teethWidth / 2, -innerRadius + 1)
        ..close();
        
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
