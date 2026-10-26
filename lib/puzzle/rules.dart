import 'dart:typed_data';

import 'puzzle.dart';

/// An analysis of a set of threads on a puzzle: who fills which cell slot, how
/// each thread enters and leaves each cell, which threads are complete, and
/// which local rules are broken.
class Weave {
  Weave(this.puzzle, Map<int, List<int>> threads)
    : threads = Map.unmodifiable(threads),
      _occ = Int32List(puzzle.cellCount * 2)
        ..fillRange(0, puzzle.cellCount * 2, -1),
      _links = Int32List(puzzle.cellCount) {
    for (final entry in threads.entries) {
      _lay(entry.key, entry.value);
    }
  }

  final Puzzle puzzle;
  final Map<int, List<int>> threads;
  final Int32List _occ;
  final Int32List _links;

  /// Structural problems (overlaps, gaps, turns inside crossings). The board
  /// never produces these; they catch broken level files.
  final List<String> errors = [];

  void _lay(int colour, List<int> path) {
    final p = puzzle;
    for (var i = 0; i < path.length; i++) {
      final cell = path[i];
      if (cell < 0 || cell >= p.cellCount || p.isHole(cell)) {
        errors.add('thread $colour enters a hole or leaves the hoop at $i');
        return;
      }
      var inDir = -1;
      if (i > 0) {
        inDir = p.dirBetween(path[i - 1], cell);
        if (inDir < 0) {
          errors.add('thread $colour jumps at step $i');
          return;
        }
      }
      final outDir = i + 1 < path.length ? p.dirBetween(cell, path[i + 1]) : -1;
      if (i == 0 && p.knotColourAt(cell) != colour) {
        errors.add('thread $colour does not start at its knot');
      }
      if (i > 0 && p.isKnot(cell)) {
        final ok = p.knotColourAt(cell) == colour && i == path.length - 1;
        if (!ok) errors.add('thread $colour passes through a knot at step $i');
      }
      var slot = cell * 2;
      if (p.isCrossing(cell)) {
        if (inDir < 0) {
          errors.add('thread $colour starts inside a crossing');
          return;
        }
        if (outDir >= 0 && outDir != inDir) {
          errors.add('thread $colour turns inside a crossing');
        }
        slot += axisOfDir(inDir);
      } else {
        if (inDir >= 0) _links[cell] |= 1 << oppositeDir(inDir);
        if (outDir >= 0) _links[cell] |= 1 << outDir;
      }
      if (_occ[slot] != -1) {
        errors.add('thread $colour overlaps thread ${_occ[slot]} at step $i');
      } else {
        _occ[slot] = colour;
      }
    }
  }

  /// Colour filling [cell] on [axis] (axis is ignored for normal cells), or -1.
  int occupant(int cell, [int axis = axisH]) =>
      _occ[cell * 2 + (puzzle.isCrossing(cell) ? axis : 0)];

  /// The colour seen on top of [cell], or -1.
  int topColour(int cell) => puzzle.isCrossing(cell)
      ? _occ[cell * 2 + puzzle.overAxis(cell)]
      : _occ[cell * 2];

  /// Bitmask of directions the thread on a normal cell connects to.
  int links(int cell) => _links[cell];

  bool isFilled(int cell) {
    if (puzzle.isHole(cell)) return true;
    if (puzzle.isCrossing(cell)) {
      return _occ[cell * 2] != -1 && _occ[cell * 2 + 1] != -1;
    }
    return _occ[cell * 2] != -1;
  }

  int get filledSlots {
    var n = 0;
    for (var i = 0; i < _occ.length; i++) {
      if (_occ[i] != -1) n++;
    }
    return n;
  }

  bool isComplete(int colour) {
    final path = threads[colour];
    if (path == null || path.length < 2) return false;
    final k = puzzle.knotOf(colour);
    return (path.first == k.a && path.last == k.b) ||
        (path.first == k.b && path.last == k.a);
  }

  int get completeCount =>
      puzzle.knots.where((k) => isComplete(k.colour)).length;

  /// Cells that currently break a local rule.
  Set<int> get violations => {for (final r in rules) ...r.violations(this)};

  bool get isCleared {
    if (errors.isNotEmpty) return false;
    for (final k in puzzle.knots) {
      if (!isComplete(k.colour)) return false;
    }
    for (var c = 0; c < puzzle.cellCount; c++) {
      if (!isFilled(c)) return false;
    }
    return violations.isEmpty;
  }
}

/// One mechanic's local check. A new mechanic means one new rule here plus its
/// drawing in the board painter.
abstract class Rule {
  const Rule();
  String get id;

  /// Cells breaking this rule given what is already laid.
  Iterable<int> violations(Weave w);
}

const int _straightH = 1 << 0 | 1 << 2;
const int _straightV = 1 << 1 | 1 << 3;

int _bits(int m) {
  var n = 0;
  for (; m != 0; m &= m - 1) {
    n++;
  }
  return n;
}

class BeadRule extends Rule {
  const BeadRule();
  @override
  String get id => 'bead';

  @override
  Iterable<int> violations(Weave w) sync* {
    for (final e in w.puzzle.features.entries) {
      if (e.value.kind != FeatureKind.bead) continue;
      final l = w.links(e.key);
      if (_bits(l) == 2 && l != _straightH && l != _straightV) yield e.key;
    }
  }
}

class PinRule extends Rule {
  const PinRule();
  @override
  String get id => 'pin';

  @override
  Iterable<int> violations(Weave w) sync* {
    for (final e in w.puzzle.features.entries) {
      if (e.value.kind != FeatureKind.pin) continue;
      final l = w.links(e.key);
      if (l == _straightH || l == _straightV) yield e.key;
    }
  }
}

class EyeletRule extends Rule {
  const EyeletRule();
  @override
  String get id => 'eyelet';

  @override
  Iterable<int> violations(Weave w) sync* {
    for (final e in w.puzzle.features.entries) {
      if (e.value.kind != FeatureKind.eyelet) continue;
      final c = e.key;
      if (w.puzzle.isCrossing(c)) {
        final h = w.occupant(c, axisH), v = w.occupant(c, axisV);
        if (h != -1 && v != -1 && h != e.value.colour && v != e.value.colour) {
          yield c;
        }
      } else {
        final o = w.occupant(c);
        if (o != -1 && o != e.value.colour) yield c;
      }
    }
  }
}

class StitchRule extends Rule {
  const StitchRule();
  @override
  String get id => 'stitch';

  @override
  Iterable<int> violations(Weave w) sync* {
    for (final e in w.puzzle.features.entries) {
      if (e.value.kind != FeatureKind.stitch) continue;
      final top = w.topColour(e.key);
      if (top != -1 && top != e.value.colour) yield e.key;
    }
  }
}

class SpoolRule extends Rule {
  const SpoolRule();
  @override
  String get id => 'spool';

  @override
  Iterable<int> violations(Weave w) sync* {
    for (final k in w.puzzle.knots) {
      final n = k.spool;
      if (n == null) continue;
      final len = w.threads[k.colour]?.length ?? 0;
      if (len > n || (w.isComplete(k.colour) && len != n)) {
        yield k.a;
        yield k.b;
      }
    }
  }
}

const List<Rule> rules = [
  BeadRule(),
  PinRule(),
  EyeletRule(),
  StitchRule(),
  SpoolRule(),
];
