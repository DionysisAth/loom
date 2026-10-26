import 'package:flutter/widgets.dart';

import 'analytics.dart';
import 'audio.dart';
import 'haptics.dart';
import 'levels.dart';
import 'save.dart';

/// App-wide state: progress, settings and the feedback services.
class Game extends ChangeNotifier {
  Game({
    required this.store,
    required this.sfx,
    required this.haptics,
    required this.analytics,
    required this.levels,
  });

  final SaveStore store;
  final Sfx sfx;
  final Haptics haptics;
  final Analytics analytics;
  final LevelRepository levels;

  SaveData _data = const SaveData();
  SaveData get data => _data;
  Settings get settings => _data.settings;

  /// The next level to play.
  int get level => _data.level;

  /// All bundled levels are cleared.
  bool get finished => level > levels.total;

  Future<void> init() async {
    await levels.load();
    _data = await store.load();
    _apply();
    analytics.appOpen();
    notifyListeners();
  }

  void _apply() {
    sfx.enabled = settings.sound;
    haptics.enabled = settings.haptics;
  }

  Future<void> levelCleared(
    int id, {
    required int seconds,
    required int hints,
    required int restarts,
    required int cuts,
  }) async {
    analytics.levelClear(
      id,
      seconds: seconds,
      hints: hints,
      restarts: restarts,
      cuts: cuts,
    );
    if (id != level) return;
    _data = _data.copyWith(level: id + 1, tapestry: [..._data.tapestry, id]);
    notifyListeners();
    await store.save(_data);
  }

  Future<void> hintUsed(int id) async {
    analytics.hintUsed(id);
    _data = _data.copyWith(hintsUsed: _data.hintsUsed + 1);
    await store.save(_data);
  }

  Future<void> updateSettings(Settings s) async {
    _data = _data.copyWith(settings: s);
    _apply();
    notifyListeners();
    await store.save(_data);
  }

  Future<void> resetProgress() async {
    _data = SaveData(settings: settings);
    notifyListeners();
    await store.save(_data);
  }
}

/// Makes the [Game] available to the widget tree.
class GameScope extends InheritedNotifier<Game> {
  const GameScope({super.key, required Game game, required super.child})
    : super(notifier: game);

  static Game of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;

  /// Reads the game without rebuilding when it changes.
  static Game read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameScope>()!.notifier!;
}
