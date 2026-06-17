// lib/animations/shake_animation.dart
//
// Horizontal shake animation for wrong-answer feedback.
//
// ARCHITECTURE NOTE:
//   - The AnimationController is owned and disposed by the parent widget
//     (QuizCard in Phase 2) — not here. This keeps the animation widget
//     stateless and reusable.
//   - The shake sequence mirrors real-world physics: large → diminishing
//     oscillations, ending at rest position.
//   - [ShakeAnimation.createFor()] is the factory helper used by the parent
//     to create the correctly-sequenced Animation<double>.

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Applies a horizontal shake displacement to [child].
///
/// Shake x-sequence (logical pixels):
///   0 → +10 → -10 → +8 → -8 → +5 → -5 → 0
///
/// Used for: wrong quiz answer feedback.
///
/// The parent widget is responsible for:
///   1. Creating an [AnimationController] with [vsync].
///   2. Calling [ShakeAnimation.createFor(controller)] to get [shakeValue].
///   3. Triggering [controller.forward(from: 0)] on wrong answer.
///   4. Disposing [controller] in its own [dispose()].
///
/// Example:
/// ```dart
/// late final AnimationController _shakeCtrl = AnimationController(
///   vsync: this,
///   duration: AppConstants.shakeAnimationDuration,
/// );
/// late final Animation<double> _shakeAnim = ShakeAnimation.createFor(_shakeCtrl);
///
/// // On wrong answer:
/// _shakeCtrl.forward(from: 0);
///
/// // In build:
/// ShakeAnimation(shakeValue: _shakeAnim, child: quizOptionWidget)
/// ```
class ShakeAnimation extends StatelessWidget {
  /// The x-displacement animation produced by [createFor].
  final Animation<double> shakeValue;

  /// The widget to shake.
  final Widget child;

  const ShakeAnimation({
    super.key,
    required this.shakeValue,
    required this.child,
  });

  // ─── Factory ───────────────────────────────────────────────────────────────

  /// Creates the shake [TweenSequence] animation from [controller].
  ///
  /// The sequence produces diminishing oscillations for natural,
  /// physics-inspired feedback. Duration is set on [controller] externally.
  static Animation<double> createFor(AnimationController controller) {
    return TweenSequence<double>([
      // Slam right
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      // Hard left
      TweenSequenceItem(
        tween: Tween<double>(begin: 10, end: -10)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      // Diminish right
      TweenSequenceItem(
        tween: Tween<double>(begin: -10, end: 8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      // Diminish left
      TweenSequenceItem(
        tween: Tween<double>(begin: 8, end: -8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      // Small right
      TweenSequenceItem(
        tween: Tween<double>(begin: -8, end: 5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      // Small left
      TweenSequenceItem(
        tween: Tween<double>(begin: 5, end: -5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      // Settle to rest
      TweenSequenceItem(
        tween: Tween<double>(begin: -5, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(controller);
    // Note: Curve is applied per-segment above. No outer CurvedAnimation needed.
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeValue,
      // child is passed through so it is not rebuilt on every animation tick.
      child: child,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(shakeValue.value, 0),
          child: child,
        );
      },
    );
  }
}

// ─── ShakeAnimationController mixin ──────────────────────────────────────────

/// Convenience mixin for [StatefulWidget]s that host a shake animation.
///
/// Mix into a [State] class with [TickerProviderStateMixin] or [SingleTickerProviderStateMixin].
///
/// ```dart
/// class _QuizCardState extends ConsumerState<QuizCard>
///     with TickerProviderStateMixin, ShakeAnimationMixin {
///
///   @override
///   void initState() {
///     super.initState();
///     initShakeAnimation(vsync: this);
///   }
///
///   // Trigger in wrong-answer handler:
///   //   triggerShake();
/// }
/// ```
mixin ShakeAnimationMixin {
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  /// The animation to pass to [ShakeAnimation.shakeValue].
  Animation<double> get shakeAnimation {
    assert(_shakeAnimation != null, 'Call initShakeAnimation() first.');
    return _shakeAnimation!;
  }

  /// Initialises the shake animation controller.
  ///
  /// Must be called in [State.initState]. [vsync] should be the State itself.
  void initShakeAnimation({required TickerProvider vsync}) {
    _shakeController = AnimationController(
      vsync: vsync,
      duration: AppConstants.shakeAnimationDuration,
    );
    _shakeAnimation = ShakeAnimation.createFor(_shakeController!);
  }

  /// Triggers the shake animation from the beginning.
  ///
  /// Safe to call mid-animation — [forward(from: 0)] resets to the start.
  void triggerShake() {
    _shakeController?.forward(from: 0);
  }

  /// Disposes the animation controller. Call in [State.dispose].
  void disposeShakeAnimation() {
    _shakeController?.dispose();
    _shakeController = null;
  }
}
