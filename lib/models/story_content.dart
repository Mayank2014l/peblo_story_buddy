// lib/models/story_content.dart
//
// Immutable model representing a single Peblo story episode.
//
// ARCHITECTURE NOTE:
//   StoryContent is a pure data model. It owns its associated QuizModel
//   (composition). The service layer is responsible for providing instances;
//   widgets only consume them via providers.

import 'package:flutter/material.dart';

import 'quiz_model.dart';

// ─── StoryContent ────────────────────────────────────────────────────────────

/// A single story episode in the Peblo Story Buddy experience.
///
/// Each story is self-contained — it carries its narrative text (for TTS),
/// display text (for the story card), and the comprehension quiz that unlocks
/// when narration completes.
///
/// [accentColor] drives the per-story tinting of cards, shadows, and the
/// animated background gradient override (Phase 2).
@immutable
class StoryContent {
  /// Stable, unique identifier. Used for analytics and progress tracking.
  final String id;

  /// Short, child-friendly story title displayed in the story card header.
  final String title;

  /// Full narrative text passed to the TTS engine.
  ///
  /// This string is optimised for speech — no markdown, no emoji, no line
  /// breaks. Punctuation drives natural TTS pause rhythm.
  final String narrativeText;

  /// Formatted text displayed in the story card for the child to follow.
  ///
  /// May include paragraph breaks (`\n\n`) and emoji for visual warmth.
  /// This is NOT read by TTS.
  final String displayText;

  /// The comprehension quiz revealed after this story's narration completes.
  ///
  /// The quiz is driven ONLY by the TTS completion callback — never by timers.
  final QuizModel quiz;

  /// Dominant accent color for this story's visual identity.
  ///
  /// Used for: card shadow tinting, buddy glow overlay, progress star color.
  final Color accentColor;

  /// Decorative emoji representing this story's theme.
  ///
  /// Displayed in the story card header and loading overlay.
  final String themeEmoji;

  const StoryContent({
    required this.id,
    required this.title,
    required this.narrativeText,
    required this.displayText,
    required this.quiz,
    required this.accentColor,
    required this.themeEmoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryContent &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StoryContent(id: $id, title: $title)';
}
