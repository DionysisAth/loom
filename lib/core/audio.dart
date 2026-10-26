import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plucked-yarn sound effects. Every call is fire-and-forget and never
/// throws: a missing audio device must not break the game.
abstract class Sfx {
  bool enabled = true;

  /// A rising note for each cell a thread enters; [step] is the thread length.
  void pluck(int step);

  /// A deeper note when a thread reaches its twin knot.
  void knot();

  /// The strum as the hoop clears.
  void clear();

  /// A soft bell when a hint is laid.
  void hint();

  Future<void> warmUp() async {}
}

class SilentSfx extends Sfx {
  final List<String> played = [];
  @override
  void pluck(int step) => played.add('pluck');
  @override
  void knot() => played.add('knot');
  @override
  void clear() => played.add('clear');
  @override
  void hint() => played.add('hint');
}

/// Plays each sound from a few preloaded low-latency players, round robin.
class PooledSfx extends Sfx {
  static const _plucks = 12;
  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _next = {};
  final Set<String> _loading = {};
  bool _broken = false;

  @override
  Future<void> warmUp() async {
    for (var i = 0; i < _plucks; i++) {
      await _load('pluck_${i.toString().padLeft(2, '0')}');
    }
    await _load('knot');
    await _load('clear');
    await _load('hint');
  }

  Future<void> _load(String name) async {
    if (_broken || _players.containsKey(name) || !_loading.add(name)) return;
    try {
      final count = name.startsWith('pluck') ? 2 : 1;
      final list = <AudioPlayer>[];
      for (var i = 0; i < count; i++) {
        final p = AudioPlayer()
          // We never read the playback position; without this the player
          // asks for a new frame on every tick while a sound plays.
          ..positionUpdater = null;
        // A stuck audio device must never hold the game up.
        const limit = Duration(seconds: 5);
        await p.setPlayerMode(PlayerMode.lowLatency).timeout(limit);
        await p.setReleaseMode(ReleaseMode.stop).timeout(limit);
        await p.setSource(AssetSource('audio/$name.wav')).timeout(limit);
        list.add(p);
      }
      _players[name] = list;
    } catch (e) {
      debugPrint('loom: audio unavailable ($e)');
      _broken = true;
    } finally {
      _loading.remove(name);
    }
  }

  void _play(String name, double volume) {
    if (!enabled || _broken) return;
    final list = _players[name];
    if (list == null) {
      _load(name);
      return;
    }
    final i = _next[name] ?? 0;
    _next[name] = (i + 1) % list.length;
    final player = list[i];
    () async {
      try {
        await player.stop();
        await player.setVolume(volume);
        await player.resume();
      } catch (e) {
        debugPrint('loom: audio failed ($e)');
      }
    }();
  }

  @override
  void pluck(int step) {
    final i = step.clamp(0, _plucks - 1);
    _play('pluck_${i.toString().padLeft(2, '0')}', 0.55);
  }

  @override
  void knot() => _play('knot', 0.8);
  @override
  void clear() => _play('clear', 0.9);
  @override
  void hint() => _play('hint', 0.6);
}
