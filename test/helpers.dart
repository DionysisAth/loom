import 'package:loom/puzzle/puzzle.dart';

/// Builds a solved puzzle from a picture: uppercase letters are knots,
/// lowercase letters are the thread of that colour, '#' is a hole.
/// Colour index is the letter's position in the alphabet (A = 0).
Puzzle picture(
  List<String> rows, {
  Map<int, Feature> features = const {},
  Map<String, int> spools = const {},
  Set<int> crossings = const {},
  Map<String, List<int>> extraPaths = const {},
}) {
  final h = rows.length, w = rows.first.length;
  final kinds = List.filled(w * h, CellKind.normal);
  final letter = List<String?>.filled(w * h, null);
  final knotCells = <String, List<int>>{};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final ch = rows[y][x];
      final i = y * w + x;
      if (ch == '#') {
        kinds[i] = CellKind.hole;
      } else if (ch == '+') {
        kinds[i] = CellKind.crossing;
      } else if (ch != '.') {
        letter[i] = ch.toLowerCase();
        if (ch.toUpperCase() == ch) {
          knotCells.putIfAbsent(ch.toLowerCase(), () => []).add(i);
        }
      }
    }
  }
  final knots = <Knot>[];
  for (final e in knotCells.entries) {
    final colour = e.key.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final path =
        extraPaths[e.key.toUpperCase()] ??
        _walk(e.value.first, e.key, letter, w, h);
    knots.add(
      Knot(colour: colour, path: path, spool: spools[e.key.toUpperCase()]),
    );
  }
  knots.sort((a, b) => a.colour.compareTo(b.colour));
  return Puzzle(
    id: 0,
    chapter: 0,
    width: w,
    height: h,
    kinds: kinds,
    features: features,
    knots: knots,
  );
}

List<int> _walk(int start, String l, List<String?> letter, int w, int h) {
  final path = [start];
  final seen = {start};
  var cur = start;
  while (true) {
    var next = -1;
    final x = cur % w, y = cur ~/ w;
    for (final (dx, dy) in const [(1, 0), (0, 1), (-1, 0), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final n = ny * w + nx;
      if (letter[n] == l && !seen.contains(n)) {
        next = n;
        break;
      }
    }
    if (next < 0) break;
    path.add(next);
    seen.add(next);
    cur = next;
  }
  return path;
}

int cellAt(Puzzle p, int x, int y) => p.index(x, y);
