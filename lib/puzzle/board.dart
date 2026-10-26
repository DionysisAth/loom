import 'puzzle.dart';
import 'rules.dart';

/// What happened during one call to [Board.extend].
class Move {
  const Move({this.entered = const [], this.left = 0, this.connected = false});

  /// Cells the thread end entered, in order.
  final List<int> entered;

  /// How many cells the thread end gave back (backtracking or looping back).
  final int left;

  /// The thread reached its twin knot.
  final bool connected;

  bool get changed => entered.isNotEmpty || left > 0;
  static const none = Move();
}

/// The threads laid so far, and the drag rules that change them.
///
/// Threads are stored as cell lists starting at the knot they were drawn from.
/// While a drag is active, the other threads are recomputed from a snapshot
/// taken when the drag began, so a thread that gets cut grows back if the
/// dragged thread backs away again.
class Board {
  Board(this.puzzle);

  final Puzzle puzzle;
  final Map<int, List<int>> _threads = {};
  Map<int, List<int>>? _snapshot;
  int? _active;
  Weave? _weave;

  /// Colour being dragged, or null.
  int? get active => _active;

  Map<int, List<int>> get threads => Map.unmodifiable(_threads);
  List<int>? threadOf(int colour) => _threads[colour];

  Weave get weave => _weave ??= Weave(puzzle, _threads);
  bool get isCleared => weave.isCleared;

  void _changed() => _weave = null;

  // ------------------------------------------------------------ dragging --

  /// Starts a drag on [cell]: from a knot (which clears its thread) or from
  /// any cell of a laid thread (which cuts the thread back to that cell).
  /// Returns the colour being drawn, or null if nothing can start here.
  int? begin(int cell) {
    end();
    if (cell < 0 || cell >= puzzle.cellCount || puzzle.isHole(cell)) {
      return null;
    }
    final knot = puzzle.knotColourAt(cell);
    if (knot >= 0) {
      _threads[knot] = [cell];
      _startDrag(knot);
      return knot;
    }
    final w = weave;
    final candidates = puzzle.isCrossing(cell)
        ? [w.topColour(cell), w.occupant(cell, 1 - puzzle.overAxis(cell))]
        : [w.occupant(cell)];
    for (final colour in candidates) {
      if (colour < 0) continue;
      final path = _threads[colour]!;
      final axis = puzzle.isCrossing(cell)
          ? (colour == w.occupant(cell, axisH) ? axisH : axisV)
          : -1;
      final j = _indexOf(path, cell, axis);
      if (j < 0) continue;
      _threads[colour] = path.sublist(0, j + 1);
      _startDrag(colour);
      return colour;
    }
    return null;
  }

  void _startDrag(int colour) {
    _active = colour;
    _snapshot = {
      for (final e in _threads.entries)
        if (e.key != colour) e.key: List.of(e.value),
    };
    _changed();
  }

  /// Moves the end of the active thread toward [cell]. Cells further than one
  /// step away are reached one step at a time, so fast drags never skip.
  Move extend(int cell) {
    final colour = _active;
    if (colour == null || cell < 0 || cell >= puzzle.cellCount) {
      return Move.none;
    }
    final entered = <int>[];
    var left = 0;
    var connected = false;
    for (var guard = 0; guard < puzzle.cellCount * 2; guard++) {
      final path = _threads[colour]!;
      final head = path.last;
      if (head == cell) break;
      final next = _nextStep(head, cell, path);
      if (next < 0) break;
      final before = path.length;
      if (!_step(colour, next)) break;
      final after = _threads[colour]!.length;
      if (after > before) {
        entered.add(next);
        if (puzzle.knotColourAt(next) == colour) connected = true;
      } else {
        left += before - after;
      }
    }
    if (entered.isNotEmpty || left > 0) {
      _recutOthers(colour);
      _changed();
    }
    return Move(
      entered: entered,
      left: left,
      connected: connected && isConnected(colour),
    );
  }

  /// One cell from [head] toward [target], preferring the longer axis and
  /// going straight on inside a crossing.
  int _nextStep(int head, int target, List<int> path) {
    final dx = puzzle.xOf(target) - puzzle.xOf(head);
    final dy = puzzle.yOf(target) - puzzle.yOf(head);
    final options = <int>[];
    if (puzzle.isCrossing(head) && path.length >= 2) {
      final d = puzzle.dirBetween(path[path.length - 2], head);
      final ahead = dirDx[d] * dx + dirDy[d] * dy;
      if (ahead > 0) options.add(d);
      // Going back out of the crossing is also fine.
      final back = oppositeDir(d);
      if (dirDx[back] * dx + dirDy[back] * dy > 0) options.add(back);
    } else {
      final hDir = dx > 0 ? 0 : 2;
      final vDir = dy > 0 ? 1 : 3;
      if (dx.abs() >= dy.abs()) {
        if (dx != 0) options.add(hDir);
        if (dy != 0) options.add(vDir);
      } else {
        if (dy != 0) options.add(vDir);
        if (dx != 0) options.add(hDir);
      }
    }
    for (final d in options) {
      final x = puzzle.xOf(head) + dirDx[d];
      final y = puzzle.yOf(head) + dirDy[d];
      if (!puzzle.inside(x, y)) continue;
      final n = puzzle.index(x, y);
      if (_canStep(_active!, n)) return n;
    }
    return -1;
  }

  bool _canStep(int colour, int t) {
    final original = _threads[colour]!;
    _threads[colour] = List.of(original);
    final ok = _step(colour, t);
    _threads[colour] = original;
    return ok;
  }

  /// Applies a single step of [colour]'s thread into adjacent cell [t].
  bool _step(int colour, int t) {
    final path = _threads[colour]!;
    final head = path.last;
    final d = puzzle.dirBetween(head, t);
    if (d < 0) return false;
    final axis = axisOfDir(d);

    // Back up one cell.
    if (path.length >= 2 && path[path.length - 2] == t) {
      path.removeLast();
      return true;
    }

    // Loop back onto our own thread: cut it back to that cell.
    if (!puzzle.isCrossing(t)) {
      final j = path.indexOf(t);
      if (j >= 0) {
        path.removeRange(j + 1, path.length);
        return true;
      }
    } else if (_indexOf(path, t, axis) >= 0) {
      return false;
    }

    if (isConnected(colour)) return false;
    if (puzzle.isCrossing(head)) {
      final inDir = puzzle.dirBetween(path[path.length - 2], head);
      if (inDir != d) return false;
    }
    if (puzzle.isHole(t)) return false;
    final knot = puzzle.knotColourAt(t);
    if (knot >= 0 &&
        (knot != colour || t != puzzle.knotOf(colour).twinOf(path.first))) {
      return false;
    }
    path.add(t);
    return true;
  }

  /// Index of [cell] in [path]; at a crossing, the visit along [axis].
  int _indexOf(List<int> path, int cell, int axis) {
    for (var i = 1; i < path.length; i++) {
      if (path[i] != cell) continue;
      if (!puzzle.isCrossing(cell)) return i;
      if (axisOfDir(puzzle.dirBetween(path[i - 1], cell)) == axis) return i;
    }
    if (path.isNotEmpty && path.first == cell && !puzzle.isCrossing(cell)) {
      return 0;
    }
    return -1;
  }

  int _slot(List<int> path, int i) {
    final cell = path[i];
    if (!puzzle.isCrossing(cell) || i == 0) return cell * 2;
    return cell * 2 + axisOfDir(puzzle.dirBetween(path[i - 1], cell));
  }

  /// Other threads are pulled back to just before the first cell the active
  /// thread now covers.
  void _recutOthers(int colour) {
    final base = _snapshot ?? {};
    final used = <int>{};
    final path = _threads[colour]!;
    for (var i = 0; i < path.length; i++) {
      used.add(_slot(path, i));
    }
    for (final e in base.entries) {
      final other = e.value;
      var keep = other.length;
      for (var i = 0; i < other.length; i++) {
        if (used.contains(_slot(other, i))) {
          keep = i;
          break;
        }
      }
      // Never leave a thread ending inside a crossing.
      while (keep > 1 && puzzle.isCrossing(other[keep - 1])) {
        keep--;
      }
      if (keep <= 0) {
        _threads.remove(e.key);
      } else {
        _threads[e.key] = other.sublist(0, keep);
      }
    }
  }

  /// Ends the current drag. Returns how many other threads it cut.
  int end() {
    final colour = _active;
    if (colour == null) return 0;
    var cuts = 0;
    final base = _snapshot ?? {};
    for (final e in base.entries) {
      if ((_threads[e.key]?.length ?? 0) < e.value.length) cuts++;
    }
    _trimSingle(colour);
    _active = null;
    _snapshot = null;
    _changed();
    return cuts;
  }

  void _trimSingle(int colour) {
    final p = _threads[colour];
    if (p == null) return;
    while (p.length > 1 && puzzle.isCrossing(p.last)) {
      p.removeLast();
    }
    if (p.length <= 1) _threads.remove(colour);
  }

  // ------------------------------------------------------------ commands --

  bool isConnected(int colour) {
    final p = _threads[colour];
    if (p == null || p.length < 2) return false;
    return p.last == puzzle.knotOf(colour).twinOf(p.first);
  }

  void clearThread(int colour) {
    end();
    _threads.remove(colour);
    _changed();
  }

  void clearAll() {
    end();
    _threads.clear();
    _changed();
  }

  /// Lays [path] for [colour] (used by hints), pulling back any thread in its
  /// way. Returns how many threads it cut.
  int lay(int colour, List<int> path) {
    end();
    _snapshot = {
      for (final e in _threads.entries)
        if (e.key != colour) e.key: List.of(e.value),
    };
    _threads[colour] = List.of(path);
    _recutOthers(colour);
    var cuts = 0;
    for (final e in _snapshot!.entries) {
      if ((_threads[e.key]?.length ?? 0) < e.value.length) cuts++;
    }
    _snapshot = null;
    _changed();
    return cuts;
  }

  /// A colour whose laid thread differs from the solution, preferring
  /// threads the player has not started. Null when every thread is right.
  int? hintColour() {
    int? fallback;
    for (final k in puzzle.knots) {
      final laid = _threads[k.colour];
      final right =
          laid != null &&
          laid.length == k.path.length &&
          (_same(laid, k.path) || _same(laid.reversed.toList(), k.path));
      if (right) continue;
      if (laid == null || laid.length <= 1) return k.colour;
      fallback ??= k.colour;
    }
    return fallback;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// A rough progress measure: filled slots plus connected threads.
  int get progress => weave.filledSlots + weave.completeCount * 4;
}
