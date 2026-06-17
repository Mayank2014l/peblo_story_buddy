// lib/services/tts_service.dart
//
// Injectable TTS service with complete audio lifecycle management.
//
// ARCHITECTURE NOTE:
//   TtsService is a pure Dart class with ZERO Flutter widget coupling.
//   It exposes a Stream<TtsAudioState> that the StoryNotifier listens to.
//   All state transitions in the story flow are driven by this stream —
//   never by Future.delayed() or timers.
//
// COMPLETION CONTRACT:
//   The quiz reveal transition is driven EXCLUSIVELY by:
//       _flutterTts.setCompletionHandler(() { ... })
//   No timers. No Future.delayed(). No workarounds.
//
// HANDLED INTERRUPTION SCENARIOS:
//   1. TTS engine unavailable on the device.
//   2. Language (en-US) not supported by the device's TTS engine.
//   3. Playback interrupted by an incoming phone call.
//   4. App sent to background mid-narration.
//   5. Narration paused and resumed explicitly.
//
// AUDIO STATE MACHINE:
//   idle ──────────► loading ──► playing ──► completed
//                       │                       │
//                       └──────► error ◄─────────┘
//   playing ──► paused ──► playing   (scenario 3, 4, 5)

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../utils/constants.dart';

// ─── TtsAudioState ───────────────────────────────────────────────────────────

/// Fine-grained audio state for the TTS engine.
///
/// Consumers should treat [TtsAudioState.completed] as the canonical and
/// ONLY signal to advance the story flow to the quiz phase.
enum TtsAudioState {
  /// Engine is idle — not initialised or fully stopped.
  idle,

  /// Engine is initialising or buffering speech content.
  loading,

  /// Engine is actively narrating. Waveform should animate.
  playing,

  /// Narration is paused (phone call, background, explicit pause).
  paused,

  /// ✅ Narration finished successfully.
  /// This is the ONLY trigger for quiz reveal — no timers, no delays.
  completed,

  /// An unrecoverable error occurred. User sees friendly retry UI.
  error,
}

// ─── TtsService ──────────────────────────────────────────────────────────────

/// Manages the complete lifecycle of the flutter_tts engine for Peblo.
///
/// Inject via Riverpod [Provider] — never instantiate inside a widget.
///
/// ```dart
/// // In providers.dart:
/// final ttsServiceProvider = Provider<TtsService>((ref) {
///   final svc = TtsService();
///   ref.onDispose(svc.dispose);
///   return svc;
/// });
/// ```
///
/// Consumers subscribe to [audioStateStream] and react accordingly.
/// The [StoryNotifier] is the canonical consumer — widgets never touch this
/// class directly.
class TtsService {
  // ── Internal Engine ──────────────────────────────────────────────────────────

  final FlutterTts _flutterTts;

  // ── Stream Infrastructure ─────────────────────────────────────────────────

  final StreamController<TtsAudioState> _stateController =
      StreamController<TtsAudioState>.broadcast();

  TtsAudioState _currentState = TtsAudioState.idle;

  // ── Lifecycle Flags ───────────────────────────────────────────────────────

  bool _isInitialized = false;
  bool _isDisposed = false;

  // ── The text currently (or last) spoken; used for pause/resume support ───

  String _lastNarrativeText = '';

  // ─── Constructor ─────────────────────────────────────────────────────────────

  /// Creates a [TtsService] and immediately registers all engine callbacks.
  ///
  /// The actual TTS engine initialisation (language, rate, pitch) is deferred
  /// to [initialize()] / [speak()] to avoid blocking object construction.
  TtsService() : _flutterTts = FlutterTts() {
    _registerEngineHandlers();
  }

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// A broadcast stream of [TtsAudioState] events.
  ///
  /// Multiple listeners are supported. The [StoryNotifier] is the primary
  /// listener; test harnesses may add additional listeners.
  Stream<TtsAudioState> get audioStateStream => _stateController.stream;

  /// Synchronous snapshot of the current [TtsAudioState].
  ///
  /// Use for guard checks in synchronous code. For reactive UI, always
  /// prefer [audioStateStream].
  TtsAudioState get currentState => _currentState;

  /// Whether the TTS engine has been successfully configured.
  bool get isInitialized => _isInitialized;

  // ─── Lifecycle Methods ────────────────────────────────────────────────────────

  /// Configures the TTS engine with Peblo's speech parameters.
  ///
  /// This method is idempotent — safe to call multiple times. Subsequent
  /// calls after a successful initialisation are no-ops.
  ///
  /// Handles:
  ///   - Scenario 1: Engine unavailable → emits [TtsAudioState.error].
  ///   - Scenario 2: en-US not supported → emits [TtsAudioState.error].
  ///
  /// Never throws — errors are emitted via [audioStateStream].
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // ── Scenario 2: Verify language support before configuring ─────────────
      final dynamic rawLanguages = await _flutterTts.getLanguages;
      if (rawLanguages is List && rawLanguages.isNotEmpty) {
        final bool supported = rawLanguages
            .any((dynamic l) => l.toString().toLowerCase().startsWith('en'));
        if (!supported) {
          _emitState(TtsAudioState.error);
          return;
        }
      }
      // If getLanguages returns null/empty, proceed optimistically —
      // the engine will surface an error via setErrorHandler if needed.

      // ── Configure speech parameters ────────────────────────────────────────
      await _flutterTts.setLanguage(AppConstants.ttsLanguage);
      await _flutterTts.setSpeechRate(AppConstants.ttsSpeechRate);
      await _flutterTts.setPitch(AppConstants.ttsPitch);
      await _flutterTts.setVolume(AppConstants.ttsVolume);

      // ── Android-specific: prefer on-device synthesis ───────────────────────
      // Reduces latency and works offline (critical for children's apps).
      // Silently ignored on iOS.
      try {
        await _flutterTts.setSharedInstance(true);
      } catch (_) {
        // Non-fatal — engine may not support this API on all platforms.
      }

      // ── iOS-specific: configure audio category ─────────────────────────────
      // This is crucial for children's apps: ensures speech plays even when
      // hardware switch is toggled to silent.
      try {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (_) {
        // Non-fatal — silently ignore on non-iOS environments.
      }

      _isInitialized = true;
    } catch (_) {
      // ── Scenario 1: Engine unavailable ────────────────────────────────────
      _emitState(TtsAudioState.error);
    }
  }

  /// Narrates [text] using the configured TTS engine.
  ///
  /// Full transition sequence:
  ///   idle → loading → playing → completed   (success path)
  ///   idle → loading → error                 (failure path)
  ///
  /// The [completed] event is driven ONLY by [setCompletionHandler].
  /// No timers. No Future.delayed(). No workarounds.
  ///
  /// [text] must be non-empty. An empty string emits an error state.
  Future<void> speak(String text) async {
    if (_isDisposed) return;

    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      _emitState(TtsAudioState.error);
      return;
    }

    _lastNarrativeText = trimmed;
    _emitState(TtsAudioState.loading);

    try {
      if (!_isInitialized) {
        await initialize();
        // If initialization failed, error state was already emitted.
        if (!_isInitialized) return;
      }

      await _flutterTts.speak(trimmed);
      // ✅ Completion is signalled ONLY via setCompletionHandler below.
      // The await here resolves when speak() has been submitted to the engine,
      // NOT when narration is complete.
    } catch (_) {
      _emitState(TtsAudioState.error);
    }
  }

  /// Pauses active narration.
  ///
  /// No-op if not currently [TtsAudioState.playing].
  /// Transition: playing → paused
  ///
  /// Handles Scenario 5 (explicit pause).
  Future<void> pause() async {
    if (_isDisposed || _currentState != TtsAudioState.playing) return;
    try {
      await _flutterTts.pause();
      // State transition is handled by setPauseHandler, not here.
    } catch (_) {
      // Soft failure — pause is best-effort; narration continues.
    }
  }

  /// Resumes narration from where it was paused.
  ///
  /// NOTE: flutter_tts does not expose a native resume() API across all
  /// platforms. On Android, `speak()` with the same text is the standard
  /// resume approach. The [StoryNotifier] orchestrates this by calling
  /// [speak()] with the stored narrative text.
  ///
  /// Transition: paused → playing (via re-speak)
  Future<void> resume() async {
    if (_isDisposed || _currentState != TtsAudioState.paused) return;
    if (_lastNarrativeText.isNotEmpty) {
      await speak(_lastNarrativeText);
    }
  }

  /// Stops narration and resets audio state to [TtsAudioState.idle].
  ///
  /// Safe to call from any state. Always resolves — never throws.
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _flutterTts.stop();
    } catch (_) {
      // Engine stop always resolves — emit idle regardless.
    } finally {
      _emitState(TtsAudioState.idle);
    }
  }

  /// Releases all TTS resources and closes the state stream.
  ///
  /// Idempotent — safe to call multiple times. After disposal, all method
  /// calls are no-ops.
  ///
  /// Called automatically by Riverpod via [ref.onDispose].
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      await _flutterTts.stop();
    } catch (_) {
      // Ignore — we're tearing down regardless.
    }

    if (!_stateController.isClosed) {
      await _stateController.close();
    }

    _isInitialized = false;
  }

  // ─── Engine Handler Registration ─────────────────────────────────────────────

  /// Registers all flutter_tts engine event callbacks.
  ///
  /// Called once in the constructor. Each callback maps a TTS engine event
  /// to a [TtsAudioState] emission on [_stateController].
  ///
  /// IMPORTANT: Callbacks fire on the platform thread and are marshalled
  /// to the Dart event loop. They should be fast and non-blocking.
  void _registerEngineHandlers() {
    // ── Narration started successfully ────────────────────────────────────────
    _flutterTts.setStartHandler(() {
      _emitState(TtsAudioState.playing);
    });

    // ── ✅ THE ONLY QUIZ REVEAL TRIGGER ───────────────────────────────────────
    // This callback fires when the TTS engine has finished narrating the full
    // text. The StoryNotifier listens for TtsAudioState.completed and
    // transitions to StoryState.quizVisible.
    //
    // ❌ DO NOT add Future.delayed() here.
    // ❌ DO NOT add Timer here.
    // ❌ DO NOT add any completion logic elsewhere.
    _flutterTts.setCompletionHandler(() {
      _emitState(TtsAudioState.completed);
    });

    // ── Scenario 3: Phone call interrupted narration ──────────────────────────
    // ── Scenario 4: App was backgrounded mid-narration ───────────────────────
    // The OS cancels TTS when the app loses audio focus.
    _flutterTts.setCancelHandler(() {
      if (_currentState == TtsAudioState.playing) {
        _emitState(TtsAudioState.paused);
      }
    });

    // ── Scenario 5: Explicit pause (platform gesture or system pause) ─────────
    _flutterTts.setPauseHandler(() {
      _emitState(TtsAudioState.paused);
    });

    // ── Scenario 5: Resumed after pause ──────────────────────────────────────
    _flutterTts.setContinueHandler(() {
      _emitState(TtsAudioState.playing);
    });

    // ── All error paths converge here ─────────────────────────────────────────
    // The [message] parameter is intentionally ignored — Peblo never shows
    // raw engine error messages to children.
    _flutterTts.setErrorHandler((dynamic message) {
      _emitState(TtsAudioState.error);
    });
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  /// Emits [newState] to [_stateController] if the service is still active.
  ///
  /// Guards against emission after disposal (isClosed) and self-transitions
  /// (same state emitted twice in a row) to minimise downstream rebuilds.
  void _emitState(TtsAudioState newState) {
    if (_isDisposed || _stateController.isClosed) return;
    if (_currentState == newState) return; // Suppress redundant transitions.
    _currentState = newState;
    _stateController.add(newState);
  }
}
