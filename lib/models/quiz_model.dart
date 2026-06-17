// lib/models/quiz_model.dart
//
// Immutable data models for quiz content.
//
// ARCHITECTURE NOTE:
//   These are pure value objects with zero Flutter/Riverpod dependencies.
//   They can be unit-tested without a Flutter environment.
//   In Phase 3, these will be JSON-deserialisable via fromJson factories.

import 'package:flutter/foundation.dart';

// ─── QuizOption ──────────────────────────────────────────────────────────────

/// A single selectable answer option presented to the child.
///
/// [id]    — Stable identifier. Used for analytics tracking.
/// [text]  — The answer text displayed to the child.
/// [emoji] — Decorative emoji alongside the text; aids pre-readers.
@immutable
class QuizOption {
  /// Stable, unique identifier for this option within its quiz.
  final String id;

  /// The answer text displayed to the child.
  final String text;

  /// Decorative emoji shown alongside [text]. Aids pre-readers.
  final String emoji;

  const QuizOption({
    required this.id,
    required this.text,
    required this.emoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizOption && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuizOption(id: $id, text: $text)';
}

// ─── QuizModel ───────────────────────────────────────────────────────────────

/// A complete quiz associated with a single story episode.
///
/// Constraints:
///   - Must have 2–4 [options] (enforced at construction).
///   - [correctOptionIndex] must be a valid index into [options].
///
/// Usage:
/// ```dart
/// final isRight = quiz.isCorrect(selectedIndex);
/// final winner  = quiz.correctOption; // the winning QuizOption
/// ```
@immutable
class QuizModel {
  /// Stable, unique identifier for this quiz.
  final String id;

  /// The comprehension question displayed after story completion.
  final String question;

  /// All selectable answer options. Length: 2–4 inclusive.
  final List<QuizOption> options;

  /// Zero-based index into [options] pointing to the correct answer.
  final int correctOptionIndex;

  const QuizModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
  })  : assert(options.length >= 3, 'QuizModel must have at least 3 options.'),
        assert(options.length <= 5, 'QuizModel must have at most 5 options.'),
        assert(
          correctOptionIndex >= 0,
          'correctOptionIndex must be non-negative.',
        );

  /// Factory constructor to create a [QuizModel] from a JSON map.
  ///
  /// Expected JSON structure:
  /// ```json
  /// {
  ///   "question": "What colour was Pip the Robot's lost gear?",
  ///   "options": ["Red", "Green", "Blue", "Yellow"],
  ///   "answer": "Blue"
  /// }
  /// ```
  factory QuizModel.fromJson(Map<String, dynamic> json, {required String id}) {
    final String questionText = json['question'] as String;
    final List<dynamic> optionsRaw = json['options'] as List<dynamic>;
    final String answerText = json['answer'] as String;

    final List<QuizOption> parsedOptions = [];
    int correctIndex = -1;

    for (int i = 0; i < optionsRaw.length; i++) {
      final String optionText = optionsRaw[i] as String;
      final String optionId = '${id}_opt_$i';
      
      // Auto-assign child-friendly decorative emoji based on option text keywords
      final String emoji = _getEmojiForOptionText(optionText);

      parsedOptions.add(QuizOption(
        id: optionId,
        text: optionText,
        emoji: emoji,
      ));

      if (optionText == answerText) {
        correctIndex = i;
      }
    }

    if (correctIndex == -1) {
      correctIndex = 0;
    }

    return QuizModel(
      id: id,
      question: questionText,
      options: parsedOptions,
      correctOptionIndex: correctIndex,
    );
  }

  static String _getEmojiForOptionText(String text) {
    final String lower = text.toLowerCase();
    if (lower.contains('red')) return '🔴';
    if (lower.contains('blue')) return '🔵';
    if (lower.contains('green')) return '🟢';
    if (lower.contains('yellow')) return '🟡';
    if (lower.contains('purple')) return '🟣';
    if (lower.contains('orange')) return '🟠';
    if (lower.contains('pink')) return '🌸';
    if (lower.contains('white')) return '⚪';
    if (lower.contains('black')) return '⚫';
    
    // Animal keywords
    if (lower.contains('owl')) return '🦉';
    if (lower.contains('firefly') || lower.contains('fizz')) return '✨';
    if (lower.contains('spider')) return '🕷️';
    if (lower.contains('bird')) return '🐦';
    if (lower.contains('fish') || lower.contains('clownfish')) return '🐠';
    if (lower.contains('turtle')) return '🐢';
    if (lower.contains('octopus')) return '🐙';
    if (lower.contains('dragon')) return '🐉';
    
    // Object keywords
    if (lower.contains('sunflower') || lower.contains('flower')) return '🌻';
    if (lower.contains('tree')) return '🌳';
    if (lower.contains('mushroom')) return '🍄';
    if (lower.contains('cloud')) return '☁️';
    if (lower.contains('fire') || lower.contains('flame')) return '🔥';
    if (lower.contains('ice') || lower.contains('snow') || lower.contains('wind')) return '❄️';
    if (lower.contains('bubble')) return '🫧';
    if (lower.contains('rainbow')) return '🌈';
    if (lower.contains('shell')) return '🐚';
    if (lower.contains('ship') || lower.contains('boat')) return '🚢';
    if (lower.contains('egg')) return '🥚';
    
    // Fallback decorative elements
    final List<String> list = ['⭐', '✨', '🎈', '🎨', '🧩', '🍭', '🧸'];
    return list[text.length % list.length];
  }
  // Note: correctOptionIndex < options.length cannot be asserted at compile
  // time with const constructors; validated via isCorrect() guard at runtime.

  // ─── Computed Properties ──────────────────────────────────────────────────

  /// Returns `true` if [selectedIndex] matches the correct answer.
  ///
  /// Always returns `false` for out-of-range indices rather than throwing.
  bool isCorrect(int selectedIndex) {
    if (selectedIndex < 0 || selectedIndex >= options.length) return false;
    return selectedIndex == correctOptionIndex;
  }

  /// Returns the correct [QuizOption].
  ///
  /// Safe to call at any time — correctOptionIndex is validated at construction.
  QuizOption get correctOption => options[correctOptionIndex];

  /// Returns the total number of options.
  int get optionCount => options.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizModel && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'QuizModel(id: $id, question: $question, options: ${options.length})';
}
