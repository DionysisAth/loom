import 'package:flutter_test/flutter_test.dart';
import 'package:loom/puzzle/puzzle.dart';
import 'package:loom/puzzle/rules.dart';

import 'helpers.dart';

void main() {
  final solved = ['AaaA', 'BbbB', 'CccC', 'DddD'];

  test('a full, connected weave is cleared', () {
    final p = picture(['AaA', 'BbB', 'CcC']);
    final w = Weave(p, p.solution);
    expect(w.errors, isEmpty);
    expect(w.isCleared, isTrue);
  });

  test('an empty cell blocks clearing', () {
    final p = picture(['AaA', 'BbB', 'CcC']);
    final threads = p.solution;
    threads[0] = [p.index(0, 0), p.index(1, 0), p.index(2, 0)];
    threads.remove(2);
    expect(Weave(p, threads).isCleared, isFalse);
  });

  test('overlapping threads are reported as errors', () {
    final p = picture(['AaA', 'BbB', 'CcC']);
    final threads = p.solution;
    threads[1] = [p.index(0, 1), p.index(1, 1), p.index(1, 0)];
    expect(Weave(p, threads).errors, isNotEmpty);
  });

  test('bead must be passed straight, pin must be turned at', () {
    final p = picture(
      ['Aaa', 'BBa', 'CCA'],
      features: {
        1: const Feature(FeatureKind.bead), // (1,0) straight: ok
        2: const Feature(FeatureKind.bead), // (2,0) corner: broken
      },
    );
    expect(p.knots.length, 3);
    final w = Weave(p, p.solution);
    expect(const BeadRule().violations(w).toList(), [2]);

    final q = picture(
      ['Aaa', 'BBa', 'CCA'],
      features: {
        1: const Feature(FeatureKind.pin), // straight: broken
        2: const Feature(FeatureKind.pin), // corner: ok
      },
    );
    expect(const PinRule().violations(Weave(q, q.solution)).toList(), [1]);
  });

  test('eyelet wants its colour', () {
    final p = picture(
      ['AaA', 'BbB', 'CcC'],
      features: {
        4: const Feature(FeatureKind.eyelet, 1),
        1: const Feature(FeatureKind.eyelet, 2),
      },
    );
    expect(const EyeletRule().violations(Weave(p, p.solution)).toList(), [1]);
  });

  test('spool wants an exact length', () {
    final ok = picture(['AaA', 'BbB', 'CcC'], spools: {'A': 3});
    expect(Weave(ok, ok.solution).isCleared, isTrue);
    final bad = picture(['AaA', 'BbB', 'CcC'], spools: {'A': 4});
    final w = Weave(bad, bad.solution);
    expect(const SpoolRule().violations(w), isNotEmpty);
    expect(w.isCleared, isFalse);
  });

  test('crossings: straight through, weave decides the top', () {
    // A runs across the middle row, B runs down the middle column.
    final p = picture(['.B.', 'A+A', '.B.']);
    final cross = p.index(1, 1);
    final a = [p.index(0, 1), cross, p.index(2, 1)];
    final b = [p.index(1, 0), cross, p.index(1, 2)];
    final w = Weave(p, {0: a, 1: b});
    expect(w.errors, isEmpty);
    expect(w.isFilled(cross), isTrue);
    // (1,1): x+y even, so the horizontal thread (A) is on top.
    expect(p.horizontalOnTop(cross), isTrue);
    expect(w.topColour(cross), 0);

    final turned = Weave(p, {
      0: [p.index(0, 1), cross, p.index(1, 0)],
    });
    expect(turned.errors, isNotEmpty);

    final stitched = p.copyWith(
      features: {cross: const Feature(FeatureKind.stitch, 1)},
    );
    expect(const StitchRule().violations(Weave(stitched, {0: a, 1: b})), [
      cross,
    ]);
  });

  test('json round trip keeps everything', () {
    final p = picture(
      solved,
      features: {
        5: const Feature(FeatureKind.bead),
        9: const Feature(FeatureKind.eyelet, 1),
      },
      spools: {'D': 4},
    );
    final back = Puzzle.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.knots.map((k) => k.path), p.knots.map((k) => k.path));
  });
}
