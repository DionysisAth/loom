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

class PooledSfx extends Sfx {
  static const _plucks = 12;
  final Map<String, AudioPool> _pools = {};
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

  Future<AudioPool?> _load(String name) async {
    if (_broken) return null;
    final existing = _pools[name];
    if (existing != null) return existing;
    if (!_loading.add(name)) return null;
    try {
      final pool = await AudioPool.create(
        source: AssetSource('audio/$name.wav'),
        maxPlayers: name.startsWith('pluck') ? 2 : 1,
        playerMode: PlayerMode.lowLatency,
      );
      _pools[name] = pool;
      return pool;
    } catch (e) {
      debugPrint('loom: audio unavailable ($e)');
      _broken = true;
      return null;
    } finally {
      _loading.remove(name);
    }
  }

  void _play(String name, double volume) {
    if (!enabled || _broken) return;
    final pool = _pools[name];
    if (pool == null) {
      _load(name);
      return;
    }
    pool.start(volume: volume).catchError((Object e) {
      debugPrint('loom: audio failed ($e)');
      return () async {};
    });
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
