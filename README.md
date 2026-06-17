# Peblo AI Story Buddy & Quiz 📖🤖✨

Peblo AI Story Buddy & Quiz is a premium, magical, children's storytelling and comprehension game built with Flutter. Driven by an expressive character mascot (Doraemon) and animated procedural background environments, the app offers an immersive Saturday-morning-cartoon aesthetic designed for children aged 4–8.

---

## 🎨 Visual Features & Aesthetics

* **🤖 Peaking Doraemon Mascot:** A custom-painted vector mascot that bobs, floats, and reacts to screen states. Paws/hands dynamically overlap the story card, and the mascot switches to a happy spinning, arm-waving dance during success states.
* **🏞️ Dynamic Seasonal Worlds:** Procedural backgrounds rendered at 60 FPS that morph based on the story theme:
  * **Spring Forest:** Winding paths, swaying oak trees, flowers, drifting leaves, fireflies, and hovering birds.
  * **Rainy Garden:** Slate storm clouds, diagonal rain, and a vibrant rainbow.
  * **Winter Glacier:** Snow-capped peaks, icicles, a snowman, and falling snowflakes.
  * **Windy Ocean:** Swaying kelp strands, rising bubbles, and swimming fish.
* **📜 Storybook Parchment Card:** Classic cream card styling with ornate gold corner brackets, a slow-rotating gear header, and high-contrast word highlights.
* **✨ Progressive Text Reveal:** Narrated text reveals itself word-by-word, fully synchronized with the speech speed of the TTS engine to guide young readers.
* **📊 Voice Waveform Visualizer:** A 24-bar reactive soundwave that dances dynamically while narration is active and settles gracefully when paused.
* **🧠 Gamified 3D Quiz Options:** Custom interactive quiz cards with 3D depth-offset shadows and mechanical press-down animations.
* **🏆 Success Celebration:** Confetti bursts, drifting balloons, and gold progress star-streaks to reward the child.

---

## 🏗️ Architecture & State Machine

The codebase is engineered with strict mobile optimization patterns:
1. **Riverpod State Management:** Driven by a centralized `StateNotifier` (`StoryNotifier`) that holds a single source of truth (`StoryStateData`). Uses granular selector providers to prevent UI rebuild cascades.
2. **Pure TTS Service:** `TtsService` handles initialization, background audio recovery (phone calls/backgrounding), and native OS event marshalling.
3. **Repaint boundaries:** Isolated high-overhead canvas elements (e.g. `BuddyWidget`, `ConfettiWidget`, `VoiceWaveform`) in `RepaintBoundary` wrappers to enforce 60 FPS rendering.
4. **Zero setState coupling:** Business logic is entirely separated from widgets. Stateful widgets are only used for local animation controllers.

---

## ⚙️ Mobile Deployment Settings

We have fully audited and optimized both mobile platforms:

### Android Configuration
* **Package Visibility:** Declared `android.intent.action.TTS_SERVICE` inside `<queries>` in `AndroidManifest.xml` to prevent silent lookup failures on Android 11+ (API 30+).
* **Permissions:** Configured `android.permission.INTERNET` to allow network-based high-quality speech engine downloads and Google Fonts.
* **SDK Pinning:** Set `minSdk = 21` in `build.gradle.kts` to guarantee library compatibility.

### iOS Configuration
* **Background Audio:** Configured the `UIBackgroundModes` `audio` key inside `Info.plist` to enable uninterrupted speech playback when backgrounded.
* **Silent Mode Override:** Configured `AVAudioSession` categories inside `TtsService` (`mixWithOthers`, `defaultToSpeaker`) to play speech even when the hardware silent switch is toggled.

---

## 🚀 Getting Started

### 1. Install Dependencies
Run the standard package retriever:
```bash
flutter pub get
```

### 2. Verify Code Health
Run the analyzer to verify zero warnings or compile errors:
```bash
flutter analyze
```

### 3. Run the App
Connect a mobile device or startup an emulator, then execute:
```bash
flutter run
```

### 4. Build Production Releases
Generate ready-to-deploy release artifacts:
```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Google Play Store upload)
flutter build appbundle --release

# iOS Build (on macOS)
flutter build ios --release
```
