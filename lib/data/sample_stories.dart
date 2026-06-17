// lib/data/sample_stories.dart
//
// Seeded story content for Peblo Story Buddy v1.
//
// ARCHITECTURE NOTE:
//   In production, stories are fetched from the Peblo CMS / AI story-
//   generation service and cached locally. This file is the offline-first
//   fallback and the development dataset for Phase 1 & 2.
//
//   All content is child-safe, age-appropriate (4–8), and follows Peblo's
//   editorial tone: warm, encouraging, imaginative, consequence-aware.
//
//   Narrative text is optimised for speech (no markdown, no emoji, no line
//   breaks). Display text is optimised for visual warmth (emoji, paragraphs).

import 'package:flutter/material.dart';

import '../models/quiz_model.dart';
import '../models/story_content.dart';
import '../utils/constants.dart';

/// The seeded story pool for Peblo Story Buddy.
///
/// Access stories via [SampleStories.all]. Stories are ordered by intended
/// difficulty / session progression. The provider layer selects based on
/// the child's current session index.
abstract final class SampleStories {
  // ─── Story Pool ─────────────────────────────────────────────────────────────

  /// All available stories.
  ///
  /// Declared `const` for zero-allocation reads — this list is never mutated.
  static final List<StoryContent> all = [
    _pipStory,       // Featured: introduced in Phase 3 UI
    _sunflowerStory,
    _dragonStory,
    _oceanStory,
  ];

  // ─── Story 0 : Pip and the Missing Gear ─────────────────────────────────────
  // Featured story that matches the Buddy character "Pip" visually.

  static final StoryContent _pipStory = StoryContent(
    id: 'peblo_story_pip_v1',
    title: 'Pip and the Missing Gear',
    themeEmoji: '🤖',
    accentColor: AppConstants.skyBlue,

    narrativeText:
        'Once upon a time, a clever little robot named Pip lost his shiny blue gear '
        'in the Whispering Woods. '
        'Pip searched everywhere — behind tall oak trees, under mossy rocks, '
        'and through sparkling streams. '
        'Then a friendly firefly named Fizz spotted the gear stuck in a spider\'s web '
        'high up in a willow tree. '
        'Fizz lit up the web with a warm golden glow, and Pip carefully reached up '
        'and retrieved his gear. '
        'Thank you Fizz! said Pip. I could not have done it without a friend! '
        'From that day on, Pip always knew — even the smartest robot needs a friend sometimes.',

    displayText:
        'Once upon a time, a clever little robot named Pip lost his shiny blue gear '
        'in the Whispering Woods. 🌲\n\n'
        'Pip searched everywhere — behind tall oak trees, under mossy rocks, '
        'and through sparkling streams.\n\n'
        'Then a friendly firefly named Fizz spotted the gear stuck high in a willow tree! 🔦\n\n'
        '"Thank you, Fizz!" said Pip. "I could not have done it without a friend!" 🤖💙\n\n'
        'From that day on, Pip always knew — even the smartest robot needs a friend sometimes. ✨',

    quiz: QuizModel(
      id: 'peblo_quiz_pip_v1',
      question: 'Who helped Pip find his missing gear?',
      options: [
        QuizOption(id: 'pip_a', text: 'A wise old owl', emoji: '🦉'),
        QuizOption(id: 'pip_b', text: 'A firefly named Fizz', emoji: '✨'),
        QuizOption(id: 'pip_c', text: 'A talking spider', emoji: '🕷️'),
        QuizOption(id: 'pip_d', text: 'A little blue bird', emoji: '🐦'),
      ],
      correctOptionIndex: 1,
    ),
  );


  // ─── Story 1 : The Little Sunflower ─────────────────────────────────────────

  static final StoryContent _sunflowerStory = StoryContent(
    id: 'peblo_story_sunflower_v1',
    title: 'The Little Sunflower',
    themeEmoji: '🌻',
    accentColor: Color(0xFFFFD740), // sunnyYellow

    // ── TTS Narrative ─────────────────────────────────────────────────────────
    // One sentence per "beat" so TTS pauses feel natural.
    narrativeText:
        'Once upon a time, a tiny seed was buried in the warm, soft ground. '
        'Every day, the rain fell gently and the sun shone brightly overhead. '
        'The little seed began to grow — first a tiny green sprout pushed through the soil. '
        'Day by day it grew taller and taller, reaching up toward the sunshine. '
        'One beautiful morning, a big bright sunflower opened its golden petals wide '
        'and turned its happy face toward the sun. '
        'It had grown all by itself, with just a little water and a lot of sunshine! '
        'The sunflower was so happy, and so was every bee and butterfly that visited it.',

    // ── Display Text ──────────────────────────────────────────────────────────
    displayText:
        'Once upon a time, a tiny seed was buried in the warm, soft ground. 🌱\n\n'
        'Every day, the rain fell gently and the sun shone brightly.\n\n'
        'The seed began to grow — first a tiny sprout, then taller and taller!\n\n'
        'One beautiful morning, a big bright sunflower opened its golden petals '
        'and turned its happy face toward the sun. 🌞\n\n'
        'It had grown all by itself, with just a little water and a lot of love! 💛',

    // ── Quiz ──────────────────────────────────────────────────────────────────
    quiz: QuizModel(
      id: 'peblo_quiz_sunflower_v1',
      question: 'What did the tiny seed grow into?',
      options: [
        QuizOption(id: 'sf_a', text: 'A tall oak tree', emoji: '🌳'),
        QuizOption(id: 'sf_b', text: 'A bright sunflower', emoji: '🌻'),
        QuizOption(id: 'sf_c', text: 'A red mushroom', emoji: '🍄'),
        QuizOption(id: 'sf_d', text: 'A little cloud', emoji: '☁️'),
      ],
      correctOptionIndex: 1,
    ),
  );

  // ─── Story 2 : Dino the Friendly Dragon ─────────────────────────────────────

  static final StoryContent _dragonStory = StoryContent(
    id: 'peblo_story_dragon_v1',
    title: 'Dino the Friendly Dragon',
    themeEmoji: '🐉',
    accentColor: AppConstants.skyBlue,

    narrativeText:
        'In a cozy green valley, surrounded by rolling hills and sparkling rivers, '
        'there lived a small dragon named Dino. '
        'All the other dragons in the valley could breathe roaring fire. '
        'But when Dino tried, out came tiny, sparkly, rainbow bubbles instead! '
        'The other dragons laughed at him and called him the bubble dragon. '
        'Dino felt sad and hid behind a tall rock. '
        'But one day, a little girl named Lily was playing nearby when her favourite ball '
        'got stuck high up in a very tall tree. '
        'Nobody could reach it! '
        'Dino took a big breath and whoooosh — a stream of shimmering bubbles floated up, '
        'gently nudging the ball free and floating it safely down into Lily\'s hands. '
        'Everyone cheered! '
        'Dino realised his bubbles were not silly at all — they were magical and kind, '
        'just like him.',

    displayText:
        'In a cozy green valley lived a small dragon named Dino. 🐉\n\n'
        'All the other dragons breathed fire — but Dino breathed sparkly rainbow bubbles! 🫧\n\n'
        'The other dragons laughed at him... until one day a little girl\'s ball '
        'got stuck in a very tall tree.\n\n'
        'Whoooosh! Dino\'s magical bubbles floated the ball safely down! ✨\n\n'
        'Everyone cheered — Dino\'s bubbles were the most magical of all! 🎉',

    quiz: QuizModel(
      id: 'peblo_quiz_dragon_v1',
      question: 'What special thing could Dino breathe instead of fire?',
      options: [
        QuizOption(id: 'dr_a', text: 'Hot flames', emoji: '🔥'),
        QuizOption(id: 'dr_b', text: 'Icy cold wind', emoji: '❄️'),
        QuizOption(id: 'dr_c', text: 'Sparkly bubbles', emoji: '🫧'),
        QuizOption(id: 'dr_d', text: 'Colourful rainbows', emoji: '🌈'),
      ],
      correctOptionIndex: 2,
    ),
  );

  // ─── Story 3 : Coral's Ocean Adventure ──────────────────────────────────────

  static final StoryContent _oceanStory = StoryContent(
    id: 'peblo_story_ocean_v1',
    title: "Coral's Ocean Adventure",
    themeEmoji: '🐠',
    accentColor: AppConstants.softMint,

    narrativeText:
        'Deep beneath the sparkling blue ocean lived a small, curious clownfish named Coral. '
        'Coral had always dreamed of exploring the ocean beyond her home reef. '
        'But her mother always said: never swim alone — always bring a friend! '
        'So Coral asked her very best friend, a gentle sea turtle named Shelly, to come along. '
        'Together they swam past rainbow-coloured coral reefs that shimmered in the water, '
        'through tall green forests of swaying seaweed, '
        'and around a giant sleeping octopus who snored in big bubbles. '
        'Deep in a hidden cave, they discovered a treasure chest! '
        'Inside were dozens of beautiful, shiny, colourful shells. '
        'Coral and Shelly gathered all the shells and swam back to share them '
        'with every fish and creature on their home reef. '
        'As they handed out the last shell, Coral smiled. '
        'Sharing made them feel far happier than keeping any treasure ever could.',

    displayText:
        'Deep beneath the sparkling blue ocean lived a curious clownfish named Coral. 🐠\n\n'
        'Her mother always said: never swim alone — always bring a friend! 🐢\n\n'
        'So Coral and her best friend Shelly the sea turtle set off together.\n\n'
        'They swam past rainbow reefs, through swaying seaweed, '
        'and found a hidden treasure chest full of beautiful shells! 🐚✨\n\n'
        'They shared every shell with every creature on the reef.\n\n'
        'Sharing made them happier than any treasure ever could. 💚',

    quiz: QuizModel(
      id: 'peblo_quiz_ocean_v1',
      question: 'What did Coral and Shelly find on their adventure?',
      options: [
        QuizOption(id: 'oc_a', text: 'A sunken pirate ship', emoji: '🚢'),
        QuizOption(id: 'oc_b', text: 'A giant octopus egg', emoji: '🐙'),
        QuizOption(
          id: 'oc_c',
          text: 'A chest full of shells',
          emoji: '🐚',
        ),
        QuizOption(id: 'oc_d', text: 'A lost submarine', emoji: '🤿'),
      ],
      correctOptionIndex: 2,
    ),
  );
}
