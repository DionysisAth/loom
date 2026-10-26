import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Gameplay analytics. The game only ever calls [log]; where events go is up
/// to the sink. A Firebase sink can be added once the project has a Firebase
/// config, without touching game code.
abstract class Analytics {
  void log(String event, [Map<String, Object?> params = const {}]);

  void appOpen() => log('app_open');
  void levelStart(int level) => log('level_start', {'level': level});
  void levelClear(
    int level, {
    required int seconds,
    required int hints,
    required int restarts,
    required int cuts,
  }) => log('level_clear', {
    'level': level,
    'seconds': seconds,
    'hints': hints,
    'restarts': restarts,
    'threads_cut': cuts,
  });
  void hintUsed(int level) => log('hint_used', {'level': level});
  void quitMidLevel(int level, {required int seconds}) =>
      log('quit_mid_level', {'level': level, 'seconds': seconds});
}

/// Keeps events in memory (for tests and debugging).
class MemoryAnalytics extends Analytics {
  final List<(String, Map<String, Object?>)> events = [];
  @override
  void log(String event, [Map<String, Object?> params = const {}]) =>
      events.add((event, params));
}

/// Appends events as JSON lines to a local file, ready to be uploaded or
/// inspected on test devices.
class LocalAnalytics extends Analytics {
  IOSink? _sink;
  bool _failed = false;

  Future<IOSink?> _open() async {
    if (_sink != null || _failed) return _sink;
    try {
      final dir = await getApplicationSupportDirectory();
      _sink = File('${dir.path}/loom_events.jsonl')
          .openWrite(mode: FileMode.append);
    } catch (e) {
      _failed = true;
    }
    return _sink;
  }

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    final line = jsonEncode({
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      ...params,
    });
    if (kDebugMode) debugPrint('loom analytics: $line');
    _open().then((s) => s?.writeln(line));
  }
}
