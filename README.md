# Loom

A calm, tactile thread puzzle for Android and iOS, built with Flutter.

Each level is an embroidery hoop with pairs of coloured knots. Drag a thread
from a knot to its twin, cell by cell, and fill the whole hoop. At a crossing,
two threads pass through each other, one over and one under. When the last
cell is filled the threads tighten, the piece lifts out, and the next hoop
slides in.

This is the MVP test build from the game plan: 60 levels in 8 chapters.

| Chapter | Levels | Mechanic |
| --- | --- | --- |
| 1 | 1–6 | Threads: connect the knots and fill the hoop |
| 2 | 7–13 | Crossings: one thread over, one under |
| 3 | 14–20 | Shaped hoops |
| 4 | 21–27 | Beads (pass straight) and pins (turn here) |
| 5 | 28–34 | Eyelets (this colour must pass through) |
| 6 | 35–41 | Picture stitches (this colour must be on top) |
| 7 | 42–49 | Spools (the thread must be exactly this long) |
| 8 | 50–60 | Mix |

Each chapter opens with two teaching levels (an animated finger shows the new
idea, no text) and ends with a showpiece whose finished threads form a
picture: heart, fish, flower, tree, boat, butterfly, house, moon and star.

## Running it

```sh
flutter pub get
flutter run            # on a connected phone or simulator
flutter test           # rules, solver, every level file, app flow
flutter test integration_test/app_test.dart   # on a device: opens the app and clears level 1
```

## Project layout

```
lib/
  main.dart          app entry; createGame() wires the real services
  app.dart           MaterialApp and start-up
  core/              save, settings, sound, haptics, analytics, palette, levels
  puzzle/            pure Dart: puzzle model, rules, board (drag rules), solver, generator
  board/             hoop and yarn painter, touch input and animations, icons
  screens/           home (Continue + tapestry), level, chapter card, tapestry, settings
assets/
  levels/            chapter_01.json ... chapter_08.json + index.json (generated, committed)
  audio/             plucked-yarn notes (generated)
  art/               icon source
tool/
  generate.dart      builds the level files from tool/src/chapters.dart
  probe.dart         shows how often a level slot generates and why attempts fail
  make_sounds.dart   synthesises the sound effects
  make_icon.py       draws the placeholder app icon in every size
test/                unit and widget tests
integration_test/    on-device launch test
```

The puzzle code has no Flutter imports, so the same rules run in the app, the
tests and the level tools.

### Rules in code

- `Weave` (`lib/puzzle/rules.dart`) analyses laid threads: who fills each
  cell, how each thread enters and leaves it, which threads are complete.
- Each mechanic is one small `Rule` class (bead, pin, eyelet, stitch, spool).
  A new mechanic is one new rule plus its drawing in `board_painter.dart`.
- `Board` (`lib/puzzle/board.dart`) holds the drag rules: start at a knot,
  grow, back up, loop back, cut through other threads (they grow back if you
  back away during the same drag), pass straight through crossings.
- The weave decides who is on top at a crossing: on cells where `x + y` is
  even the horizontal thread is over, otherwise the vertical one.

## Levels

Levels are generated offline and committed:

```sh
dart run tool/generate.dart          # all chapters (a few minutes)
dart run tool/generate.dart --only=4 # one chapter
```

The generator covers the hoop with random paths, puts knots at the ends, and
asks the solver whether the solution is unique. If it is not, it adds a clue
of the chapter's mechanic (bead, pin, eyelet, stitch or spool) where the
intended solution and the other one differ, then removes clues that turn out
not to be needed. Every level has exactly one solution, so hints (which lay
the stored solution thread) are always right. `test/levels_test.dart` checks
this for every level on every CI run.

Chapter plans, hoop shapes and showpiece pictures are in
`tool/src/chapters.dart`. A showpiece is drawn as letters, one per region;
each thread stays inside one region, so the finished threads form the
picture. Background regions use muted yarns so the motif stands out.

## Analytics

Events: `app_open`, `level_start`, `level_clear` (seconds, hints, restarts,
threads cut), `hint_used`, `quit_mid_level`. In this build they are written
to `loom_events.jsonl` in the app's support folder (`LocalAnalytics`). To send
them to Firebase, add the Firebase config files and implement an `Analytics`
sink; game code only calls `Analytics.log`.

## CI/CD

`.github/workflows/ci.yml`:

1. **Analyze and test**: format check, `flutter analyze`, `flutter test`
   (includes solving every level file).
2. **Android**: builds the APK and AAB, and runs the launch test on emulators
   with API 29 and 34 (opens the app, clears level 1 by dragging).
3. **iOS**: builds for the simulator and runs the same launch test on a
   simulator.
4. **Release**: once the Android checks pass, publishes the APK as a GitHub
   release. Pushes to `main` update `latest`
   (`releases/download/latest/loom.apk`); pushes to other branches update
   `preview` (`releases/download/preview/loom.apk`).

Store uploads switch on by themselves once these repository secrets exist:

| Secret | Used for |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Release-signing the APK and AAB (otherwise they use the debug key) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Uploading the AAB to Play internal testing (`android/fastlane`) |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `APPLE_TEAM_ID` | Signed IPA and TestFlight upload (`ios/fastlane`) |

Google Play needs the first AAB of a new app uploaded by hand in the Play
Console. Keep a backup of the Android upload key.

## Not in this build

From the plan's v1.0 column, still to do: chapters 9–12 (tassels, sleeve,
mirror hoop, dye pots), the hint economy (3 free per day, rewarded ads,
purchase), ads, remove-ads purchase, UMP consent, music, final art, and store
accounts and listings.
