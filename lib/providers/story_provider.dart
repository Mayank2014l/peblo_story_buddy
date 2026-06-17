// lib/providers/story_provider.dart
//
// Core state management for the Peblo Story Buddy & Quiz experience.
//
// ARCHITECTURE NOTE:
//   This file contains:
//     1. StoryState   — the canonical story flow state enum (required exact).
//     2. BuddyEmotion — the buddy character's expressive state enum.
//     3. StoryStateData — the full immutable state record.
//     4. StoryNotifier  — the StateNotifier that owns all business logic.
//
//   Rules enforced here:
//     ✓ Zero setState() calls — all state via copyWith.
//     ✓ Quiz reveal driven ONLY by TtsAudioState.completed stream event.
//     ✓ TtsService injected via constructor — never instantiated here.
//     ✓ All transitions are guarded to prevent invalid state sequences.
//     ✓ StreamSubscription cancelled in dispose() — no memory leaks.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_stories.dart';
import '../models/quiz_model.dart';
import '../models/story_content.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';

// ─── StoryState ──────────────────────────────────────────────────────────────

/// The canonical state enum for the Peblo story flow.
///
/// ⚠️  DO NOT rename, remove, or reorder these values without explicit
/// product sign-off. External callers (analytics, A/B testing) depend
/// on stable enum names.
///
/// State machine diagram:
/// ```
///   idle ──────────────────────────────────► loading
///   loading (via TtsAudioState.playing) ──► playing
///   playing (via TtsAudioState.completed) ► quizVisible
///   quizVisible ──────────────────────────► wrongAnswer | success
///   wrongAnswer ──────────────────────────► quizVisible (retry)
///   success | error ──────────────────────► idle (restart / retry)
/// ```
enum StoryState {
  /// App launched, buddy idle, CTA visible.
  idle,

  /// Story selected — TTS initialising, buddy shows [BuddyEmotion.thinking].
  loading,

  /// TTS actively narrating — buddy shows [BuddyEmotion.reading].
  playing,

  /// Narration complete — quiz card visible, buddy shows [BuddyEmotion.thinking].
  quizVisible,

  /// Child selected a wrong answer — shake animation fires.
  wrongAnswer,

  /// Child selected the correct answer — confetti + celebration.
  success,

  /// TTS or system error — friendly recovery UI visible.
  error,
}

// ─── BuddyEmotion ────────────────────────────────────────────────────────────

/// The expressive emotional state of the Peblo buddy character.
///
/// Drives: character expression, glow color, animation intensity, and
/// (in Phase 2) the CustomPainter drawing state.
enum BuddyEmotion {
  /// Default resting state — gentle idle float animation.
  idle,

  /// Curious, processing state — slight head tilt, raised eyebrow.
  thinking,

  /// Active narration — animated mouth, warm reading expression.
  reading,

  /// Correct answer — big smile, arms raised, peak glow.
  celebrating,

  /// Wrong answer or error — droopy eyes, empathetic expression.
  sad,
}

// ─── StoryStateData ──────────────────────────────────────────────────────────

/// The complete, immutable snapshot of the Peblo story experience.
///
/// This is the single source of truth consumed by all widgets.
/// Never mutate fields directly — always use [copyWith].
///
/// [StoryNotifier] holds the [StateNotifier<StoryStateData>] and is the
/// only class authorised to produce new [StoryStateData] instances.
@immutable
class StoryStateData {
  // ── Core Flow ───────────────────────────────────────────────────────────────

  /// The current phase of the story flow.
  final StoryState status;

  // ── Content ─────────────────────────────────────────────────────────────────

  /// The active story. Null in [StoryState.idle] before first story starts.
  final StoryContent? currentStory;

  // ── Character ───────────────────────────────────────────────────────────────

  /// The buddy's current emotional expression.
  final BuddyEmotion buddyEmotion;

  // ── Quiz Interaction ────────────────────────────────────────────────────────

  /// The index of the last option the child selected. Null if none yet.
  final int? selectedOptionIndex;

  // ── Error Handling ──────────────────────────────────────────────────────────

  /// Child-friendly error copy. NEVER contains raw exception messages.
  final String? errorMessage;

  // ── Progress / Session ──────────────────────────────────────────────────────

  /// Number of consecutive correct answers this session.
  /// Used for story rotation and star display.
  final int correctAnswerStreak;

  /// Whether the child has completed at least one full story+quiz cycle.
  final bool hasCompletedOnce;

  // ── Visual ──────────────────────────────────────────────────────────────────

  /// Gradient color stops for the animated background.
  ///
  /// Uses the CONST lists from [AppConstants] — Dart canonicalises these so
  /// identical() comparisons in Riverpod select() work correctly.
  final List<Color> backgroundGradientStops;

  // ─── Constructor ─────────────────────────────────────────────────────────────

  const StoryStateData({
    required this.status,
    required this.buddyEmotion,
    required this.backgroundGradientStops,
    this.currentStory,
    this.selectedOptionIndex,
    this.errorMessage,
    this.correctAnswerStreak = 0,
    this.hasCompletedOnce = false,
  });

  /// The initial state at app launch.
  factory StoryStateData.initial() => const StoryStateData(
        status: StoryState.idle,
        buddyEmotion: BuddyEmotion.idle,
        backgroundGradientStops: AppConstants.gradientIdle,
      );

  // ─── copyWith ────────────────────────────────────────────────────────────────

  /// Returns a new [StoryStateData] with the specified fields replaced.
  ///
  /// Optional nullable override flags:
  ///   [clearSelectedOption] — sets [selectedOptionIndex] to null.
  ///   [clearError]          — sets [errorMessage] to null.
  ///   [clearStory]          — sets [currentStory] to null.
  StoryStateData copyWith({
    StoryState? status,
    StoryContent? currentStory,
    BuddyEmotion? buddyEmotion,
    int? selectedOptionIndex,
    String? errorMessage,
    int? correctAnswerStreak,
    bool? hasCompletedOnce,
    List<Color>? backgroundGradientStops,
    // Explicit null-clearing helpers — Dart's null-safety prevents passing
    // null to a copyWith that forwards via ??  without these flags.
    bool clearSelectedOption = false,
    bool clearError = false,
    bool clearStory = false,
  }) {
    return StoryStateData(
      status: status ?? this.status,
      currentStory: clearStory ? null : (currentStory ?? this.currentStory),
      buddyEmotion: buddyEmotion ?? this.buddyEmotion,
      selectedOptionIndex: clearSelectedOption
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      correctAnswerStreak:
          correctAnswerStreak ?? this.correctAnswerStreak,
      hasCompletedOnce: hasCompletedOnce ?? this.hasCompletedOnce,
      backgroundGradientStops:
          backgroundGradientStops ?? this.backgroundGradientStops,
    );
  }

  @override
  String toString() => 'StoryStateData('
      'status: $status, '
      'emotion: $buddyEmotion, '
      'streak: $correctAnswerStreak, '
      'hasCompleted: $hasCompletedOnce'
      ')';
}

// ─── StoryNotifier ───────────────────────────────────────────────────────────

/// The primary [StateNotifier] for the Peblo Story Buddy & Quiz experience.
///
/// Owns all story flow business logic. The [TtsService] is injected via
/// constructor — this class never creates its own service instances.
///
/// Widget interaction pattern (via Riverpod):
///   ```dart
///   // Reading state (in build):
///   final status = ref.watch(storyStatusProvider);
///
///   // Triggering actions (in callbacks — never in build):
///   ref.read(storyNotifierProvider.notifier).startStory();
///   ref.read(storyNotifierProvider.notifier).selectAnswer(index);
///   ```
class StoryNotifier extends StateNotifier<StoryStateData> {
  final TtsService _ttsService;
  StreamSubscription<TtsAudioState>? _ttsSubscription;

  StoryNotifier(this._ttsService) : super(StoryStateData.initial()) {
    _subscribeTtsStream();
  }

  // ─── TTS Stream Subscription ─────────────────────────────────────────────────

  /// Subscribes to the TTS audio state stream.
  ///
  /// The [TtsAudioState.completed] event is the canonical and ONLY trigger
  /// for transitioning to [StoryState.quizVisible]. All other audio events
  /// drive appropriate buddy/status state updates.
  void _subscribeTtsStream() {
    _ttsSubscription = _ttsService.audioStateStream.listen(
      _onTtsStateChanged,
      onError: (_) => _handleTtsError(),
      cancelOnError: false, // Keep listening after individual errors.
    );
  }

  /// Maps incoming [TtsAudioState] events to [StoryStateData] transitions.
  void _onTtsStateChanged(TtsAudioState audioState) {
    if (!mounted) return;

    switch (audioState) {
      case TtsAudioState.loading:
        state = state.copyWith(
          status: StoryState.loading,
          buddyEmotion: BuddyEmotion.thinking,
          backgroundGradientStops: AppConstants.gradientLoading,
          clearError: true,
        );

      case TtsAudioState.playing:
        state = state.copyWith(
          status: StoryState.playing,
          buddyEmotion: BuddyEmotion.reading,
          backgroundGradientStops: AppConstants.gradientPlaying,
        );

      // ✅ THE ONLY QUIZ REVEAL TRIGGER.
      // No timers. No Future.delayed(). No workarounds.
      case TtsAudioState.completed:
        state = state.copyWith(
          status: StoryState.quizVisible,
          buddyEmotion: BuddyEmotion.thinking,
          backgroundGradientStops: AppConstants.gradientQuiz,
          clearSelectedOption: true,
          clearError: true,
        );

      // Scenarios 3 & 4: Phone call or app backgrounded.
      // We stay in 'playing' status so the UI shows the same screen, but
      // update the buddy to a neutral idle so it doesn't look frozen.
      case TtsAudioState.paused:
        if (state.status == StoryState.playing) {
          state = state.copyWith(buddyEmotion: BuddyEmotion.idle);
        }

      case TtsAudioState.error:
        _handleTtsError();

      case TtsAudioState.idle:
        // No action required — idle is the default between operations.
        break;
    }
  }

  /// Transitions to [StoryState.error] with child-friendly copy.
  void _handleTtsError() {
    if (!mounted) return;
    state = state.copyWith(
      status: StoryState.error,
      buddyEmotion: BuddyEmotion.sad,
      errorMessage: AppConstants.ttsErrorMessage,
      backgroundGradientStops: AppConstants.gradientError,
    );
  }

  // ─── Public Actions ───────────────────────────────────────────────────────────

  /// Triggered when the child taps the "Read Me A Story" CTA.
  ///
  /// Selects the next story, transitions to [StoryState.loading], and
  /// starts TTS narration. The loading → playing transition is driven by
  /// the TTS stream.
  ///
  /// Guard: only valid from [StoryState.idle].
  Future<void> startStory() async {
    if (state.status != StoryState.idle) return;

    final StoryContent story = _selectNextStory();

    state = state.copyWith(
      status: StoryState.loading,
      currentStory: story,
      buddyEmotion: BuddyEmotion.thinking,
      backgroundGradientStops: AppConstants.gradientLoading,
      clearSelectedOption: true,
      clearError: true,
    );

    // speak() submits the text to the TTS engine.
    // The TtsService stream drives all subsequent state transitions.
    await _ttsService.speak(story.narrativeText);
  }

  /// Called when the child selects a quiz answer option.
  ///
  /// Evaluates correctness and transitions to [wrongAnswer] or [success].
  ///
  /// Guard: only valid from [StoryState.quizVisible] or [StoryState.wrongAnswer]
  /// (to allow retries without restriction).
  void selectAnswer(int optionIndex) {
    final bool canAnswer = state.status == StoryState.quizVisible ||
        state.status == StoryState.wrongAnswer;
    if (!canAnswer) return;

    final QuizModel? quiz = state.currentStory?.quiz;
    if (quiz == null) return;

    if (quiz.isCorrect(optionIndex)) {
      // ── Correct answer ─────────────────────────────────────────────────────
      state = state.copyWith(
        status: StoryState.success,
        buddyEmotion: BuddyEmotion.celebrating,
        selectedOptionIndex: optionIndex,
        correctAnswerStreak: state.correctAnswerStreak + 1,
        hasCompletedOnce: true,
        backgroundGradientStops: AppConstants.gradientSuccess,
        clearError: true,
      );
    } else {
      // ── Wrong answer ────────────────────────────────────────────────────────
      state = state.copyWith(
        status: StoryState.wrongAnswer,
        buddyEmotion: BuddyEmotion.sad,
        selectedOptionIndex: optionIndex,
        backgroundGradientStops: AppConstants.gradientQuiz,
      );
    }
  }

  /// Resets after a wrong answer so the child can try again.
  ///
  /// Returns to [StoryState.quizVisible] without re-narrating the story.
  /// Unlimited retries are intentional — Peblo never penalises children.
  ///
  /// Guard: only valid from [StoryState.wrongAnswer].
  void retryAnswer() {
    if (state.status != StoryState.wrongAnswer) return;
    state = state.copyWith(
      status: StoryState.quizVisible,
      buddyEmotion: BuddyEmotion.thinking,
      backgroundGradientStops: AppConstants.gradientQuiz,
      clearSelectedOption: true,
    );
  }

  /// Triggered by the "Try Again" button in the error recovery UI.
  ///
  /// Stops any active TTS, preserves session progress, and returns to idle.
  ///
  /// Guard: only valid from [StoryState.error].
  Future<void> retryFromError() async {
    if (state.status != StoryState.error) return;
    await _ttsService.stop();
    state = StoryStateData.initial().copyWith(
      // Preserve session progress across error recovery.
      hasCompletedOnce: state.hasCompletedOnce,
      correctAnswerStreak: state.correctAnswerStreak,
    );
  }

  /// Resets the full flow for another story.
  ///
  /// Called from the "Read Another Story" button in [StoryState.success].
  /// Preserves cumulative session progress (streak, hasCompletedOnce).
  Future<void> restartFlow() async {
    await _ttsService.stop();
    state = StoryStateData.initial().copyWith(
      hasCompletedOnce: state.hasCompletedOnce,
      correctAnswerStreak: state.correctAnswerStreak,
    );
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  /// Selects the next story from [SampleStories.all].
  ///
  /// Currently rotates sequentially based on the session's story count
  /// (derived from [correctAnswerStreak]). In Phase 3, this will be
  /// replaced by the Peblo AI recommendation engine.
  StoryContent _selectNextStory() {
    final List<StoryContent> stories = SampleStories.all;
    if (stories.isEmpty) {
      throw StateError(
        '[StoryNotifier] No stories available in SampleStories.all. '
        'Ensure the data layer is populated before calling startStory().',
      );
    }
    // Wrap around to keep the experience fresh across multiple sessions.
    final int index = state.correctAnswerStreak % stories.length;
    return stories[index];
  }

  // ─── Disposal ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks and post-dispose
    // state emissions.
    _ttsSubscription?.cancel();
    _ttsSubscription = null;

    // TtsService disposal is handled by Riverpod's ref.onDispose() in
    // providers.dart — we do NOT call _ttsService.dispose() here to avoid
    // double-disposal if the provider is re-used.

    super.dispose();
  }
}
