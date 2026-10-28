import 'dart:math';
import 'dart:ui';

import '../puzzle/puzzle.dart';

/// Where the hoop and its cells sit inside the board's box. Everything is
/// measured in cells, so the board scales to any screen.
///
/// When [mirrored], the hoop is seen from the back: columns run right to
/// left, as they do when you turn a piece of embroidery over.
class BoardLayout {
  BoardLayout(this.puzzle, this.size, {this.mirrored = false}) {
    cell = min(
      size.width / (puzzle.width + 2 * frame),
      size.height / (puzzle.height + 2 * frame),
    );
    final gw = cell * puzzle.width, gh = cell * puzzle.height;
    origin = Offset((size.width - gw) / 2, (size.height - gh) / 2);
  }

  /// Space around the grid for the hoop, in cells.
  static const double frame = 0.62;

  final Puzzle puzzle;
  final Size size;
  final bool mirrored;

  /// Screen column of puzzle column [x] (they differ when mirrored).
  int _col(int x) => mirrored ? puzzle.width - 1 - x : x;
  late final double cell;
  late final Offset origin;

  Rect get grid => origin & Size(cell * puzzle.width, cell * puzzle.height);

  Offset centre(int c) =>
      origin +
      Offset((_col(puzzle.xOf(c)) + 0.5) * cell, (puzzle.yOf(c) + 0.5) * cell);

  Rect cellRect(int c) =>
      Rect.fromCenter(center: centre(c), width: cell, height: cell);

  /// The cell under [p], or -1 if [p] is outside the grid.
  int cellAt(Offset p) {
    final x = ((p.dx - origin.dx) / cell).floor();
    final y = ((p.dy - origin.dy) / cell).floor();
    if (!puzzle.inside(x, y)) return -1;
    return puzzle.index(_col(x), y);
  }

  /// The cell nearest to [p], even when [p] is just outside the grid.
  int nearestCell(Offset p) {
    final x = ((p.dx - origin.dx) / cell).floor().clamp(0, puzzle.width - 1);
    final y = ((p.dy - origin.dy) / cell).floor().clamp(0, puzzle.height - 1);
    return puzzle.index(_col(x), y);
  }
}
