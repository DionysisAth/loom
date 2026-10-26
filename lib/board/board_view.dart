import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/audio.dart';
import '../core/haptics.dart';
import '../puzzle/board.dart';
import '../puzzle/puzzle.dart';
import 'board_painter.dart';
import 'layout.dart';

/// Stats for one cleared level, reported to analytics.
class ClearStats {
  const ClearStats({
    required this.seconds,
    required this.hints,
    required this.restarts,
    required this.cuts,
  });
  final int seconds;
  final int hints;
  final int restarts;
  final int cuts;
}

/// Lets the level screen ask the board for hints and restarts.
class BoardController {
  _BoardViewState? _state;

  /// Lays one correct thread. Returns false if there is nothing to hint.
  bool hint() => _state?._hint() ?? false;

  /// Clears every thread.
  void restart() => _state?._restart();

  /// Whether the player has laid anything yet.
  bool get started => _state?._started ?? false;
}

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.puzzle,
    required this.controller,
    required this.sfx,
    required this.haptics,
    this.symbols = true,
    this.onProgress,
    this.onCleared,
  });

  final Puzzle puzzle;
  final BoardController controller;
  final Sfx sfx;
  final Haptics haptics;
  final bool symbols;

  /// Called whenever the player gets further than before (for the hint timer).
  final VoidCallback? onProgress;

  /// Called after the clear animation has played.
  final ValueChanged<ClearStats>? onCleared;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late Board _board;
  late final Ticker _ticker;

  /// Board time. Keeps counting across ticker restarts.
  Duration _now = Duration.zero;
  Duration _offset = Duration.zero;

  int? _pointer;
  Offset? _finger;
  int? _snapColour;
  Duration? _snapStart;
  final Map<int, Duration> _knotPulses = {};
  int? _growColour;
  Duration? _growStart;
  Duration _growLength = Duration.zero;
  Duration? _tightenStart;
  bool _cleared = false;

  // Teaching finger.
  bool _ghostOn = false;
  Duration _ghostStart = Duration.zero;
  Duration _lastTouch = Duration.zero;

  // Stats.
  final Stopwatch _clock = Stopwatch();
  int _hints = 0;
  int _restarts = 0;
  int _cuts = 0;
  int _bestProgress = 0;
  bool _started = false;

  static const _snap = Duration(milliseconds: 160);
  static const _pulse = Duration(milliseconds: 380);
  static const _tighten = Duration(milliseconds: 900);
  static const _ghostLoop = Duration(milliseconds: 3600);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    widget.controller._state = this;
    _reset();
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
    if (old.puzzle != widget.puzzle) _reset();
  }

  void _reset() {
    _board = Board(widget.puzzle);
    _pointer = null;
    _finger = null;
    _snapColour = null;
    _knotPulses.clear();
    _growColour = null;
    _tightenStart = null;
    _cleared = false;
    _hints = 0;
    _restarts = 0;
    _cuts = 0;
    _bestProgress = 0;
    _started = false;
    _clock
      ..reset()
      ..start();
    _ghostOn = widget.puzzle.teachColour != null;
    _ghostStart = _now;
    _lastTouch = _now;
    _kick();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ ticking --

  void _kick() {
    if (_ticker.isActive) return;
    _offset = _now;
    _ticker.start();
  }

  /// Teaching levels keep time so the finger can come back.
  bool get _teaching =>
      widget.puzzle.teachColour != null &&
      !_cleared &&
      !_board.isConnected(widget.puzzle.teachColour!);

  bool get _animating =>
      _ghostOn ||
      _teaching ||
      _snapColour != null ||
      _knotPulses.isNotEmpty ||
      _growColour != null ||
      _tightenStart != null ||
      _board.weave.violations.isNotEmpty;

  void _tick(Duration elapsed) {
    _now = _offset + elapsed;
    if (_snapStart != null && _now - _snapStart! > _snap) {
      _snapColour = null;
      _snapStart = null;
    }
    _knotPulses.removeWhere((_, start) => _now - start > _pulse);
    if (_growColour != null && _now - _growStart! > _growLength) {
      _growColour = null;
      _afterChange();
    }
    if (_tightenStart != null && _now - _tightenStart! > _tighten) {
      _tightenStart = null;
      widget.onCleared?.call(
        ClearStats(
          seconds: _clock.elapsed.inSeconds,
          hints: _hints,
          restarts: _restarts,
          cuts: _cuts,
        ),
      );
    }
    // Bring the teaching finger back if the player stalls.
    if (!_ghostOn &&
        _teaching &&
        _pointer == null &&
        _now - _lastTouch > const Duration(seconds: 7)) {
      _ghostOn = true;
      _ghostStart = _now;
    }
    if (mounted) setState(() {});
    if (!_animating && _pointer == null) _ticker.stop();
  }

  // ------------------------------------------------------------- input --

  BoardLayout _layout() => BoardLayout(widget.puzzle, context.size!);

  bool get _busy => _cleared || _growColour != null;

  void _down(PointerDownEvent e) {
    if (_pointer != null || _busy) return;
    _pointer = e.pointer;
    _ghostOn = false;
    _lastTouch = _now;
    final l = _layout();
    final colour = _board.begin(l.cellAt(e.localPosition));
    if (colour != null) {
      _finger = e.localPosition;
      _snapColour = null;
      widget.haptics.tick();
      widget.sfx.pluck(_board.threadOf(colour)!.length - 1);
    }
    _kick();
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || _board.active == null) return;
    _lastTouch = _now;
    _finger = e.localPosition;
    final l = _layout();
    final path = _board.threadOf(_board.active!)!;
    final head = path.last;
    // A little stickiness around the current cell avoids jitter on borders.
    final headRect = l.cellRect(head).inflate(l.cell * 0.12);
    if (!headRect.contains(e.localPosition)) {
      final target = l.grid.inflate(l.cell * 0.4).contains(e.localPosition)
          ? l.nearestCell(e.localPosition)
          : -1;
      if (target >= 0) _apply(_board.extend(target));
    }
    setState(() {});
  }

  void _apply(Move m) {
    final colour = _board.active;
    if (colour == null) return;
    final path = _board.threadOf(colour)!;
    for (var i = 0; i < m.entered.length; i++) {
      widget.haptics.tick();
      widget.sfx.pluck(path.length - m.entered.length + i);
    }
    if (m.connected) {
      widget.haptics.knot();
      widget.sfx.knot();
      _knotPulses[colour] = _now;
    }
    if (m.changed) {
      _started = true;
      _afterChange(duringDrag: true);
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final colour = _board.active;
    _cuts += _board.end();
    if (colour != null && !_board.isConnected(colour)) {
      _snapColour = colour;
      _snapStart = _now;
    }
    _afterChange();
    _kick();
    setState(() {});
  }

  void _afterChange({bool duringDrag = false}) {
    final progress = _board.progress;
    if (progress > _bestProgress) {
      _bestProgress = progress;
      widget.onProgress?.call();
    }
    if (!_cleared && _board.isCleared) {
      if (duringDrag) {
        _cuts += _board.end();
        _pointer = null;
      }
      _cleared = true;
      _clock.stop();
      _ghostOn = false;
      _tightenStart = _now;
      widget.sfx.clear();
      widget.haptics.clear();
      _kick();
    }
  }

  // ---------------------------------------------------------- commands --

  bool _hint() {
    if (_busy) return false;
    if (_pointer != null) {
      _cuts += _board.end();
      _pointer = null;
    }
    final colour = _board.hintColour();
    if (colour == null) return false;
    final path = widget.puzzle.knotOf(colour).path;
    _cuts += _board.lay(colour, path);
    _hints++;
    _started = true;
    _growColour = colour;
    _growStart = _now;
    _growLength = Duration(milliseconds: min(1100, 90 * path.length + 200));
    _ghostOn = false;
    widget.sfx.hint();
    widget.haptics.knot();
    _kick();
    setState(() {});
    return true;
  }

  void _restart() {
    if (_busy) return;
    _board.clearAll();
    _pointer = null;
    _restarts++;
    _snapColour = null;
    setState(() {});
  }

  // ------------------------------------------------------------ build --

  Set<int> get _teachCells {
    final p = widget.puzzle;
    if (p.teachColour == null) return const {};
    return switch (p.mechanic) {
      'crossings' => {
        for (var c = 0; c < p.cellCount; c++)
          if (p.isCrossing(c)) c,
      },
      'spools' => {
        for (final k in p.knots)
          if (k.spool != null) ...[k.a, k.b],
      },
      'beads' || 'eyelets' || 'stitches' => p.features.keys.toSet(),
      _ => const {},
    };
  }

  double _t(Duration? start, Duration length) => start == null
      ? 0
      : ((_now - start).inMicroseconds / length.inMicroseconds).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    final dragging = _board.active;
    final tailColour = dragging ?? _snapColour;
    var tail = 0.0;
    if (dragging != null && !_board.isConnected(dragging)) {
      tail = 1;
    } else if (_snapColour != null) {
      final t = _t(_snapStart, _snap);
      tail = 1 - Curves.easeOutBack.transform(t).clamp(0.0, 1.2);
      tail = tail.clamp(0.0, 1.0);
    }
    final ghostT = _ghostOn
        ? ((_now - _ghostStart).inMicroseconds % _ghostLoop.inMicroseconds) /
              _ghostLoop.inMicroseconds
        : 0.0;
    final scene = BoardScene(
      puzzle: p,
      threads: _board.threads,
      weave: _board.weave,
      active: tailColour,
      finger: _finger,
      tailAmount: tail,
      symbols: widget.symbols,
      teachCells: _ghostOn ? _teachCells : const {},
      knotPulse: {
        for (final e in _knotPulses.entries) e.key: _t(e.value, _pulse),
      },
      growColour: _growColour,
      grow: _growColour == null
          ? 1
          : Curves.easeInOut.transform(_t(_growStart, _growLength)),
      tighten: _tightenStart == null
          ? (_cleared ? 1 : 0)
          : _t(_tightenStart, _tighten),
      ghostPath: _ghostOn ? p.knotOf(p.teachColour!).path : null,
      ghostT: ghostT,
      time: _now.inMicroseconds / 1e6,
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Semantics(
        label: 'Hoop, level ${p.id}',
        child: CustomPaint(painter: BoardPainter(scene), size: Size.infinite),
      ),
    );
  }
}
