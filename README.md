# Loom

A chill grid puzzle for Android and iOS, built with **Godot 4.7** (GDScript, GL Compatibility renderer).
Lift the threads to weave each pattern.

Warp threads run top to bottom, each tied to a shaft (A, B, C). Each row has a weft
thread and a lift switch per shaft. Where a warp's shaft is lifted, the warp shows;
otherwise the weft does. Match the target cloth.

## MVP status

| Feature | State |
| --- | --- |
| Lift switches per row, ripple flip, win check | done |
| Tap the cloth: flips that crossing's shaft in its row, with a press preview (slide off to cancel) | done |
| Mismatch dots on crossings that differ from the target (can be turned off) | done |
| Hold the target to lay it over the cloth | done |
| Drag-to-thread warps onto shafts (tap also works) | done |
| Unlimited undo and restart, stars (3 clean / 2 with undo / 1 with hint) | done |
| Unlimited hints (set one row or one warp correctly) | done |
| Interactive 5-level tutorial (animated pointer, no reading needed) | done |
| 60 levels in 3 worlds: Lifting, Threading, Full Loom | done |
| Woven thread rendering (procedural thread sprites, shadows, dive shading) | done |
| Colourblind mode (thread textures per colour) | done |
| Quilt meta-progression (simple grid per world) | done |
| Local save, local analytics log, synthesized sounds, haptics | done |
| Bright look: Fredoka font, gradient backdrop, pill buttons, honey loom, confetti | done |
| Ads, IAP, consent | v1.0, not in the MVP |

## Project layout

```
core/autoload/   Save, Levels, Audio, Haptics, Analytics
core/ui/         menus, level select, quilt, settings, win and pause panels, theme, icons
fonts/           Fredoka (SIL Open Font License, see Fredoka-OFL.txt)
core/undo/       Command, UndoStack
game/            LoomState (pure data), LoomSolver, commands, board, cloth view, input
levels/          world_1.json ... world_3.json (generated, committed)
tools/           level generator, level preview, icon maker (not exported)
tests/           unit tests and the scene smoke test (not exported)
ci/              CI helper scripts
```

`LoomState` is plain data with no nodes. Only commands on the `UndoStack` change it,
so every move can be undone, and the solver, generator and tests reuse it without
a scene.

## Working on it

Open the folder in Godot 4.7. Useful commands (run from the repo root):

```sh
godot --headless --path . --import                                   # first time
godot --headless --path . --script res://tests/run_tests.gd          # unit tests
godot --headless --path . --script res://tests/smoke_test.gd         # drives the real scenes
godot --headless --path . --script res://tools/generate_levels.gd    # regenerate levels/*.json
godot --headless --path . --script res://tools/preview_levels.gd     # print targets as text
```

The level files are generated deterministically from `tools/level_generator.gd`.
A unit test fails if the committed JSON no longer matches the generator, so after
changing the generator, regenerate and commit the files.

Analytics events (`level_start`, `level_complete`, `hint_used`, `undo_count`,
`quit_mid_level`) are written to `user://analytics.jsonl` on the device; nothing
is sent over the network.

## CI (`.github/workflows/android.yml`)

Runs on every push to `main`, on pull requests, and on demand:

1. **Tests**: unit tests and the scene smoke test in headless Godot, plus
   screenshots of every screen (uploaded as the `screenshots` artifact).
2. **Build debug APK**: exports `loom-debug.apk` (arm64, armv7, x86_64) with the
   prebuilt template. Artifact: `loom-debug-apk`.
3. **Emulator boot test** (API 29 and 34): installs the APK, launches it, waits
   for the main menu (`LOOM_BOOT_OK` in logcat), checks it is still running in
   the foreground 15 s later with no crash, ANR or script error, then runs 600
   random monkey taps and checks again. Logcat and screenshots are uploaded.
4. **Build release AAB** (pushes only): Gradle build of `loom-release.aab` for
   Google Play, with the version code set from the run number.

### Release signing

Add these repository secrets so the AAB is signed with your upload key:

- `ANDROID_KEYSTORE_BASE64`: `base64 -w0 upload.keystore`
- `ANDROID_KEYSTORE_ALIAS`: the key alias
- `ANDROID_KEYSTORE_PASSWORD`: the keystore password (Godot needs the key password to be the same)

Without them the AAB is signed with a throwaway key: fine for checking the build,
not uploadable to Google Play. Keep a backup of the upload key somewhere safe.
