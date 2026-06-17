// lib/widgets/loading_widget.dart
//
// Loading state overlay shown while TTS initialises.
//
// ARCHITECTURE NOTE:
//   - Pure presentational widget — no provider reads beyond constants.
//   - AnimationController disposed in dispose() — no memory leaks.
//   - Phase 2: Replace animated dots with full buddy thinking animation
//     and a bouncing loading pill.

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/theme.dart';

/// Loading overlay shown in [StoryState.loading].
///
/// Displays the loading headline, animated ellipsis, and a soft progress
/// indicator to reassure the child that something is happening.
///
/// The buddy widget (above this in the layout) simultaneously transitions
/// to its [BuddyEmotion.thinking] state — the two work in concert.
class LoadingWidget extends StatefulWidget {
  const LoadingWidget({super.key});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    // Animate the ellipsis dot count: 1 → 2 → 3 → 1 → …
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() => _dotCount = (_dotCount % 3) + 1);
          }
          _dotsController.forward(from: 0);
        }
      });
    _dotsController.forward();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String dots = '.' * _dotCount;

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        boxShadow: AppTheme.cardShadow(tintColor: AppConstants.primaryCoral),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Soft progress ring — colored to match Peblo brand.
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppConstants.primaryCoral,
              ),
              backgroundColor: AppConstants.softPeach,
            ),
          ),

          const SizedBox(height: AppConstants.spacingLG),

          // Loading headline with animated dots.
          Text(
            '${AppConstants.loadingHeadline}$dots',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.spacingSM),

          Text(
            AppConstants.loadingSubtext,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    );
  }
}
