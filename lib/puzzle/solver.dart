import 'dart:typed_data';

import 'puzzle.dart';

/// Result of [Solver.solve].
class SolveResult {
  SolveResult(
    this.count,
    this.solutions,
    this.nodes,
    this.backtracks, {
    this.gaveUp = false,
  });

  /// Number of solutions found, capped at the requested limit.
  final int count;
  final List<Map<int, List<int>>> solutions;

  /// Search effort: branch points visited and dead ends hit.
  final int nodes;
  final int backtracks;

  /// The search hit its node budget before finishing.
  final bool gaveUp;

  bool get unique => count == 1 && !gaveUp;
}

const int _unknown = 0;
const int _on = 1;
const int _off = 2;

/// Mutable search state, copied at each branch.
class _State {
  _State(int nodes, int edges)
    : e = Int8List(edges),
      parent = Int32List(nodes),
      dom = Int32List(nodes),
      size = Int32List(nodes),
      knots = Int8List(nodes),
      spool = Int32List(nodes),
      endA = Int32List(nodes),
      endB = Int32List(nodes),
      on = Int8List(nodes),
      unk = Int8List(nodes);

  _State.copy(_State o)
    : e = Int8List.fromList(o.e),
      parent = Int32List.fromList(o.parent),
      dom = Int32List.fromList(o.dom),
      size = Int32List.fromList(o.size),
      knots = Int8List.fromList(o.knots),
      spool = Int32List.fromList(o.spool),
      endA = Int32List.fromList(o.endA),
      endB = Int32List.fromList(o.endB),
      on = Int8List.fromList(o.on),
      unk = Int8List.fromList(o.unk);

  final Int8List e;
  final Int32List parent;
  final Int32List dom;
  final Int32List size;
  final Int8List knots;
  final Int32List spool;
  final Int32List endA;
  final Int32List endB;
  final Int8List on;
  final Int8List unk;

  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }
}

/// Backtracking search with constraint propagation.
///
/// Each normal cell is a node that needs two thread connections (one for a
/// knot); a crossing is two nodes, one per axis. Edges join neighbouring
/// nodes and are on or off. Propagation keeps degrees right, forbids loops,
/// keeps colours consistent along joined edges, applies bead/pin/eyelet/
/// stitch/spool rules, and checks every colour can still reach its twin.
class Solver {
  Solver(this.puzzle) {
    _build();
  }

  final Puzzle puzzle;

  late final Int32List _nodeOf; // cell*2+axis -> node
  late final List<int> _nodeCell;
  late final List<int> _req;
  late final List<int> _feature; // 0 none, 1 bead, 2 pin
  late final Int32List _nodeEdge; // node*4+dir -> edge or -1
  late final List<int> _ea;
  late final List<int> _eb;
  late final List<int> _initDom;
  final List<int> _colours = [];
  final Map<int, int> _knotA = {};
  final Map<int, int> _knotB = {};
  bool _impossible = false;

  /// Free-weave targets: (across node, down node, front colour, back colour),
  /// with -1 for a side that has no target.
  final List<(int, int, int, int)> _pairs = [];

  int get nodeCount => _nodeCell.length;

  void _build() {
    final p = puzzle;
    _nodeOf = Int32List(p.cellCount * 2)..fillRange(0, p.cellCount * 2, -1);
    _nodeCell = [];
    for (var c = 0; c < p.cellCount; c++) {
      if (p.isHole(c)) continue;
      if (p.isCrossing(c)) {
        _nodeOf[c * 2] = _nodeCell.length;
        _nodeCell.add(c);
        _nodeOf[c * 2 + 1] = _nodeCell.length;
        _nodeCell.add(c);
      } else {
        _nodeOf[c * 2] = _nodeOf[c * 2 + 1] = _nodeCell.length;
        _nodeCell.add(c);
      }
    }
    final n = _nodeCell.length;
    _nodeEdge = Int32List(n * 4)..fillRange(0, n * 4, -1);
    _ea = [];
    _eb = [];
    for (var c = 0; c < p.cellCount; c++) {
      if (p.isHole(c)) continue;
      for (final dir in const [0, 1]) {
        final m = p.neighbour(c, dir);
        if (m < 0) continue;
        final axis = axisOfDir(dir);
        final a = _nodeOf[c * 2 + axis];
        final b = _nodeOf[m * 2 + axis];
        final e = _ea.length;
        _ea.add(a);
        _eb.add(b);
        _nodeEdge[a * 4 + dir] = e;
        _nodeEdge[b * 4 + oppositeDir(dir)] = e;
      }
    }
    for (final k in p.knots) {
      _colours.add(k.colour);
      _knotA[k.colour] = _nodeOf[k.a * 2];
      _knotB[k.colour] = _nodeOf[k.b * 2];
    }
    var all = 0;
    for (final c in _colours) {
      all |= 1 << c;
    }
    _req = List.filled(n, 2);
    _feature = List.filled(n, 0);
    _initDom = List.filled(n, all);
    for (final k in p.knots) {
      for (final end in [k.a, k.b]) {
        final node = _nodeOf[end * 2];
        _req[node] = 1;
        _initDom[node] = 1 << k.colour;
      }
    }
    for (final entry in p.features.entries) {
      final c = entry.key;
      final f = entry.value;
      if (p.isHole(c)) continue;
      switch (f.kind) {
        case FeatureKind.bead:
          _feature[_nodeOf[c * 2]] = 1;
        case FeatureKind.pin:
          _feature[_nodeOf[c * 2]] = 2;
        case FeatureKind.eyelet:
          if (!p.isCrossing(c)) _initDom[_nodeOf[c * 2]] &= 1 << f.colour!;
        case FeatureKind.stitch:
          final node = p.isCrossing(c)
              ? _nodeOf[c * 2 + p.overAxis(c)]
              : _nodeOf[c * 2];
          _initDom[node] &= 1 << f.colour!;
        case FeatureKind.weave:
          if (!p.isCrossing(c)) {
            _impossible = true;
          } else if (p.freeWeave) {
            _pairs.add((
              _nodeOf[c * 2 + axisH],
              _nodeOf[c * 2 + axisV],
              f.colour ?? -1,
              f.back ?? -1,
            ));
          } else {
            final over = p.overAxis(c);
            if (f.colour != null) {
              _initDom[_nodeOf[c * 2 + over]] &= 1 << f.colour!;
            }
            if (f.back != null) {
              _initDom[_nodeOf[c * 2 + 1 - over]] &= 1 << f.back!;
            }
          }
      }
    }
    for (var node = 0; node < n; node++) {
      if (_initDom[node] == 0) _impossible = true;
    }
  }

  _State _initial() {
    final n = nodeCount;
    final s = _State(n, _ea.length);
    for (var i = 0; i < n; i++) {
      s.parent[i] = i;
      s.dom[i] = _initDom[i];
      s.size[i] = 1;
      s.endA[i] = i;
      s.endB[i] = i;
      var u = 0;
      for (var d = 0; d < 4; d++) {
        if (_nodeEdge[i * 4 + d] >= 0) u++;
      }
      s.unk[i] = u;
    }
    for (final k in puzzle.knots) {
      for (final end in [k.a, k.b]) {
        final node = _nodeOf[end * 2];
        s.knots[node] = 1;
        s.spool[node] = k.spool ?? 0;
      }
    }
    return s;
  }

  int _nodes = 0;
  int _backtracks = 0;
  int _limit = 2;
  int _maxNodes = 0;
  bool _gaveUp = false;
  final List<Map<int, List<int>>> _found = [];

  /// Finds up to [limit] solutions, giving up after [maxNodes] branch points.
  SolveResult solve({int limit = 2, int maxNodes = 400000}) {
    _nodes = 0;
    _backtracks = 0;
    _limit = limit;
    _maxNodes = maxNodes;
    _gaveUp = false;
    _found.clear();
    if (!_impossible) {
      final s = _initial();
      final queue = <int>[for (var i = 0; i < nodeCount; i++) i];
      if (_propagate(s, queue)) _search(s);
    }
    return SolveResult(
      _found.length,
      List.of(_found),
      _nodes,
      _backtracks,
      gaveUp: _gaveUp,
    );
  }

  void _search(_State s) {
    if (_found.length >= _limit || _gaveUp) return;
    if (++_nodes > _maxNodes) {
      _gaveUp = true;
      return;
    }
    if (!_reach(s)) {
      _backtracks++;
      return;
    }
    // Pick the most constrained open node, preferring thread ends.
    var best = -1;
    var bestScore = 1 << 30;
    for (var n = 0; n < nodeCount; n++) {
      final u = s.unk[n];
      if (u == 0 || s.on[n] >= _req[n]) continue;
      final score =
          u * 4 -
          (s.on[n] > 0 || _req[n] == 1 ? 2 : 0) -
          (s.knots[s.find(n)] > 0 ? 1 : 0);
      if (score < bestScore) {
        bestScore = score;
        best = n;
      }
    }
    if (best < 0) {
      _found.add(_extract(s));
      return;
    }
    var edge = -1;
    for (var d = 0; d < 4; d++) {
      final e = _nodeEdge[best * 4 + d];
      if (e >= 0 && s.e[e] == _unknown) {
        edge = e;
        break;
      }
    }
    final onBranch = _State.copy(s);
    final q1 = <int>[];
    if (_setEdge(onBranch, edge, _on, q1) && _propagate(onBranch, q1)) {
      _search(onBranch);
    } else {
      _backtracks++;
    }
    if (_found.length >= _limit || _gaveUp) return;
    final q2 = <int>[];
    if (_setEdge(s, edge, _off, q2) && _propagate(s, q2)) {
      _search(s);
    } else {
      _backtracks++;
    }
  }

  int _other(int r, int x, _State s) => s.endA[r] == x ? s.endB[r] : s.endA[r];

  bool _setEdge(_State s, int e, int val, List<int> queue) {
    if (e < 0) return val == _off;
    final cur = s.e[e];
    if (cur == val) return true;
    if (cur != _unknown) return false;
    s.e[e] = val;
    final a = _ea[e], b = _eb[e];
    s.unk[a]--;
    s.unk[b]--;
    queue
      ..add(a)
      ..add(b);
    if (val == _off) return true;
    s.on[a]++;
    s.on[b]++;
    if (s.on[a] > _req[a] || s.on[b] > _req[b]) return false;
    final ra = s.find(a), rb = s.find(b);
    if (ra == rb) return false;
    final dom = s.dom[ra] & s.dom[rb];
    if (dom == 0) return false;
    final knots = s.knots[ra] + s.knots[rb];
    if (knots > 2) return false;
    final sa = s.spool[ra], sb = s.spool[rb];
    if (sa != 0 && sb != 0 && sa != sb) return false;
    final spool = sa != 0 ? sa : sb;
    final size = s.size[ra] + s.size[rb];
    if (spool != 0) {
      if (knots == 2 && size != spool) return false;
      if (knots < 2 && size >= spool) return false;
    }
    final na = _other(ra, a, s), nb = _other(rb, b, s);
    final r = s.size[ra] >= s.size[rb] ? ra : rb;
    final child = r == ra ? rb : ra;
    s.parent[child] = r;
    s.dom[r] = dom;
    s.size[r] = size;
    s.knots[r] = knots;
    s.spool[r] = spool;
    s.endA[r] = na;
    s.endB[r] = nb;
    queue
      ..add(na)
      ..add(nb);
    return true;
  }

  int _state(_State s, int node, int dir) {
    final e = _nodeEdge[node * 4 + dir];
    return e < 0 ? _off : s.e[e];
  }

  bool _force(_State s, int node, int dir, int val, List<int> q) {
    final e = _nodeEdge[node * 4 + dir];
    if (e < 0) return val == _off;
    return _setEdge(s, e, val, q);
  }

  bool _check(_State s, int n, List<int> q) {
    final req = _req[n];
    final on = s.on[n], unk = s.unk[n];
    if (on > req || on + unk < req) return false;
    final f = _feature[n];
    if (f != 0) {
      for (final pair in const [
        [0, 2],
        [1, 3],
      ]) {
        for (var k = 0; k < 2; k++) {
          final p = pair[k], o = pair[1 - k];
          final sp = _state(s, n, p);
          if (f == 1) {
            if (sp == _on && !_force(s, n, o, _on, q)) return false;
            if (sp == _off && !_force(s, n, o, _off, q)) return false;
          } else {
            if (sp == _on && !_force(s, n, o, _off, q)) return false;
            if (sp == _off && !_force(s, n, o, _on, q)) return false;
          }
        }
      }
      if (f == 1) {
        final h = _state(s, n, 0) == _on || _state(s, n, 2) == _on;
        final v = _state(s, n, 1) == _on || _state(s, n, 3) == _on;
        if (h && !(_force(s, n, 1, _off, q) && _force(s, n, 3, _off, q))) {
          return false;
        }
        if (v && !(_force(s, n, 0, _off, q) && _force(s, n, 2, _off, q))) {
          return false;
        }
      }
    }
    if (s.on[n] > req || s.on[n] + s.unk[n] < req) return false;
    if (s.unk[n] == 0) return true;
    if (s.on[n] == req) {
      for (var d = 0; d < 4; d++) {
        final e = _nodeEdge[n * 4 + d];
        if (e >= 0 && s.e[e] == _unknown && !_setEdge(s, e, _off, q)) {
          return false;
        }
      }
      return true;
    }
    if (s.on[n] + s.unk[n] == req) {
      for (var d = 0; d < 4; d++) {
        final e = _nodeEdge[n * 4 + d];
        if (e >= 0 && s.e[e] == _unknown && !_setEdge(s, e, _on, q)) {
          return false;
        }
      }
      return true;
    }
    // Prune edges that would close a loop, mix colours or break a spool.
    final rn = s.find(n);
    for (var d = 0; d < 4; d++) {
      final e = _nodeEdge[n * 4 + d];
      if (e < 0 || s.e[e] != _unknown) continue;
      final m = _ea[e] == n ? _eb[e] : _ea[e];
      final rm = s.find(m);
      var bad =
          rm == rn ||
          (s.dom[rn] & s.dom[rm]) == 0 ||
          s.knots[rn] + s.knots[rm] > 2;
      if (!bad) {
        final sa = s.spool[rn], sb = s.spool[rm];
        final spool = sa != 0 ? sa : sb;
        if (sa != 0 && sb != 0 && sa != sb) {
          bad = true;
        } else if (spool != 0) {
          final size = s.size[rn] + s.size[rm];
          final knots = s.knots[rn] + s.knots[rm];
          bad = knots == 2 ? size != spool : size >= spool;
        }
      }
      if (bad && !_setEdge(s, e, _off, q)) return false;
    }
    final on2 = s.on[n], unk2 = s.unk[n];
    return on2 + unk2 >= req;
  }

  bool _propagate(_State s, List<int> queue) {
    while (queue.isNotEmpty) {
      final n = queue.removeLast();
      if (!_check(s, n, queue)) return false;
    }
    return true;
  }

  /// Every colour must still be able to reach its twin; cells no colour can
  /// reach make the state dead, and colours that cannot reach a cell are
  /// removed from its options.
  /// Narrows the colours at free-weave targets: the two threads crossing
  /// there must fit the target one way round or the other.
  bool _weavePairs(_State s, List<int> q) {
    for (var changed = true; changed;) {
      changed = false;
      for (final (h, v, front, back) in _pairs) {
        final rh = s.find(h), rv = s.find(v);
        final dh = s.dom[rh], dv = s.dom[rv];
        // Every (across, down) colour pair that fits the target.
        var allowH = 0, allowV = 0;
        for (var a = dh; a != 0; a &= a - 1) {
          final colourA = (a & -a).bitLength - 1;
          for (var b = dv; b != 0; b &= b - 1) {
            final colourB = (b & -b).bitLength - 1;
            // Both halves in one thread means one colour.
            if (rh == rv && colourA != colourB) continue;
            bool fits(int top, int bottom) =>
                (front < 0 || top == front) && (back < 0 || bottom == back);
            if (fits(colourA, colourB) || fits(colourB, colourA)) {
              allowH |= 1 << colourA;
              allowV |= 1 << colourB;
            }
          }
        }
        if (rh == rv) allowH = allowV = allowH & allowV;
        if (allowH == 0 || allowV == 0) return false;
        if (allowH != dh) {
          s.dom[rh] = allowH;
          q
            ..add(s.endA[rh])
            ..add(s.endB[rh]);
          changed = true;
        }
        if (rv != rh && allowV != dv) {
          s.dom[rv] = allowV;
          q
            ..add(s.endA[rv])
            ..add(s.endB[rv]);
          changed = true;
        }
      }
    }
    return true;
  }

  bool _reach(_State s) {
    if (_pairs.isNotEmpty) {
      final q = <int>[];
      if (!_weavePairs(s, q)) return false;
      if (q.isNotEmpty && !_propagate(s, q)) return false;
    }
    final n = nodeCount;
    final reach = Int32List(n);
    final stack = <int>[];
    for (final c in _colours) {
      final bit = 1 << c;
      final seen = Uint8List(n);
      final start = _knotA[c]!;
      seen[start] = 1;
      stack
        ..clear()
        ..add(start);
      while (stack.isNotEmpty) {
        final x = stack.removeLast();
        reach[x] |= bit;
        for (var d = 0; d < 4; d++) {
          final e = _nodeEdge[x * 4 + d];
          if (e < 0 || s.e[e] == _off) continue;
          final y = _ea[e] == x ? _eb[e] : _ea[e];
          if (seen[y] == 1) continue;
          if (s.dom[s.find(y)] & bit == 0) continue;
          // A knot of this colour other than the twin is a dead end.
          seen[y] = 1;
          stack.add(y);
        }
      }
      if (seen[_knotB[c]!] == 0) return false;
    }
    final q = <int>[];
    for (var x = 0; x < n; x++) {
      final r = s.find(x);
      final allowed = s.dom[r] & reach[x];
      if (allowed == 0) return false;
      if (allowed != s.dom[r]) {
        s.dom[r] = allowed;
        q
          ..add(s.endA[r])
          ..add(s.endB[r]);
      }
    }
    if (q.isEmpty) return true;
    // Restricting colours can rule out more edges.
    for (var x = 0; x < n; x++) {
      q.add(x);
    }
    return _propagate(s, q);
  }

  Map<int, List<int>> _extract(_State s) {
    final out = <int, List<int>>{};
    for (final c in _colours) {
      final path = <int>[];
      var prev = -1;
      var cur = _knotA[c]!;
      final end = _knotB[c]!;
      for (var guard = 0; guard <= nodeCount; guard++) {
        path.add(_nodeCell[cur]);
        if (cur == end) break;
        var next = -1;
        for (var d = 0; d < 4; d++) {
          final e = _nodeEdge[cur * 4 + d];
          if (e < 0 || s.e[e] != _on) continue;
          final y = _ea[e] == cur ? _eb[e] : _ea[e];
          if (y != prev) {
            next = y;
            break;
          }
        }
        if (next < 0) break;
        prev = cur;
        cur = next;
      }
      out[c] = path;
    }
    return out;
  }
}
