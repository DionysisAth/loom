import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loom/puzzle/board.dart';
import 'package:loom/puzzle/generator.dart';
import 'package:loom/puzzle/puzzle.dart';
import 'package:loom/puzzle/rules.dart';
import 'package:loom/puzzle/solver.dart';

import 'helpers.dart';

/// A single crossing: A (colour 0) runs across the middle, B (colour 1)
/// runs down it; the corners are holes.
Puzzle cross({Map<int, Feature> features = const {}, bool free = true}) =>
    picture(
      ['#B#', 'A+A', '#B#'],
      extraPaths: {
        'A': [3, 4, 5],
        'B': [1, 4, 7],
      },
      features: features,
    ).copyWith(freeWeave: free, solutionOver: free ? {4: axisV} : const {});

void main() {
  const centre = 4;

  test('front and back of a crossing follow the weave', () {
    final p = cross();
    final threads = {
      0: [3, 4, 5],
      1: [1, 4, 7],
    };
    // (1,1) starts with the across thread on top.
    var w = Weave(p, threads);
    expect(w.topColour(centre), 0);
    expect(w.bottomColour(centre), 1);
    w = Weave(p, threads, over: {centre: axisV});
    expect(w.topColour(centre), 1);
    expect(w.bottomColour(centre), 0);
  });

  test('weave targets check the front, the back, or both', () {
    final threads = {
      0: [3, 4, 5],
      1: [1, 4, 7],
    };
    Set<int> bad(Feature f, int over) => Weave(
      cross(features: {centre: f}),
      threads,
      over: {centre: over},
    ).violations;

    const front1 = Feature(FeatureKind.weave, 1);
    expect(bad(front1, axisH), {centre});
    expect(bad(front1, axisV), isEmpty);

    const back1 = Feature(FeatureKind.weave, null, 1);
    expect(bad(back1, axisH), isEmpty);
    expect(bad(back1, axisV), {centre});

    const both = Feature(FeatureKind.weave, 1, 0);
    expect(bad(both, axisV), isEmpty);
    expect(bad(both, axisH), {centre});

    expect(WeaveRule.canMeet(both, 0, 1), isTrue);
    expect(WeaveRule.canMeet(both, 0, 2), isFalse);
    expect(
      WeaveRule.canMeet(const Feature(FeatureKind.weave, 2), 0, 1),
      isFalse,
    );
  });

  test('the player flips crossings only on free-weave levels', () {
    expect(Board(cross(free: false)).flip(centre), isFalse);
    final b = Board(cross());
    expect(b.canFlip(0), isFalse);
    expect(b.flip(centre), isTrue);
    expect(b.weave.overAxisAt(centre), axisV);
    expect(b.flip(centre), isTrue);
    expect(b.weave.overAxisAt(centre), axisH);
  });

  test('a level clears only when the weave meets its targets', () {
    final p = cross(features: {centre: const Feature(FeatureKind.weave, 1)});
    final b = Board(p);
    for (final k in p.knots) {
      b.begin(k.path.first);
      b.extend(k.path.last);
      b.end();
    }
    expect(b.weave.completeCount, 2);
    expect(b.isCleared, isFalse);
    expect(b.wrongWeave(), centre);
    b.flip(centre);
    expect(b.isCleared, isTrue);
    expect(b.wrongWeave(), isNull);
  });

  test('hint threads take the solution weave with them', () {
    final p = cross(features: {centre: const Feature(FeatureKind.weave, 1)});
    final b = Board(p);
    for (final k in p.knots) {
      b.lay(k.colour, k.path);
    }
    expect(b.weave.overAxisAt(centre), axisV);
    expect(b.isCleared, isTrue);
  });

  test('weave targets and solution weave survive the level file', () {
    final p = cross(features: {centre: const Feature(FeatureKind.weave, 1, 0)});
    final back = Puzzle.fromJson(p.toJson());
    expect(back.freeWeave, isTrue);
    expect(back.solutionOver, {centre: axisV});
    expect(back.features[centre], const Feature(FeatureKind.weave, 1, 0));
    expect(back.toJson(), p.toJson());
  });

  test('generated woven levels: one solution, and it is the stored one', () {
    final gen = Generator(Random(11));
    var made = 0;
    for (var i = 0; i < 300 && made < 12; i++) {
      final p = gen.attempt(
        GenSpec(
          width: 6,
          height: 6,
          minThreads: 4,
          maxThreads: 5,
          patch: i.isEven ? (2, 2) : (2, 1),
          crossings: i % 3 == 0 ? 1 : 0,
          freeWeave: true,
          weaveSides: const {WeaveSide.front, WeaveSide.back, WeaveSide.both},
          clueKinds: const {FeatureKind.weave},
          minClues: const {FeatureKind.weave: 1},
        ),
      );
      if (p == null) continue;
      made++;
      final w = Weave(p, p.solution, over: p.solutionOver);
      expect(w.isCleared, isTrue);
      // At least one target needs the player to flip from the start.
      expect(
        p.features.entries.any(
          (e) =>
              e.value.kind == FeatureKind.weave &&
              p.solutionOver[e.key] != p.overAxis(e.key),
        ),
        isTrue,
      );
      final r = Solver(p).solve(limit: 2, maxNodes: 400000);
      expect(r.unique, isTrue);
    }
    expect(made, greaterThan(5));
  });

  test('without its targets, every solution the solver finds can be woven', () {
    final gen = Generator(Random(5));
    var checked = 0;
    for (var i = 0; i < 300 && checked < 10; i++) {
      final p = gen.attempt(
        GenSpec(
          width: 6,
          height: 6,
          minThreads: 4,
          maxThreads: 5,
          patch: i.isEven ? (2, 2) : (2, 1),
          freeWeave: true,
          weaveSides: const {WeaveSide.front, WeaveSide.back, WeaveSide.both},
          clueKinds: const {FeatureKind.weave},
          minClues: const {FeatureKind.weave: 1},
        ),
      );
      if (p == null) continue;
      // Keep one target so the pair constraint is still exercised.
      final targets = p.features.entries
          .where((e) => e.value.kind == FeatureKind.weave)
          .toList();
      final kept = p.copyWith(
        features: {targets.first.key: targets.first.value},
      );
      final r = Solver(kept).solve(limit: 100, maxNodes: 400000);
      expect(r.count, greaterThan(0));
      for (final sol in r.solutions) {
        final plain = Weave(kept, sol);
        final over = <int, int>{};
        for (final e in kept.features.entries) {
          final h = plain.occupant(e.key, axisH);
          final v = plain.occupant(e.key, axisV);
          expect(WeaveRule.canMeet(e.value, h, v), isTrue);
          final f = e.value;
          final hFits =
              (f.colour == null || h == f.colour) &&
              (f.back == null || v == f.back);
          over[e.key] = hFits ? axisH : axisV;
        }
        expect(Weave(kept, sol, over: over).isCleared, isTrue);
      }
      checked++;
    }
    expect(checked, greaterThan(3));
  });
}
