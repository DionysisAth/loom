import 'dart:math';
import 'dart:ui';

import '../puzzle/puzzle.dart';

/// Where the hoop and its cells sit inside the board's box. Everything is
/// measured in cells, so the board scales to any screen.
class BoardLayout {
  BoardLayout(this.puzzle, this.size) {
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
  late final double cell;
  late final Offset origin;

  Rect get grid => origin & Size(cell * puzzle.width, cell * puzzle.height);

  Offset centre(int c) =>
      origin +
      Offset((puzzle.xOf(c) + 0.5) * cell, (puzzle.yOf(c) + 0.5) * cell);

  Rect cellRect(int c) =>
      Rect.fromCenter(center: centre(c), width: cell, height: cell);

  /// The cell under [p], or -1 if [p] is outside the grid.
  int cellAt(Offset p) {
    final x = ((p.dx - origin.dx) / cell).floor();
    final y = ((p.dy - origin.dy) / cell).floor();
    if (!puzzle.inside(x, y)) return -1;
    return puzzle.index(x, y);
  }

  /// The cell nearest to [p], even when [p] is just outside the grid.
  int nearestCell(Offset p) {
    final x = ((p.dx - origin.dx) / cell).floor().clamp(0, puzzle.width - 1);
    final y = ((p.dy - origin.dy) / cell).floor().clamp(0, puzzle.height - 1);
    return puzzle.index(x, y);
  }
}
