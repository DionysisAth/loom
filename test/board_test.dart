import 'package:flutter_test/flutter_test.dart';
import 'package:loom/puzzle/board.dart';
import 'package:loom/puzzle/puzzle.dart';

import 'helpers.dart';

void main() {
  // A 3x3 with three straight rows.
  Puzzle rows() => picture(['AaA', 'BbB', 'CcC']);

  test('drag from a knot to its twin connects', () {
    final p = rows();
    final b = Board(p);
    expect(b.begin(p.index(0, 0)), 0);
    final m1 = b.extend(p.index(1, 0));
    expect(m1.entered, [p.index(1, 0)]);
    final m2 = b.extend(p.index(2, 0));
    expect(m2.connected, isTrue);
    b.end();
    expect(b.isConnected(0), isTrue);
  });

  test('a fast drag fills the cells in between', () {
    final p = rows();
    final b = Board(p)..begin(p.index(0, 0));
    final m = b.extend(p.index(2, 0));
    expect(m.entered, [p.index(1, 0), p.index(2, 0)]);
    expect(m.connected, isTrue);
  });

  test('dragging back shortens the thread', () {
    final p = rows();
    final b = Board(p)..begin(p.index(0, 0));
    b.extend(p.index(1, 0));
    b.extend(p.index(1, 1));
    expect(b.threadOf(0)!.length, 3);
    final back = b.extend(p.index(1, 0));
    expect(back.left, 1);
    expect(b.threadOf(0), [p.index(0, 0), p.index(1, 0)]);
  });

  test('tapping a knot clears its thread', () {
    final p = rows();
    final b = Board(p)..begin(p.index(0, 0));
    b.extend(p.index(2, 0));
    b.end();
    b.begin(p.index(2, 0));
    b.end();
    expect(b.threadOf(0), isNull);
  });

  test('cannot enter another colour\'s knot or a hole', () {
    final p = picture(['A#A', 'BbB', 'CcC']);
    final b = Board(p)..begin(p.index(0, 0));
    expect(b.extend(p.index(1, 0)).changed, isFalse);
    expect(b.extend(p.index(0, 1)).changed, isFalse);
  });

  test('drawing over a thread cuts it, backing off restores it', () {
    final p = rows();
    final b = Board(p);
    b.begin(p.index(0, 1));
    b.extend(p.index(2, 1));
    b.end();
    expect(b.isConnected(1), isTrue);

    b.begin(p.index(0, 0));
    b.extend(p.index(1, 0));
    b.extend(p.index(1, 1)); // through B's middle
    // B is pulled back to its first knot.
    expect(b.threadOf(1), [p.index(0, 1)]);
    expect(b.isConnected(1), isFalse);
    b.extend(p.index(1, 0)); // back off
    expect(b.isConnected(1), isTrue);
    expect(b.end(), 0);
  });

  test('starting on a laid thread cuts it back there and continues', () {
    final p = rows();
    final b = Board(p)..begin(p.index(0, 0));
    b.extend(p.index(2, 0));
    b.end();
    expect(b.begin(p.index(1, 0)), 0);
    expect(b.threadOf(0), [p.index(0, 0), p.index(1, 0)]);
  });

  group('crossings', () {
    // A across the middle, B down the middle, C and D fill the corners.
    Puzzle cross() => picture(
      ['DBC', 'A+A', 'dBc'],
      extraPaths: {
        'A': [3, 4, 5],
        'B': [1, 4, 7],
        'D': [0, 6],
        'C': [2, 8],
      },
    );

    test('a thread goes straight through and may not turn inside', () {
      final p = cross();
      final b = Board(p)..begin(p.index(0, 1));
      b.extend(p.index(1, 1));
      // Turning up inside the crossing is refused.
      expect(b.extend(p.index(1, 0)).changed, isFalse);
      expect(b.extend(p.index(2, 1)).connected, isTrue);
    });

    test('a perpendicular thread passes without cutting', () {
      final p = cross();
      final b = Board(p)..begin(p.index(0, 1));
      b.extend(p.index(2, 1));
      b.end();
      b.begin(p.index(1, 0));
      expect(b.extend(p.index(1, 2)).connected, isTrue);
      expect(b.end(), 0);
      expect(b.isConnected(0), isTrue);
      expect(b.weave.isFilled(p.index(1, 1)), isTrue);
    });

    test('a thread released inside a crossing is pulled out of it', () {
      final p = cross();
      final b = Board(p)..begin(p.index(0, 1));
      b.extend(p.index(1, 1));
      b.end();
      expect(b.threadOf(0), isNull);
    });
  });

  test('hints lay the solution and cut what is in the way', () {
    final p = picture(['AaA', 'BbB', 'CcC']);
    final b = Board(p)..begin(p.index(0, 0));
    b.extend(p.index(0, 1)); // B's knot: refused
    b.extend(p.index(1, 0));
    b.extend(p.index(1, 1));
    b.end();
    final c = b.hintColour();
    expect(c, isNotNull);
    b.lay(c!, p.knotOf(c).path);
    for (var i = 0; i < p.knots.length; i++) {
      if (b.hintColour() == null) break;
      final next = b.hintColour()!;
      b.lay(next, p.knotOf(next).path);
    }
    expect(b.isCleared, isTrue);
    expect(b.hintColour(), isNull);
  });
}
