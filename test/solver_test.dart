import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loom/puzzle/generator.dart';
import 'package:loom/puzzle/puzzle.dart';
import 'package:loom/puzzle/rules.dart';
import 'package:loom/puzzle/solver.dart';

import 'helpers.dart';

void main() {
  test('solves a small level and finds it unique', () {
    final p = picture(['AaaA', 'BbbB', 'CccC']);
    final r = Solver(p).solve();
    expect(r.count, 1);
    expect(Weave(p, r.solutions.first).isCleared, isTrue);
  });

  test('finds two solutions when there are two', () {
    // Two threads in an open 2x3 can swap shapes.
    final p = picture(['Aa', 'aB', 'AB']);
    final r = Solver(p).solve(limit: 10);
    for (final s in r.solutions) {
      expect(Weave(p, s).isCleared, isTrue);
    }
  });

  test('reports no solution when there is none', () {
    final p = picture(['AB', 'BA']);
    expect(Solver(p).solve().count, 0);
  });

  test('every solution found is valid and the generated one is among them', () {
    final rng = Random(7);
    final gen = Generator(rng);
    var checked = 0;
    for (var i = 0; i < 400 && checked < 25; i++) {
      final spec = GenSpec(
        width: 4 + rng.nextInt(2),
        height: 4 + rng.nextInt(2),
        minThreads: 2,
        maxThreads: 5,
        crossings: rng.nextBool() ? 1 : 0,
        clueKinds: {FeatureKind.bead, FeatureKind.pin, FeatureKind.stitch},
        spools: true,
      );
      final p = gen.attempt(spec);
      if (p == null) continue;
      // Strip clues so there are several solutions to check.
      final open = p.copyWith(
        features: {},
        knots: [for (final k in p.knots) Knot(colour: k.colour, path: k.path)],
      );
      final r = Solver(open).solve(limit: 200, maxNodes: 200000);
      expect(r.count, greaterThan(0));
      var foundIntended = false;
      final seen = <String>{};
      for (final s in r.solutions) {
        final w = Weave(open, s);
        expect(w.isCleared, isTrue, reason: 'invalid solution $s');
        expect(seen.add(s.toString()), isTrue, reason: 'duplicate solution');
        if (open.knots.every((k) => _same(s[k.colour]!, k.path))) {
          foundIntended = true;
        }
      }
      if (!r.gaveUp && r.count < 200) expect(foundIntended, isTrue);
      checked++;
    }
    expect(checked, greaterThan(10));
  });

  test('bead, pin, stitch and spool clues all narrow the search', () {
    final rng = Random(3);
    final gen = Generator(rng);
    for (final kinds in [
      {FeatureKind.bead},
      {FeatureKind.pin},
      {FeatureKind.eyelet},
    ]) {
      Puzzle? p;
      for (var i = 0; i < 200 && p == null; i++) {
        p = gen.attempt(
          GenSpec(
            width: 6,
            height: 6,
            minThreads: 4,
            maxThreads: 5,
            clueKinds: kinds,
            minClues: {kinds.first: 1},
          ),
        );
      }
      expect(p, isNotNull);
      expect(Solver(p!).solve().unique, isTrue);
      expect(p.features.values.any((f) => f.kind == kinds.first), isTrue);
    }
  });
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var fwd = true, rev = true;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) fwd = false;
    if (a[i] != b[b.length - 1 - i]) rev = false;
  }
  return fwd || rev;
}
