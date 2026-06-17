// lib/animations/success_animation.dart
//
// Scale-bounce success animation for the buddy widget.
//
// ARCHITECTURE NOTE:
//   Mirrors the same pattern as ShakeAnimation:
//     - StatelessWidget takes a pre-built Animation<double>.
//     - Factory method createFor() builds the TweenSequence.
//     - Host widget owns and disposes the AnimationController.
//     - SuccessAnimationMixin provides a convenience pattern for host widgets.

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Applies a celebratory scale-bounce to [child].
///
/// Scale sequence:
///   1.0 → [AppConstants.successBounceScale] → 1.0
///
/// Curve: [Curves.elasticOut] for a spring-like, joyful overshoot.
///
/// Used for: buddy widget on correct answer, success headline text.
class SuccessAnimation extends StatelessWidget {
  /// The scale animation produced by [createFor].
  final Animation<double> scaleValue;

  /// The widget to scale.
  final Widget child;

  const SuccessAnimation({
    super.key,
    required this.scaleValue,
    required this.child,
  });

  // ─── Factory ───────────────────────────────────────────────────────────────

  /// Creates the success scale [TweenSequence] animation from [controller].
  ///
  /// The sequence: expand (with elasticOut overshoot) then settle back to 1.0.
  static Animation<double> createFor(AnimationController controller) {
    return TweenSequence<double>([
      // Phase 1: Expand with elastic overshoot.
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: AppConstants.successBounceScale,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      // Phase 2: Spring back to rest with elastic settle.
      TweenSequenceItem(
        tween: Tween<double>(
          begin: AppConstants.successBounceScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(controller);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scaleValue,
      child: child,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: scaleValue.value,
          child: child,
        );
      },
    );
  }
}

// ─── SuccessAnimationMixin ────────────────────────────────────────────────────

/// Convenience mixin for widgets that host the success scale animation.
///
/// ```dart
/// class _BuddyWidgetState extends ConsumerState<BuddyWidget>
///     with TickerProviderStateMixin, SuccessAnimationMixin {
///
///   @override
///   void initState() {
///     super.initState();
///     initSuccessAnimation(vsync: this);
///   }
///
///   // In ref.listen for StoryState.success:
///   //   triggerSuccess();
/// }
/// ```
mixin SuccessAnimationMixin {
  AnimationController? _successController;
  Animation<double>? _successAnimation;

  /// The scale animation to pass to [SuccessAnimation.scaleValue].
  Animation<double> get successAnimation {
    assert(_successAnimation != null, 'Call initSuccessAnimation() first.');
    return _successAnimation!;
  }

  /// Initialises the success animation controller.
  void initSuccessAnimation({required TickerProvider vsync}) {
    _successController = AnimationController(
      vsync: vsync,
      duration: AppConstants.successBounceDuration,
    );
    _successAnimation = SuccessAnimation.createFor(_successController!);
  }

  /// Triggers the success animation from the beginning.
  void triggerSuccess() {
    _successController?.forward(from: 0);
  }

  /// Disposes the animation controller. Call in [State.dispose].
  void disposeSuccessAnimation() {
    _successController?.dispose();
    _successController = null;
  }
}
