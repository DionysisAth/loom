import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/analytics.dart';
import 'core/audio.dart';
import 'core/game.dart';
import 'core/haptics.dart';
import 'core/levels.dart';
import 'core/save.dart';

/// Builds the game with real services; tests swap in their own.
Game createGame({SaveStore? store, Sfx? sfx, Analytics? analytics}) => Game(
  store: store ?? FileSaveStore(),
  sfx: sfx ?? PooledSfx(),
  haptics: Haptics(),
  analytics: analytics ?? LocalAnalytics(),
  levels: LevelRepository(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final game = createGame();
  runApp(LoomApp(game: game));
  // Load sounds after the first frame so start-up stays fast.
  WidgetsBinding.instance.addPostFrameCallback((_) => game.sfx.warmUp());
}
