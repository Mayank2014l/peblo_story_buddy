// lib/widgets/buddy_widget.dart
//
// Peblo AI Story Buddy — Pip the Animated Robot Character.
//
// ARCHITECTURE:
//   BuddyWidget            → ConsumerStatefulWidget; subscribes to buddyEmotionProvider
//   _BuddyWidgetState      → Owns 11 AnimationControllers, zero setState() calls
//   _BuddyPainter          → CustomPainter; draws Pip entirely in code (no assets)
//   _WaveformPainter       → 5-bar animated waveform inside speech bubble
//   _SparkleParticlePainter→ Deterministic particle system for celebrating state
//   _SpeechBubble          → Floating rounded bubble with waveform + text
//
// PERFORMANCE:
//   • Outer RepaintBoundary isolates the whole buddy layer
//   • Inner RepaintBoundary isolates the particle layer
//   • Listenable.merge() drives one AnimatedBuilder for the main canvas
//   • shouldRepaint() compares all fields; no redundant paints
//   • 11 controllers properly disposed; Timer cancelled on dispose
//   • Zero setState() — plain fields read by AnimatedBuilder on each tick

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/providers.dart';
import '../providers/story_provider.dart';
import '../utils/constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// §1 — Eye Style Enum
// ═══════════════════════════════════════════════════════════════════════════════

enum _EyeStyle {
  normal,     // circles, centred pupils
  scanning,   // circles, pupils animate left-right
  lookingUp,  // circles, pupils shifted upward
  sad,        // downward arc + drooping brow + teardrop
  stars,      // 5-point star shapes — delighted
}

// ═══════════════════════════════════════════════════════════════════════════════
// §2 — Emotion Parameters (lerp-able value object)
// ═══════════════════════════════════════════════════════════════════════════════

@immutable
class _EmotionParams {
  final double headTilt;       // radians (+ve = clockwise)
  final double leanY;          // vertical lean in pixels (+ve = forward/down)
  final double droop;          // overall droop offset in pixels
  final double glowIntensity;  // 0.0–1.0 base multiplier
  final Color glowColor;
  final Color accentColor;     // antenna ball + cheek bolts + chest panel
  final _EyeStyle eyeStyle;
  final bool showSpeechBubble;
  final bool showParticles;
  final bool showQuestionMark;

  const _EmotionParams({
    required this.headTilt,
    required this.leanY,
    required this.droop,
    required this.glowIntensity,
    required this.glowColor,
    required this.accentColor,
    required this.eyeStyle,
    this.showSpeechBubble = false,
    this.showParticles = false,
    this.showQuestionMark = false,
  });

  /// Linearly interpolates all numeric fields; switches discrete values at t=0.5.
  static _EmotionParams lerp(_EmotionParams a, _EmotionParams b, double t) {
    final double tt = t.clamp(0.0, 1.0);
    return _EmotionParams(
      headTilt: a.headTilt + (b.headTilt - a.headTilt) * tt,
      leanY: a.leanY + (b.leanY - a.leanY) * tt,
      droop: a.droop + (b.droop - a.droop) * tt,
      glowIntensity: a.glowIntensity + (b.glowIntensity - a.glowIntensity) * tt,
      glowColor: Color.lerp(a.glowColor, b.glowColor, tt) ?? b.glowColor,
      accentColor: Color.lerp(a.accentColor, b.accentColor, tt) ?? b.accentColor,
      eyeStyle: tt < 0.5 ? a.eyeStyle : b.eyeStyle,
      showSpeechBubble: tt > 0.5 ? b.showSpeechBubble : a.showSpeechBubble,
      showParticles: tt > 0.5 ? b.showParticles : a.showParticles,
      showQuestionMark: tt > 0.5 ? b.showQuestionMark : a.showQuestionMark,
    );
  }
}

/// Pre-defined [_EmotionParams] for each [BuddyEmotion].
abstract final class _Presets {
  static const _EmotionParams idle = _EmotionParams(
    headTilt: 0.0, leanY: 0.0, droop: 0.0,
    glowIntensity: 0.40, glowColor: AppConstants.skyBlue,
    accentColor: AppConstants.primaryCoral, eyeStyle: _EyeStyle.normal,
    showParticles: true,
  );
  static const _EmotionParams thinking = _EmotionParams(
    headTilt: 0.18, leanY: 0.0, droop: 0.0,
    glowIntensity: 0.60, glowColor: AppConstants.sunnyYellow,
    accentColor: AppConstants.sunnyYellow, eyeStyle: _EyeStyle.lookingUp,
    showQuestionMark: true,
    showParticles: true,
  );
  static const _EmotionParams reading = _EmotionParams(
    headTilt: 0.0, leanY: 7.0, droop: 0.0,
    glowIntensity: 0.50, glowColor: AppConstants.primaryCoral,
    accentColor: AppConstants.primaryCoral, eyeStyle: _EyeStyle.scanning,
    showSpeechBubble: true,
  );
  static const _EmotionParams celebrating = _EmotionParams(
    headTilt: 0.0, leanY: 0.0, droop: 0.0,
    glowIntensity: 1.0, glowColor: AppConstants.softMint,
    accentColor: AppConstants.sunnyYellow, eyeStyle: _EyeStyle.stars,
    showParticles: true,
  );
  static const _EmotionParams sad = _EmotionParams(
    headTilt: 0.12, leanY: 0.0, droop: 10.0,
    glowIntensity: 0.20, glowColor: AppConstants.mutedIndigo,
    accentColor: AppConstants.mutedIndigo, eyeStyle: _EyeStyle.sad,
  );

  static _EmotionParams forEmotion(BuddyEmotion e) => switch (e) {
    BuddyEmotion.idle => idle,
    BuddyEmotion.thinking => thinking,
    BuddyEmotion.reading => reading,
    BuddyEmotion.celebrating => celebrating,
    BuddyEmotion.sad => sad,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// §3 — Sparkle Particle Data
// ═══════════════════════════════════════════════════════════════════════════════

@immutable
class _Sparkle {
  final double angle;        // radians — emission direction
  final double speed;        // max travel distance (px)
  final double size;         // base radius
  final Color color;
  final double phase;        // stagger offset (0–1)
  final double twinkleFreq;  // oscillation cycles per loop

  const _Sparkle({
    required this.angle, required this.speed, required this.size,
    required this.color, required this.phase, required this.twinkleFreq,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// §4 — BuddyWidget
// ═══════════════════════════════════════════════════════════════════════════════

/// Peblo's animated robot buddy "Pip".
///
/// Driven entirely by [BuddyEmotion] from [buddyEmotionProvider].
/// Layout (220 × 265 SizedBox scaled by 1.8):
///   ┌─── Stack ──────────────────────────────┐
///   │  [Speech bubble]        top:0–62       │
///   │  ❓ (thinking only)     top:28–42      │
///   │  [Buddy canvas]         top:65–245     │
///   │  [Particles]            Positioned.fill│
///   └────────────────────────────────────────┘
class BuddyWidget extends ConsumerStatefulWidget {
  const BuddyWidget({super.key});

  @override
  ConsumerState<BuddyWidget> createState() => _BuddyWidgetState();
}

class _BuddyWidgetState extends ConsumerState<BuddyWidget>
    with TickerProviderStateMixin {

  // ── Emotion tracking (plain fields — AnimatedBuilder reads on every tick) ──
  BuddyEmotion _currentEmotion = BuddyEmotion.idle;
  _EmotionParams _fromParams = _Presets.idle;
  _EmotionParams _toParams = _Presets.idle;

  // ── 11 AnimationControllers ────────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _transitionCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _spinCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _speechBubbleCtrl;
  late final AnimationController _questionMarkCtrl;

  // ── Derived animations ─────────────────────────────────────────────────────
  late final Animation<double> _floatAnim;
  late final Animation<double> _blinkAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _transitionAnim;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _spinAnim;
  late final Animation<double> _scanAnim;
  late final Animation<double> _speechBubbleAnim;
  late final Animation<double> _questionMarkAnim;

  // ── Blink timer ────────────────────────────────────────────────────────────
  Timer? _blinkTimer;
  final math.Random _rng = math.Random(42);

  // ── Merged listenable for the main buddy canvas ────────────────────────────
  late final Listenable _buddyListenable;

  // ── Pre-generated sparkle pool (deterministic seed) ───────────────────────
  static final List<_Sparkle> _sparkles = _buildPool();

  static const List<Color> _sparkleColors = [
    AppConstants.sunnyYellow,
    AppConstants.primaryCoral,
    AppConstants.skyBlue,
    AppConstants.softMint,
    Color(0xFFCE93D8),
    Color(0xFFFF8A80),
  ];

  static List<_Sparkle> _buildPool() {
    final r = math.Random(99);
    return List.generate(16, (i) => _Sparkle(
      angle: (i / 16.0) * 2 * math.pi + r.nextDouble() * 0.5,
      speed: 30 + r.nextDouble() * 50,
      size: 3 + r.nextDouble() * 5,
      color: _sparkleColors[i % _sparkleColors.length],
      phase: r.nextDouble(),
      twinkleFreq: 1.5 + r.nextDouble() * 2.5,
    ));
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initControllers();
    _buddyListenable = Listenable.merge([
      _floatCtrl, _blinkCtrl, _glowCtrl, _transitionCtrl,
      _bounceCtrl, _spinCtrl, _scanCtrl,
    ]);
    _floatCtrl.repeat(reverse: true);
    _glowCtrl.repeat(reverse: true);
    _scheduleBlink();
  }

  void _initControllers() {
    // 1. Float — ±8 px continuous bob
    _floatCtrl = AnimationController(vsync: this, duration: AppConstants.buddyIdleCycleDuration);
    _floatAnim = Tween<double>(
      begin: -AppConstants.buddyFloatDistance,
      end: AppConstants.buddyFloatDistance,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // 2. Blink — triggered by Timer
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _blinkAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 1.0), weight: 1),
    ]).animate(_blinkCtrl);
    _blinkCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _blinkCtrl.reset();
        _scheduleBlink();
      }
    });

    // 3. Glow pulse — continuous
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _glowAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // 4. Emotion transition — forward(from:0) on each emotion change
    _transitionCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _transitionAnim = CurvedAnimation(parent: _transitionCtrl, curve: Curves.easeInOut);

    // 5. Bounce — single play on celebrating entry
    _bounceCtrl = AnimationController(vsync: this, duration: AppConstants.successBounceDuration);
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: AppConstants.successBounceScale), weight: 40),
      TweenSequenceItem(tween: Tween(begin: AppConstants.successBounceScale, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    // 6. Spin — single 360° spin on celebrating entry
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _spinAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _spinCtrl, curve: Curves.easeInOut));

    // 7. Scan — continuous pupil x-offset during reading
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _scanAnim = Tween<double>(begin: -4.0, end: 4.0)
        .animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));

    // 8. Waveform — continuous during reading
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    // 9. Particles — continuous during celebrating/idle/thinking
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _particleCtrl.repeat();

    // 10. Speech bubble — scale 0→1 on appear, 1→0 on disappear
    _speechBubbleCtrl = AnimationController(vsync: this, duration: AppConstants.speechBubbleAppearanceDuration);
    _speechBubbleAnim = CurvedAnimation(parent: _speechBubbleCtrl, curve: Curves.easeOutBack);

    // 11. Question mark — float up/down during thinking
    _questionMarkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _questionMarkAnim = Tween<double>(begin: 0.0, end: -14.0)
        .animate(CurvedAnimation(parent: _questionMarkCtrl, curve: Curves.easeInOut));
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 1800 + _rng.nextInt(2800)),
      () { if (mounted) _blinkCtrl.forward(from: 0.0); },
    );
  }

  // ── Emotion change handler (called from ref.listen in build) ───────────────

  void _handleEmotionChange(BuddyEmotion? prev, BuddyEmotion next) {
    if (next == _currentEmotion) return;

    // Capture current lerped state as the new baseline
    _fromParams = _EmotionParams.lerp(_fromParams, _toParams, _transitionCtrl.value);
    _toParams = _Presets.forEmotion(next);
    _currentEmotion = next;
    _transitionCtrl.forward(from: 0.0);

    // Stop previous emotion's exclusive animations
    if (prev != null) {
      switch (prev) {
        case BuddyEmotion.reading:
          _scanCtrl.stop();
          _waveCtrl.stop();
          _speechBubbleCtrl.reverse();
        case BuddyEmotion.thinking:
          _questionMarkCtrl.stop();
        case BuddyEmotion.celebrating:
          // Keep particleCtrl running as it acts as ambient particles now
          break;
        case BuddyEmotion.idle:
        case BuddyEmotion.sad:
          break;
      }
    }

    // Start new emotion's exclusive animations
    switch (next) {
      case BuddyEmotion.reading:
        _scanCtrl.repeat(reverse: true);
        _waveCtrl.repeat();
        _speechBubbleCtrl.forward();
      case BuddyEmotion.thinking:
        _questionMarkCtrl.repeat(reverse: true);
      case BuddyEmotion.celebrating:
        _bounceCtrl.forward(from: 0.0);
        _spinCtrl.forward(from: 0.0);
      case BuddyEmotion.idle:
      case BuddyEmotion.sad:
        break;
    }
  }

  /// Current interpolated params — read by AnimatedBuilder on every tick.
  _EmotionParams get _current =>
      _EmotionParams.lerp(_fromParams, _toParams, _transitionAnim.value);

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _blinkTimer?.cancel();
    for (final c in [
      _floatCtrl, _blinkCtrl, _glowCtrl, _transitionCtrl, _bounceCtrl,
      _spinCtrl, _scanCtrl, _waveCtrl, _particleCtrl,
      _speechBubbleCtrl, _questionMarkCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<BuddyEmotion>(buddyEmotionProvider, _handleEmotionChange);

    final bool isCelebrating = _currentEmotion == BuddyEmotion.celebrating;
    final double waveVal = isCelebrating ? _particleCtrl.value : _floatCtrl.value;

    return Semantics(
      label: AppConstants.semanticsBuddy,
      child: RepaintBoundary(
        child: SizedBox(
          width: 396, // Scaled by 1.8 (220 * 1.8)
          height: 477, // Scaled by 1.8 (265 * 1.8)
          child: Center(
            child: Transform.scale(
              scale: 1.8,
              alignment: Alignment.center,
              child: SizedBox(
                width: 220,
                height: 265,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── L1: Sparkle particles (ambient & celebratory) ──────────
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_particleCtrl, _floatCtrl]),
                          builder: (_, __) {
                            if (!_current.showParticles) return const SizedBox.shrink();
                            return CustomPaint(
                              painter: _SparkleParticlePainter(
                                progress: waveVal,
                                sparkles: _sparkles,
                                emitCenter: const Offset(110, 135),
                                speedMultiplier: isCelebrating ? 1.0 : 0.35,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── L2: Buddy canvas ──────────────────────────────────────────
                    Positioned(
                      top: 65, left: 30, right: 30,
                      child: AnimatedBuilder(
                        animation: _buddyListenable,
                        builder: (_, __) {
                          final p = _current;
                          return Transform.translate(
                            offset: Offset(0, _floatAnim.value + p.droop),
                            child: Transform.scale(
                              scale: _bounceAnim.value,
                              child: Transform.rotate(
                                angle: _spinCtrl.isAnimating ? _spinAnim.value : 0.0,
                                child: CustomPaint(
                                  painter: _BuddyPainter(
                                    headTilt: p.headTilt,
                                    leanY: p.leanY,
                                    glowIntensity: (p.glowIntensity * _glowAnim.value).clamp(0.0, 1.0),
                                    glowColor: p.glowColor,
                                    accentColor: p.accentColor,
                                    eyeStyle: p.eyeStyle,
                                    blinkFactor: _blinkAnim.value,
                                    scanOffset: p.eyeStyle == _EyeStyle.scanning ? _scanAnim.value : 0.0,
                                    emotion: _currentEmotion,
                                    waveProgress: waveVal,
                                  ),
                                  size: const Size(160, 180),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── L3: Speech bubble (scale in/out) ──────────────────────────
                    Positioned(
                      top: -15, left: 15, right: 15,
                      child: AnimatedBuilder(
                        animation: _speechBubbleAnim,
                        builder: (_, child) {
                          final scale = _speechBubbleAnim.value;
                          if (scale < 0.01) return const SizedBox.shrink();
                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          );
                        },
                        child: _SpeechBubble(waveCtrl: _waveCtrl),
                      ),
                    ),

                    // ── L4: Question mark particle (thinking) ─────────────────────
                    Positioned(
                      top: -10, right: 30,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_transitionCtrl, _questionMarkCtrl]),
                        builder: (_, child) {
                          final p = _current;
                          if (!p.showQuestionMark) return const SizedBox.shrink();
                          return Transform.translate(
                            offset: Offset(0, 42 + _questionMarkAnim.value),
                            child: Opacity(
                              opacity: _transitionAnim.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: const Text('❓', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §5 — _BuddyPainter (Pip Robot — chibi visual character design)
// ═══════════════════════════════════════════════════════════════════════════════

class _BuddyPainter extends CustomPainter {
  final double headTilt;       // radians
  final double leanY;          // px forward lean
  final double glowIntensity;  // 0–1 (already multiplied by pulse)
  final Color glowColor;
  final Color accentColor;
  final _EyeStyle eyeStyle;
  final double blinkFactor;    // 1.0=open 0.05=closed
  final double scanOffset;     // pupil x-shift
  final BuddyEmotion emotion;
  final double waveProgress;

  _BuddyPainter({
    required this.headTilt,
    required this.leanY,
    required this.glowIntensity,
    required this.glowColor,
    required this.accentColor,
    required this.eyeStyle,
    required this.blinkFactor,
    required this.scanOffset,
    required this.emotion,
    required this.waveProgress,
  });

  // ── Proportions (canvas: 160×180) ──────────────────────────────
  static const double _cx       = 80.0;  // canvas center x
  static const double _hcy      = 82.0;  // head center y
  static const double _hr       = 48.0;  // Head radius
  
  static const double _eyeY     = _hcy - 15;
  static const double _mouthY   = _hcy + 22;
  static const double _mouthW   = 22.0;
  
  static const double _bodyTop  = _hcy + _hr - 12; // overlaps head slightly
  static const double _bodyW    = 46.0;            
  static const double _bodyH    = 36.0;            
  static const double _bodyBot  = _bodyTop + _bodyH;
  
  static const double _armW     = 10.0;
  static const double _armH     = 26.0;

  // Rich charcoal-navy outline paint style for premium look
  Paint get _outlinePaint => Paint()
    ..color = const Color(0xFF221F52)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, leanY);

    _drawGlow(canvas);
    _drawBody(canvas);
    _drawArms(canvas);

    // Head tilt applies to head, eyes, face, nose, whiskers, mouth
    canvas.save();
    canvas.translate(_cx, _hcy);
    canvas.rotate(headTilt);
    canvas.translate(-_cx, -_hcy);
    
    _drawHead(canvas);
    _drawCheeks(canvas);
    _drawAntenna(canvas); // Keep signature, empty implementation
    _drawBolts(canvas);   // Keep signature, empty implementation
    _drawEyes(canvas);
    _drawMouth(canvas);
    
    canvas.restore();

    canvas.restore();
  }

  void _drawGlow(Canvas canvas) {
    final double r = _hr * 1.7 + glowIntensity * 24;
    const Offset c = Offset(_cx, _hcy);
    canvas.drawCircle(
      c, r,
      Paint()
        ..shader = RadialGradient(colors: [
          glowColor.withAlpha((glowIntensity * 90).round()),
          glowColor.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _drawBody(Canvas canvas) {
    final bodyBounds = Rect.fromLTRB(_cx - _bodyW / 2, _bodyTop, _cx + _bodyW / 2, _bodyBot);
    final bodyRect = RRect.fromRectAndRadius(bodyBounds, const Radius.circular(20));

    // Blue gradient body
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
      ).createShader(bodyBounds);

    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, _outlinePaint..strokeWidth = 3.5);

    // White belly (soft off-white gradient)
    final Offset bellyCenter = Offset(_cx, _bodyTop + 16);
    final bellyBounds = Rect.fromCircle(center: bellyCenter, radius: 15.0);
    final Paint bellyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFF5F5F5)],
      ).createShader(bellyBounds);

    canvas.drawCircle(bellyCenter, 15.0, bellyPaint);
    canvas.drawCircle(bellyCenter, 15.0, _outlinePaint..strokeWidth = 2.5);

    // Pocket (half-circle)
    final pocketPath = Path()
      ..addArc(Rect.fromCircle(center: bellyCenter, radius: 10.0), 0, math.pi);
    canvas.drawPath(pocketPath, Paint()..color = Colors.white);
    canvas.drawPath(pocketPath, _outlinePaint..strokeWidth = 2.5);
    canvas.drawLine(
      Offset(bellyCenter.dx - 10.0, bellyCenter.dy),
      Offset(bellyCenter.dx + 10.0, bellyCenter.dy),
      _outlinePaint..strokeWidth = 2.5,
    );

    // Red gradient collar
    final collarBounds = Rect.fromLTRB(_cx - 18, _bodyTop - 3, _cx + 18, _bodyTop + 3);
    final collarRect = RRect.fromRectAndRadius(collarBounds, const Radius.circular(2));
    final Paint collarPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEF5350), Color(0xFFC62828)],
      ).createShader(collarBounds);

    canvas.drawRRect(collarRect, collarPaint);
    canvas.drawRRect(collarRect, _outlinePaint..strokeWidth = 2.5);

    // Golden gradient bell
    final bellCenter = Offset(_cx, _bodyTop + 4);
    final bellBounds = Rect.fromCircle(center: bellCenter, radius: 5.5);
    final Paint bellPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEE58), Color(0xFFF57F17)],
      ).createShader(bellBounds);

    canvas.drawCircle(bellCenter, 5.5, bellPaint);
    canvas.drawCircle(bellCenter, 5.5, _outlinePaint..strokeWidth = 2.2);

    // Bell details
    canvas.drawLine(
      Offset(bellCenter.dx - 5.5, bellCenter.dy - 1.0),
      Offset(bellCenter.dx + 5.5, bellCenter.dy - 1.0),
      _outlinePaint..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      Offset(bellCenter.dx, bellCenter.dy + 1.8),
      1.2,
      Paint()..color = const Color(0xFF221F52),
    );
  }

  void _drawArm(Canvas canvas, Offset joint, double angle, bool isLeft) {
    canvas.save();
    canvas.translate(joint.dx, joint.dy);
    canvas.rotate(angle);
    
    final armBounds = Rect.fromLTWH(-_armW / 2, 0, _armW, _armH);
    final Paint armPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
      ).createShader(armBounds);

    final armRect = RRect.fromRectAndRadius(armBounds, const Radius.circular(5));
    canvas.drawRRect(armRect, armPaint);
    canvas.drawRRect(armRect, _outlinePaint..strokeWidth = 3.2);
    
    // Spherical hand (white circle with soft 3D shading)
    final handCenter = Offset(0, _armH);
    final handBounds = Rect.fromCircle(center: handCenter, radius: 8.5);
    final Paint handPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.2),
        colors: [Colors.white, Color(0xFFEEEEEE)],
      ).createShader(handBounds);

    canvas.drawCircle(handCenter, 8.5, handPaint);
    canvas.drawCircle(handCenter, 8.5, _outlinePaint..strokeWidth = 3.2);
    
    // Joint Cap (navy color to look like part of outline)
    canvas.drawCircle(Offset.zero, 3.8, Paint()..color = const Color(0xFF221F52));
    
    canvas.restore();
  }

  void _drawArms(Canvas canvas) {
    double leftAngle = -0.4;
    double rightAngle = 0.4;
    
    switch (emotion) {
      case BuddyEmotion.celebrating:
        leftAngle = -2.3 + math.sin(waveProgress * 2 * math.pi) * 0.5;
        rightAngle = 2.3 + math.cos(waveProgress * 2 * math.pi) * 0.5;
      case BuddyEmotion.reading:
        leftAngle = -1.2 + math.sin(waveProgress * 2 * math.pi) * 0.1;
        rightAngle = 0.5;
      case BuddyEmotion.thinking:
        leftAngle = -2.6; 
        rightAngle = 0.2;
      case BuddyEmotion.sad:
        leftAngle = -0.15;
        rightAngle = 0.15;
      case BuddyEmotion.idle:
        leftAngle = -0.4 + math.sin(waveProgress * 2 * math.pi) * 0.08;
        rightAngle = 0.4 - math.sin(waveProgress * 2 * math.pi) * 0.08;
    }
    
    final lJoint = const Offset(_cx - _bodyW / 2 - 2, _bodyTop + 10);
    final rJoint = const Offset(_cx + _bodyW / 2 + 2, _bodyTop + 10);
    
    _drawArm(canvas, lJoint, leftAngle, true);
    _drawArm(canvas, rJoint, rightAngle, false);
  }

  void _drawHead(Canvas canvas) {
    const Offset hc = Offset(_cx, _hcy);
    final headBounds = Rect.fromCircle(center: hc, radius: _hr);

    // Blue Gradient Head
    final Paint headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
      ).createShader(headBounds);

    canvas.drawCircle(hc, _hr, headPaint);
    canvas.drawCircle(hc, _hr, _outlinePaint..strokeWidth = 3.8);
      
    // White Face Mask (with off-white radial shading)
    final faceRect = Rect.fromCenter(center: const Offset(_cx, _hcy + 4), width: _hr * 1.62, height: _hr * 1.52);
    final Paint facePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 0.8,
        colors: [Colors.white, Color(0xFFF5F5F5)],
      ).createShader(faceRect);

    canvas.drawOval(faceRect, facePaint);
    canvas.drawOval(faceRect, _outlinePaint..strokeWidth = 3.2);

    // Red Gradient Nose (glossy cartoon sphere look)
    final Offset noseCenter = Offset(_cx, _hcy - 2);
    final noseBounds = Rect.fromCircle(center: noseCenter, radius: 6.5);
    final Paint nosePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFFA5F5F), Color(0xFFD32F2F)],
      ).createShader(noseBounds);

    canvas.drawCircle(noseCenter, 6.5, nosePaint);
    canvas.drawCircle(noseCenter, 6.5, _outlinePaint..strokeWidth = 2.5);
    // nose shine reflection dot
    canvas.drawCircle(Offset(noseCenter.dx - 1.8, noseCenter.dy - 1.8), 1.5, Paint()..color = Colors.white);

    // Nose-to-mouth vertical line
    canvas.drawLine(
      Offset(_cx, noseCenter.dy + 6.5),
      const Offset(_cx, _mouthY),
      _outlinePaint..strokeWidth = 2.5,
    );

    // Whiskers (3 on each cheek, drawn with rounded caps and bold thickness)
    final whiskerPaint = _outlinePaint
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
      
    // Left Whiskers
    canvas.drawLine(const Offset(_cx - 10, _hcy + 4), const Offset(_cx - 32, _hcy - 1), whiskerPaint);
    canvas.drawLine(const Offset(_cx - 10, _hcy + 9), const Offset(_cx - 34, _hcy + 9), whiskerPaint);
    canvas.drawLine(const Offset(_cx - 10, _hcy + 14), const Offset(_cx - 32, _hcy + 19), whiskerPaint);
    
    // Right Whiskers
    canvas.drawLine(const Offset(_cx + 10, _hcy + 4), const Offset(_cx + 32, _hcy - 1), whiskerPaint);
    canvas.drawLine(const Offset(_cx + 10, _hcy + 9), const Offset(_cx + 34, _hcy + 9), whiskerPaint);
    canvas.drawLine(const Offset(_cx + 10, _hcy + 14), const Offset(_cx + 32, _hcy + 19), whiskerPaint);
  }

  void _drawCheeks(Canvas canvas) {
    // Blush is pink and soft
    final blushPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.pinkAccent.withOpacity(0.38),
          Colors.pinkAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(_cx - 24, _hcy + 12), radius: 11))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(_cx - 24, _hcy + 12), 11, blushPaint);

    final rBlushPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.pinkAccent.withOpacity(0.38),
          Colors.pinkAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(_cx + 24, _hcy + 12), radius: 11))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(_cx + 24, _hcy + 12), 11, rBlushPaint);
  }

  void _drawAntenna(Canvas canvas) {} // Empty implementation for Doraemon
  void _drawBolts(Canvas canvas) {}   // Empty implementation for Doraemon

  void _drawEyes(Canvas canvas) {
    final l = const Offset(_cx - 10, _hcy - 15);
    final r = const Offset(_cx + 10, _hcy - 15);
    switch (eyeStyle) {
      case _EyeStyle.normal:
        _doraemonEye(canvas, l, true); _doraemonEye(canvas, r, false);
      case _EyeStyle.scanning:
        _doraemonEye(canvas, l, true, dx: scanOffset * 0.8); _doraemonEye(canvas, r, false, dx: scanOffset * 0.8);
      case _EyeStyle.lookingUp:
        _doraemonEye(canvas, l, true, dy: -3.0); _doraemonEye(canvas, r, false, dy: -3.0);
      case _EyeStyle.sad:
        _sadEye(canvas, l); _sadEye(canvas, r);
      case _EyeStyle.stars:
        _starEye(canvas, l); _starEye(canvas, r);
    }
  }

  void _doraemonEye(Canvas canvas, Offset c, bool isLeft, {double dx = 0, double dy = 0}) {
    final double blink = blinkFactor.clamp(0.05, 1.0);
    // Bigger, huger eyes (width: 20, height: 26)
    final scleraRect = Rect.fromCenter(center: c, width: 20, height: 26 * blink);
    canvas.drawOval(scleraRect, Paint()..color = Colors.white);
    canvas.drawOval(scleraRect, _outlinePaint..strokeWidth = 2.5);
      
    if (blink > 0.3) {
      final double pupilX = c.dx + (isLeft ? 3.0 : -3.0) + dx;
      final double pupilY = c.dy + dy;
       final Rect pupilRect = Rect.fromCenter(
    center: Offset(pupilX, pupilY),
    width: 6 * blink,
    height: 8 * blink,
  );
      canvas.drawOval(pupilRect, Paint()..color = const Color(0xFF2D2867));
      canvas.drawCircle(Offset(pupilX - 1.0, pupilY - 2.0), 1.2 * blink, Paint()..color = Colors.white);
    }
  }

  void _sadEye(Canvas canvas, Offset c) {
    final path = Path()
      ..moveTo(c.dx - 8, c.dy + 4)
      ..quadraticBezierTo(c.dx, c.dy - 4, c.dx + 8, c.dy + 4);
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF2D2867)
      ..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round);
  }

  void _starEye(Canvas canvas, Offset c) {
    // Happy curved Doraemon eyes ( arches ^ ^ )
    final path = Path()
      ..moveTo(c.dx - 8, c.dy + 4)
      ..quadraticBezierTo(c.dx, c.dy - 4, c.dx + 8, c.dy + 4);
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF2D2867)
      ..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round);
  }

  void _drawMouth(Canvas canvas) {
    final mp = Paint()
      ..color = const Color(0xFF2D2867)
      ..style = PaintingStyle.stroke ..strokeWidth = 3.0 ..strokeCap = StrokeCap.round;
    const double mx = _cx, my = _mouthY, mw = _mouthW;
    final path = Path();
    switch (eyeStyle) {
      case _EyeStyle.sad:
        path..moveTo(mx - mw * 0.5, my + 4)
            ..quadraticBezierTo(mx, my - 4, mx + mw * 0.5, my + 4);
      case _EyeStyle.stars:
        // Wide open happy Doraemon mouth with red tongue
        final happyMouthRect = Rect.fromLTWH(mx - mw * 0.8, my - 2, mw * 1.6, mw * 1.3);
        canvas.drawArc(happyMouthRect, 0, math.pi, true, Paint()..color = const Color(0xFFE57373));
        
        // Draw tongue
canvas.drawArc(
  Rect.fromCenter(
    center: Offset(mx, my + 12),
    width: 20,
    height: 12,
  ),
  0,
  math.pi,
  true,
  Paint()..color = const Color(0xFFFF8A80),
);

// Mouth outline
canvas.drawArc(
  happyMouthRect,
  0,
  math.pi,
  false,
  mp,
);

// Smile separator
canvas.drawLine(
  Offset(mx - mw * 0.8, my - 2),
  Offset(mx + mw * 0.8, my - 2),
  mp,
);
        return;
      case _EyeStyle.lookingUp:
        path..moveTo(mx - mw * 0.4, my + 2)
            ..quadraticBezierTo(mx, my + 6, mx + mw * 0.4, my + 2);
      default:
        // Wide happy crescent smile
        path..moveTo(mx - mw * 0.8, my - 2)
            ..quadraticBezierTo(mx, my + 10, mx + mw * 0.8, my - 2);
    }
    canvas.drawPath(path, mp);
  }

  @override
  bool shouldRepaint(_BuddyPainter o) =>
      o.headTilt != headTilt || o.leanY != leanY ||
      o.glowIntensity != glowIntensity || o.glowColor != glowColor ||
      o.accentColor != accentColor || o.eyeStyle != eyeStyle ||
      o.blinkFactor != blinkFactor || o.scanOffset != scanOffset ||
      o.emotion != emotion || o.waveProgress != waveProgress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// §6 — Speech Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeechBubble extends StatelessWidget {
  final AnimationController waveCtrl;
  const _SpeechBubble({required this.waveCtrl});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryCoral.withAlpha(45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: waveCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _WaveformPainter(
                      progress: waveCtrl.value,
                      barColor: AppConstants.primaryCoral,
                    ),
                    size: const Size(76, 28),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppConstants.playingBubbleText,
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppConstants.mutedIndigo,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            painter: _TailPainter(),
            size: const Size(18, 10),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }
  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// §7 — Waveform Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _WaveformPainter extends CustomPainter {
  final double progress; // 0–1 cycling
  final Color barColor;

  static const List<double> _freqs  = [1.4, 1.9, 1.0, 1.7, 1.2];
  static const List<double> _phases = [0.0, 0.55, 1.1, 0.28, 0.82];

  const _WaveformPainter({required this.progress, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    const int bars = 5;
    final double gap = size.width * 0.08;
    final double bw = (size.width - gap * (bars - 1)) / bars;
    final double maxH = size.height * 0.88;
    final double minH = size.height * 0.18;

    for (int i = 0; i < bars; i++) {
      final double t = _freqs[i] * progress * 2 * math.pi + _phases[i] * math.pi;
      final double h = minH + (maxH - minH) * ((math.sin(t) + 1) / 2);
      final double x = i * (bw + gap);
      final double top = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(x, top, x + bw, top + h, Radius.circular(bw / 2)),
        Paint()..color = barColor,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter o) =>
      o.progress != progress || o.barColor != barColor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// §8 — Sparkle Particle Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _SparkleParticlePainter extends CustomPainter {
  final double progress;     // 0–1 cycling
  final List<_Sparkle> sparkles;
  final Offset emitCenter;
  final double speedMultiplier;

  const _SparkleParticlePainter({
    required this.progress,
    required this.sparkles,
    required this.emitCenter,
    this.speedMultiplier = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final double t = (progress + s.phase) % 1.0;
      final double opacity = t < 0.2 ? t * 5.0 : (1.0 - t) / 0.8;
      if (opacity <= 0) continue;

      final double dist = s.speed * t * speedMultiplier;
      final double px = emitCenter.dx + math.cos(s.angle) * dist;
      final double py = emitCenter.dy + math.sin(s.angle) * dist;

      final double twinkle = (math.sin(progress * s.twinkleFreq * 2 * math.pi) + 1) / 2;
      final double r = s.size * (0.5 + 0.5 * twinkle) * (1.0 - t * 0.35);
      if (r <= 0) continue;

      final Color col = s.color.withAlpha((opacity * 225).round());
      canvas.drawCircle(Offset(px, py), r, Paint()..color = col);

      if (s.size > 5.5) {
        final cross = Paint()
          ..color = col ..strokeWidth = 1.4 ..strokeCap = StrokeCap.round;
        final double cr = r * 1.7;
        canvas.drawLine(Offset(px - cr, py), Offset(px + cr, py), cross);
        canvas.drawLine(Offset(px, py - cr), Offset(px, py + cr), cross);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkleParticlePainter o) =>
      o.progress != progress || o.speedMultiplier != speedMultiplier;
}
