import 'dart:math';

import 'puzzle.dart';
import 'rules.dart';
import 'solver.dart';

/// What a generated level should look like.
class GenSpec {
  const GenSpec({
    required this.width,
    required this.height,
    required this.minThreads,
    required this.maxThreads,
    this.crossings = 0,
    this.shape,
    this.clueKinds = const {},
    this.spools = false,
    this.minClues = const {},
    this.minSpools = 0,
    this.motif,
    this.regionColours,
    this.colours,
    this.minLength = 3,
    this.fixedCrossings = const [],
  });

  /// Crossings at fixed (x, y) places, used by showpieces.
  final List<(int, int)> fixedCrossings;

  final int width;
  final int height;
  final int minThreads;
  final int maxThreads;

  /// How many crossings to place.
  final int crossings;

  /// Rows with '#' for holes (the hoop's shape).
  final List<String>? shape;

  /// Clue features the generator may add to make the solution unique.
  final Set<FeatureKind> clueKinds;

  /// Whether spool numbers may be added to knots.
  final bool spools;

  /// At least this many of each feature kind, even if some are redundant
  /// (teaching levels want the new thing to be visible).
  final Map<FeatureKind, int> minClues;
  final int minSpools;

  /// For showpieces: rows of region letters ('#' is a hole). Every thread
  /// stays inside one region, so the finished threads draw a picture.
  final List<String>? motif;

  /// Palette colours each region's threads are drawn from.
  final Map<String, List<int>>? regionColours;

  /// Palette colours for ordinary levels, in order of preference.
  final List<int>? colours;

  final int minLength;
}

/// Palette order for ordinary levels: high contrast first.
const List<int> defaultColours = [0, 1, 2, 3, 4, 5, 7, 6, 9, 8];

class Generator {
  Generator(this.rng);
  final Random rng;

  /// Why attempts failed, for tuning chapter specs.
  final Map<String, int> failures = {};
  Null _fail(String why) {
    failures[why] = (failures[why] ?? 0) + 1;
    return null;
  }

  /// Makes one attempt. Returns null if this attempt failed (try again).
  Puzzle? attempt(GenSpec spec, {int id = 0, int chapter = 0}) {
    final w = spec.width, h = spec.height;
    final kinds = List.filled(w * h, CellKind.normal);
    final region = List.filled(w * h, '.');
    final rows = spec.motif ?? spec.shape;
    if (rows != null) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final ch = rows[y][x];
          if (ch == '#') kinds[y * w + x] = CellKind.hole;
          if (spec.motif != null) region[y * w + x] = ch;
        }
      }
    }
    for (final (x, y) in spec.fixedCrossings) {
      kinds[y * w + x] = CellKind.crossing;
    }
    final base = Puzzle(
      id: id,
      chapter: chapter,
      width: w,
      height: h,
      kinds: kinds,
      features: const {},
      knots: const [],
    );
    if (!_placeCrossings(base, kinds, region, spec.crossings)) {
      return _fail('crossings');
    }
    final grid = Puzzle(
      id: id,
      chapter: chapter,
      width: w,
      height: h,
      kinds: kinds,
      features: const {},
      knots: const [],
    );
    final paths = _cover(grid, region, spec);
    if (paths == null) return null;

    // Colours.
    final knots = <Knot>[];
    if (spec.motif != null) {
      final taken = <int>{};
      for (final p in paths) {
        final options = spec.regionColours![region[p.first]]!;
        final colour = options.where((c) => !taken.contains(c)).firstOrNull;
        if (colour == null) return _fail('region colours');
        taken.add(colour);
        knots.add(Knot(colour: colour, path: p));
      }
    } else {
      final pool = List.of(spec.colours ?? defaultColours);
      final head = pool.take(paths.length + 1).toList()..shuffle(rng);
      for (var i = 0; i < paths.length; i++) {
        knots.add(Knot(colour: head[i], path: paths[i]));
      }
    }
    var puzzle = Puzzle(
      id: id,
      chapter: chapter,
      width: w,
      height: h,
      kinds: kinds,
      features: const {},
      knots: knots,
    );
    if (Weave(puzzle, puzzle.solution).errors.isNotEmpty) return _fail('weave');
    return _makeUnique(puzzle, spec);
  }

  bool _placeCrossings(
    Puzzle p,
    List<CellKind> kinds,
    List<String> region,
    int count,
  ) {
    if (count == 0) return true;
    final candidates = <int>[];
    for (var y = 1; y < p.height - 1; y++) {
      for (var x = 1; x < p.width - 1; x++) {
        final c = p.index(x, y);
        if (p.isHole(c)) continue;
        var ok = true;
        for (var d = 0; d < 4; d++) {
          final n = p.neighbour(c, d);
          if (n < 0 || region[n] != region[c]) ok = false;
        }
        if (ok) candidates.add(c);
      }
    }
    candidates.shuffle(rng);
    var placed = 0;
    for (final c in candidates) {
      if (placed == count) break;
      var nearOther = false;
      for (var d = 0; d < 4; d++) {
        final n = p.neighbour(c, d);
        if (n >= 0 && kinds[n] == CellKind.crossing) nearOther = true;
      }
      if (nearOther) continue;
      kinds[c] = CellKind.crossing;
      placed++;
    }
    return placed == count;
  }

  /// Covers the hoop with random non-overlapping paths, then reshapes and
  /// merges them until the thread count is in range.
  List<List<int>>? _cover(Puzzle p, List<String> region, GenSpec spec) {
    final n = p.cellCount;
    final taken = List.filled(n, false);
    final paths = <List<int>>[];

    // Each crossing starts as two short straight threads through it.
    for (var c = 0; c < n; c++) {
      if (!p.isCrossing(c)) continue;
      for (final dir in const [0, 1]) {
        final before = p.neighbour(c, oppositeDir(dir));
        final after = p.neighbour(c, dir);
        if (before < 0 || after < 0 || taken[before] || taken[after]) {
          return _fail('cover: crossing blocked');
        }
        if (p.isCrossing(before) || p.isCrossing(after)) {
          return _fail('cover: crossings touch');
        }
        taken[before] = taken[after] = true;
        paths.add([before, c, after]);
      }
      taken[c] = true;
    }

    bool open(int from, int to) =>
        to >= 0 && !taken[to] && region[to] == region[from];

    int exits(int c) {
      var k = 0;
      for (var d = 0; d < 4; d++) {
        if (open(c, p.neighbour(c, d))) k++;
      }
      return k;
    }

    // Random walks from the tightest free cells.
    while (true) {
      var best = <int>[];
      var bestExits = 99;
      for (var c = 0; c < n; c++) {
        if (p.isHole(c) || taken[c]) continue;
        final e = exits(c);
        if (e < bestExits) {
          bestExits = e;
          best = [c];
        } else if (e == bestExits) {
          best.add(c);
        }
      }
      if (best.isEmpty) break;
      final start = best[rng.nextInt(best.length)];
      final path = [start];
      taken[start] = true;
      final target = 2 + rng.nextInt(6);
      while (path.length < target) {
        final head = path.last;
        final opts = <int>[
          for (var d = 0; d < 4; d++)
            if (open(head, p.neighbour(head, d))) p.neighbour(head, d),
        ];
        if (opts.isEmpty) break;
        int next;
        if (rng.nextDouble() < 0.75) {
          final low = opts.map(exits).reduce(min);
          final ties = opts.where((o) => exits(o) == low).toList();
          next = ties[rng.nextInt(ties.length)];
        } else {
          next = opts[rng.nextInt(opts.length)];
        }
        path.add(next);
        taken[next] = true;
      }
      paths.add(path);
    }

    // Each separate patch of a region needs at least one thread.
    var components = 0;
    final seen = List.filled(n, false);
    for (var c = 0; c < n; c++) {
      if (p.isHole(c) || seen[c]) continue;
      components++;
      final stack = [c];
      seen[c] = true;
      while (stack.isNotEmpty) {
        final x = stack.removeLast();
        for (var d = 0; d < 4; d++) {
          final y = p.neighbour(x, d);
          if (y >= 0 && !seen[y] && region[y] == region[x]) {
            seen[y] = true;
            stack.add(y);
          }
        }
      }
    }
    final targetCount = max(
      components,
      spec.minThreads + rng.nextInt(spec.maxThreads - spec.minThreads + 1),
    );
    final limits = spec.regionColours?.map((k, v) => MapEntry(k, v.length));
    int inRegion(String r) => paths.where((q) => region[q.first] == r).length;
    bool regionsOk() =>
        limits == null ||
        limits.entries.every((e) => inRegion(e.key) <= e.value);
    final owner = List.filled(n, -1);
    final at = List.filled(n, -1);
    void reindex() {
      owner.fillRange(0, n, -1);
      for (var i = 0; i < paths.length; i++) {
        final q = paths[i];
        for (var k = 0; k < q.length; k++) {
          if (!p.isCrossing(q[k])) {
            owner[q[k]] = i;
            at[q[k]] = k;
          }
        }
      }
    }

    bool done() =>
        paths.length <= targetCount &&
        paths.length >= spec.minThreads &&
        paths.every((q) => q.length >= spec.minLength) &&
        regionsOk();

    for (var step = 0; step < 20000 && !done(); step++) {
      reindex();
      // Pick a path end (short paths first) and a neighbouring cell in the
      // same region.
      final shortOnes = [
        for (var x = 0; x < paths.length; x++)
          if (paths[x].length < spec.minLength) x,
      ];
      final i = shortOnes.isNotEmpty && rng.nextBool()
          ? shortOnes[rng.nextInt(shortOnes.length)]
          : rng.nextInt(paths.length);
      final a = rng.nextBool() ? paths[i] : paths[i].reversed.toList();
      final e = a.last;
      final options = <int>[
        for (var d = 0; d < 4; d++)
          if (p.neighbour(e, d) >= 0 &&
              !p.isCrossing(p.neighbour(e, d)) &&
              region[p.neighbour(e, d)] == region[e])
            p.neighbour(e, d),
      ];
      if (options.isEmpty) continue;
      final c = options[rng.nextInt(options.length)];
      final j = owner[c];
      final k = at[c];
      if (j == i) {
        // Backbite within the same path: reverse the tail after c.
        final self = a;
        final kk = self.indexOf(c);
        if (kk >= self.length - 2) continue;
        final newEnd = self[kk + 1];
        if (p.isCrossing(newEnd)) continue;
        paths[i] = [
          ...self.sublist(0, kk + 1),
          ...self.sublist(kk + 1).reversed,
        ];
        continue;
      }
      final b = paths[j];
      final tooMany =
          paths.length > targetCount ||
          (limits != null && inRegion(region[e]) > (limits[region[e]] ?? 99));
      final aShort = a.length < spec.minLength;
      final bWhole = k == 0 || k == b.length - 1;
      if (bWhole) {
        // The ends touch: merge if we still have too many threads or a
        // short one, otherwise just keep shuffling.
        if (!tooMany && !aShort && b.length >= spec.minLength) continue;
        if (paths.length <= spec.minThreads) continue;
        final rest = k == 0 ? b : b.reversed.toList();
        paths[i] = [...a, ...rest];
        paths.removeAt(j);
        continue;
      }
      // Bite into the middle of b: a takes one side, b keeps the other.
      final takeTail = rng.nextBool();
      final taken2 = takeTail
          ? b.sublist(k)
          : b.sublist(0, k + 1).reversed.toList();
      final rest = takeTail ? b.sublist(0, k) : b.sublist(k + 1);
      if (rest.isEmpty || p.isCrossing(rest.first) || p.isCrossing(rest.last)) {
        continue;
      }
      if (rest.length < spec.minLength && rng.nextDouble() < 0.8) continue;
      paths[i] = [...a, ...taken2];
      paths[j] = rest;
    }
    if (!done()) {
      final count = paths.length;
      if (count > spec.maxThreads || count < spec.minThreads) {
        return _fail('cover: thread count');
      }
      return _fail('cover: short');
    }
    return paths;
  }

  Puzzle? _makeUnique(Puzzle puzzle, GenSpec spec) {
    final intended = puzzle.solution;
    var current = puzzle;
    final wantsClues = spec.clueKinds.isNotEmpty || spec.spools;
    for (var round = 0; round < 40; round++) {
      final res = Solver(current).solve(limit: 2, maxNodes: 60000);
      if (res.gaveUp) return _fail('solver gave up');
      if (res.count == 1) break;
      if (!wantsClues || res.count == 0) return _fail('not unique');
      final alt = res.solutions.firstWhere(
        (s) => !_sameSolution(s, intended),
        orElse: () => res.solutions.first,
      );
      final next = _addClue(current, intended, alt, spec);
      if (next == null) return _fail('no clue helps');
      current = next;
    }
    final check = Solver(current).solve(limit: 2, maxNodes: 60000);
    if (!check.unique) return null;

    // Drop clues that are not needed.
    if (wantsClues) {
      current = _minimise(current, spec);
    }
    current = _topUp(current, spec);
    final last = Solver(current).solve(limit: 2, maxNodes: 120000);
    if (!last.unique) return null;
    if (!_sameSolution(last.solutions.first, current.solution)) {
      throw StateError('solver disagrees with the generated solution');
    }
    if (!Weave(current, current.solution).isCleared) return null;
    return current.copyWith(difficulty: difficultyOf(current, last));
  }

  static bool _sameSolution(Map<int, List<int>> a, Map<int, List<int>> b) {
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null) return false;
      final p = e.value;
      if (p.length != o.length) return false;
      var fwd = true, rev = true;
      for (var i = 0; i < p.length; i++) {
        if (p[i] != o[i]) fwd = false;
        if (p[i] != o[o.length - 1 - i]) rev = false;
      }
      if (!fwd && !rev) return false;
    }
    return true;
  }

  Puzzle? _addClue(
    Puzzle p,
    Map<int, List<int>> intended,
    Map<int, List<int>> alt,
    GenSpec spec,
  ) {
    final want = Weave(p, intended);
    final other = Weave(p, alt);
    final options = <Puzzle>[];
    for (var c = 0; c < p.cellCount; c++) {
      if (p.isHole(c) || p.isKnot(c) || p.features.containsKey(c)) continue;
      for (final kind in spec.clueKinds) {
        final f = _clueFor(kind, c, p, want);
        if (f == null) continue;
        final trial = p.copyWith(features: {...p.features, c: f});
        final rule = rules.firstWhere((r) => r.id == kind.name);
        if (rule.violations(Weave(trial, alt)).isNotEmpty) options.add(trial);
      }
    }
    if (spec.spools) {
      for (final k in p.knots) {
        if (k.spool != null) continue;
        if ((other.threads[k.colour]?.length ?? 0) != k.path.length) {
          options.add(
            p.copyWith(
              knots: [
                for (final o in p.knots)
                  o == k
                      ? Knot(
                          colour: o.colour,
                          path: o.path,
                          spool: o.path.length,
                        )
                      : o,
              ],
            ),
          );
        }
      }
    }
    if (options.isEmpty) return null;
    return options[rng.nextInt(options.length)];
  }

  /// The clue of [kind] on [cell] that the intended solution satisfies, or
  /// null if this kind cannot go there.
  Feature? _clueFor(FeatureKind kind, int cell, Puzzle p, Weave want) {
    final crossing = p.isCrossing(cell);
    switch (kind) {
      case FeatureKind.bead:
        if (crossing) return null;
        final l = want.links(cell);
        return (l == 5 || l == 10) ? const Feature(FeatureKind.bead) : null;
      case FeatureKind.pin:
        if (crossing) return null;
        final l = want.links(cell);
        return (l != 5 && l != 10) ? const Feature(FeatureKind.pin) : null;
      case FeatureKind.eyelet:
        if (crossing) return null;
        return Feature(FeatureKind.eyelet, want.occupant(cell));
      case FeatureKind.stitch:
        return Feature(FeatureKind.stitch, want.topColour(cell));
    }
  }

  Puzzle _minimise(Puzzle p, GenSpec spec) {
    var current = p;
    final cells = current.features.keys.toList()..shuffle(rng);
    for (final c in cells) {
      final f = current.features[c]!;
      final count = current.features.values
          .where((v) => v.kind == f.kind)
          .length;
      if (count <= (spec.minClues[f.kind] ?? 0)) continue;
      final trial = current.copyWith(
        features: {...current.features}..remove(c),
      );
      if (Solver(trial).solve(limit: 2, maxNodes: 60000).unique) {
        current = trial;
      }
    }
    final spooled = current.knots.where((k) => k.spool != null).toList()
      ..shuffle(rng);
    for (final k in spooled) {
      if (current.knots.where((o) => o.spool != null).length <=
          spec.minSpools) {
        break;
      }
      final trial = current.copyWith(
        knots: [
          for (final o in current.knots)
            o.colour == k.colour ? Knot(colour: o.colour, path: o.path) : o,
        ],
      );
      if (Solver(trial).solve(limit: 2, maxNodes: 60000).unique) {
        current = trial;
      }
    }
    return current;
  }

  /// Adds redundant clues until each kind reaches its minimum.
  Puzzle _topUp(Puzzle p, GenSpec spec) {
    var current = p;
    final want = Weave(p, p.solution);
    for (final entry in spec.minClues.entries) {
      var have = current.features.values
          .where((f) => f.kind == entry.key)
          .length;
      final cells = [for (var c = 0; c < p.cellCount; c++) c]..shuffle(rng);
      for (final c in cells) {
        if (have >= entry.value) break;
        if (p.isHole(c) || p.isKnot(c) || current.features.containsKey(c)) {
          continue;
        }
        final f = _clueFor(entry.key, c, p, want);
        if (f == null) continue;
        if (entry.key == FeatureKind.stitch &&
            !p.isCrossing(c) &&
            p.hasCrossings) {
          continue; // stitches teach best on crossings
        }
        current = current.copyWith(features: {...current.features, c: f});
        have++;
      }
    }
    var spools = current.knots.where((k) => k.spool != null).length;
    if (spools < spec.minSpools) {
      final order = List.of(current.knots)..shuffle(rng);
      final add = <int>{};
      for (final k in order) {
        if (spools >= spec.minSpools) break;
        if (k.spool == null) {
          add.add(k.colour);
          spools++;
        }
      }
      current = current.copyWith(
        knots: [
          for (final o in current.knots)
            add.contains(o.colour)
                ? Knot(colour: o.colour, path: o.path, spool: o.path.length)
                : o,
        ],
      );
    }
    return current;
  }
}

/// A difficulty score from solver effort, size, threads and clues.
double difficultyOf(Puzzle p, SolveResult r) {
  final effort = log(1 + r.nodes) / ln2 + sqrt(r.backtracks.toDouble());
  final size = p.slotCount / 10;
  final threads = p.knots.length * 0.5;
  final clues =
      (p.features.length + p.knots.where((k) => k.spool != null).length) * 0.2;
  return effort + size + threads + clues;
}
