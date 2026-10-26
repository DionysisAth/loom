import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Player settings.
class Settings {
  const Settings({this.sound = true, this.haptics = true, this.symbols = true});
  final bool sound;
  final bool haptics;

  /// Draw a symbol on each knot and thread (colourblind support).
  final bool symbols;

  Settings copyWith({bool? sound, bool? haptics, bool? symbols}) => Settings(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    symbols: symbols ?? this.symbols,
  );

  Map<String, Object?> toJson() => {
    'sound': sound,
    'haptics': haptics,
    'symbols': symbols,
  };

  factory Settings.fromJson(Map<String, Object?> j) => Settings(
    sound: j['sound'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    symbols: j['symbols'] as bool? ?? true,
  );
}

/// Everything that persists: one small JSON file, written after every
/// cleared level and settings change.
class SaveData {
  const SaveData({
    this.level = 1,
    this.tapestry = const [],
    this.hintsUsed = 0,
    this.settings = const Settings(),
  });

  /// The next level to play.
  final int level;

  /// Ids of cleared levels, in the order they were cleared.
  final List<int> tapestry;
  final int hintsUsed;
  final Settings settings;

  SaveData copyWith({
    int? level,
    List<int>? tapestry,
    int? hintsUsed,
    Settings? settings,
  }) => SaveData(
    level: level ?? this.level,
    tapestry: tapestry ?? this.tapestry,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    settings: settings ?? this.settings,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'level': level,
    'tapestry': tapestry,
    'hintsUsed': hintsUsed,
    'settings': settings.toJson(),
  };

  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    level: j['level'] as int? ?? 1,
    tapestry: (j['tapestry'] as List? ?? const []).cast<int>(),
    hintsUsed: j['hintsUsed'] as int? ?? 0,
    settings: Settings.fromJson(
      (j['settings'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
  );
}

/// Where the save lives. Swapped for [MemorySaveStore] in tests.
abstract class SaveStore {
  Future<SaveData> load();
  Future<void> save(SaveData data);
}

class MemorySaveStore implements SaveStore {
  MemorySaveStore([this.data = const SaveData()]);
  SaveData data;
  @override
  Future<SaveData> load() async => data;
  @override
  Future<void> save(SaveData d) async => data = d;
}

class FileSaveStore implements SaveStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/loom_save.json');
  }

  @override
  Future<SaveData> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const SaveData();
      final j = jsonDecode(await f.readAsString()) as Map<String, Object?>;
      return SaveData.fromJson(j);
    } catch (e) {
      debugPrint('loom: could not read save ($e); starting fresh');
      return const SaveData();
    }
  }

  @override
  Future<void> save(SaveData data) async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('loom: could not write save ($e)');
    }
  }
}
