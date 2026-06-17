// lib/providers/providers.dart
//
// Riverpod dependency injection registry.
//
// ARCHITECTURE NOTE:
//   All Provider declarations live in this single file. This makes the DI
//   graph visible at a glance and avoids scattered provider declarations.
//
//   Provider hierarchy:
//     ttsServiceProvider          (leaf — no deps)
//         └─► storyNotifierProvider (injects TtsService)
//                 └─► [all derived providers] (select from storyNotifier)
//
//   Derived providers use select() to isolate individual fields.
//   Widgets consuming these providers rebuild ONLY when their specific
//   field changes — not on every StoryStateData change.
//
//   Ref.watch() is used ONLY inside Provider factory bodies.
//   Widgets use ref.watch() for reads, ref.read() for action callbacks.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_model.dart';
import '../models/story_content.dart';
import '../services/tts_service.dart';
import 'story_provider.dart';

// ─── Service Providers ───────────────────────────────────────────────────────

/// Provides the singleton [TtsService] for the app lifecycle.
///
/// [ref.onDispose] ensures the TTS engine is stopped and its stream closed
/// when the provider is removed from the graph (e.g., on hot restart or
/// when the ProviderScope is disposed).
final ttsServiceProvider = Provider<TtsService>((ref) {
  final TtsService service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

// ─── Primary State Provider ──────────────────────────────────────────────────

/// The primary [StateNotifierProvider] for the Peblo story experience.
///
/// [TtsService] is injected from [ttsServiceProvider]. [StoryNotifier]
/// never instantiates services — it only consumes them via this pattern.
///
/// Access in widgets:
///   ```dart
///   // For state reads (reactive):
///   final data = ref.watch(storyNotifierProvider);
///
///   // For action calls (non-reactive):
///   ref.read(storyNotifierProvider.notifier).startStory();
///   ```
final storyNotifierProvider =
    StateNotifierProvider<StoryNotifier, StoryStateData>((ref) {
  final TtsService ttsService = ref.watch(ttsServiceProvider);
  return StoryNotifier(ttsService);
});

// ─── Derived Selector Providers ──────────────────────────────────────────────
//
// Each derived provider isolates a SINGLE field from StoryStateData via
// select(). Widgets watching these rebuild only when that field changes.
//
// Performance rationale:
//   Without select(), every StoryStateData change (e.g., buddyEmotion update)
//   would force ALL consumers to rebuild. With select(), the BuddyWidget only
//   rebuilds when buddyEmotion changes, the QuizCard only when the quiz
//   changes, etc.

/// Current [StoryState] — drives top-level UI branching in StoryScreen.
///
/// Widgets: StoryScreen (layout selector), LoadingWidget, ErrorWidget.
final storyStatusProvider = Provider<StoryState>(
  (ref) => ref.watch(storyNotifierProvider.select((s) => s.status)),
);

/// Current [BuddyEmotion] — drives character expression, glow, and animation.
///
/// Widgets: BuddyWidget exclusively. All other widgets are decoupled from
/// the buddy's emotional state.
final buddyEmotionProvider = Provider<BuddyEmotion>(
  (ref) => ref.watch(storyNotifierProvider.select((s) => s.buddyEmotion)),
);

/// The active [StoryContent] — consumed by StoryCard.
///
/// Null in [StoryState.idle] before a story is loaded.
final currentStoryProvider = Provider<StoryContent?>(
  (ref) => ref.watch(storyNotifierProvider.select((s) => s.currentStory)),
);

/// The active [QuizModel] — consumed by QuizCard.
///
/// Derived from [currentStory.quiz]. Null if no story is loaded.
final currentQuizProvider = Provider<QuizModel?>(
  (ref) => ref.watch(
    storyNotifierProvider.select((s) => s.currentStory?.quiz),
  ),
);

/// The index of the last selected quiz option.
///
/// Null if no option has been selected yet.
/// Consumed by QuizCard to highlight the selected option.
final selectedOptionIndexProvider = Provider<int?>(
  (ref) => ref.watch(
    storyNotifierProvider.select((s) => s.selectedOptionIndex),
  ),
);

/// The current child-facing error message.
///
/// Null when there is no active error. Consumed by the error recovery widget.
/// Always child-safe copy — never raw exception messages.
final errorMessageProvider = Provider<String?>(
  (ref) => ref.watch(storyNotifierProvider.select((s) => s.errorMessage)),
);

/// Background gradient color stops — consumed by StoryScreen's AnimatedContainer.
///
/// Uses const lists from [AppConstants] so select() identity comparisons
/// correctly suppress redundant rebuilds when the gradient doesn't change.
final backgroundGradientProvider = Provider<List<Color>>(
  (ref) => ref.watch(
    storyNotifierProvider.select((s) => s.backgroundGradientStops),
  ),
);

/// Correct answer streak — consumed by the progress stars widget.
///
/// Drives the number of filled stars displayed after [StoryState.success].
final streakProvider = Provider<int>(
  (ref) => ref.watch(
    storyNotifierProvider.select((s) => s.correctAnswerStreak),
  ),
);

/// Whether the child has completed at least one full story+quiz cycle.
///
/// Used to conditionally show "Your Progress" section in the success state.
final hasCompletedOnceProvider = Provider<bool>(
  (ref) => ref.watch(
    storyNotifierProvider.select((s) => s.hasCompletedOnce),
  ),
);
