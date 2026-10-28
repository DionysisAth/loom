// Generates assets/levels/chapter_XX.json from the chapter plan in
// tool/src/chapters.dart. Output is deterministic for a given seed.
//
//   dart run tool/generate.dart            # all chapters
//   dart run tool/generate.dart --only=3   # one chapter
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:loom/puzzle/generator.dart';
import 'package:loom/puzzle/puzzle.dart';
import 'package:loom/puzzle/rules.dart';

import 'src/chapters.dart';

const int seed = 20261025;

void main(List<String> args) {
  int? only;
  for (final a in args) {
    if (a.startsWith('--only=')) only = int.parse(a.substring(7));
  }
  var id = 0;
  final index = <Map<String, Object?>>[];
  for (final chapter in chapters) {
    final first = id + 1;
    final levels = <Puzzle>[];
    for (final (slotIndex, slot) in chapter.slots.indexed) {
      id++;
      if (only != null && chapter.number != only) continue;
      final p = _build(chapter, slot, id, slotIndex);
      levels.add(p);
      stdout.writeln(
        'level $id (ch ${chapter.number}, ${slot.role.name}): '
        '${p.width}x${p.height}, ${p.knots.length} threads, '
        '${p.features.length} clues, '
        '${p.knots.where((k) => k.spool != null).length} spools, '
        'difficulty ${p.difficulty.toStringAsFixed(1)}',
      );
    }
    index.add({
      'chapter': chapter.number,
      'mechanic': chapter.mechanic,
      'first': first,
      'last': id,
      'file': 'chapter_${chapter.number.toString().padLeft(2, '0')}.json',
    });
    if (only != null && chapter.number != only) continue;
    final file = File(
      'assets/levels/chapter_${chapter.number.toString().padLeft(2, '0')}.json',
    );
    file.writeAsStringSync(
      _encode({
        'chapter': chapter.number,
        'mechanic': chapter.mechanic,
        'levels': [for (final l in levels) l.toJson()],
      }),
    );
  }
  File('assets/levels/index.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'chapters': index}),
  );
}

/// One level per line keeps diffs readable.
String _encode(Map<String, Object?> chapter) {
  final b = StringBuffer()
    ..writeln('{')
    ..writeln('  "chapter": ${chapter['chapter']},')
    ..writeln('  "mechanic": ${jsonEncode(chapter['mechanic'])},')
    ..writeln('  "levels": [');
  final levels = chapter['levels'] as List;
  for (var i = 0; i < levels.length; i++) {
    b.write('    ${jsonEncode(levels[i])}');
    b.writeln(i + 1 < levels.length ? ',' : '');
  }
  b
    ..writeln('  ]')
    ..writeln('}');
  return b.toString();
}

Puzzle _build(Chapter chapter, Slot slot, int id, int slotIndex) {
  // Seeded by chapter and slot, not level number, so adding a chapter does
  // not reshuffle the levels after it.
  final rng = Random(_stableHash('$seed/${chapter.mechanic}/$slotIndex'));
  final gen = Generator(rng);
  final want = switch (slot.role) {
    Role.showpiece => 1,
    Role.teach || Role.breather => 4,
    _ => 6,
  };
  final candidates = <Puzzle>[];
  final clock = Stopwatch()..start();
  var tries = 0;
  while (candidates.length < want) {
    tries++;
    final p = gen.attempt(slot.spec, id: id, chapter: chapter.number);
    if (p != null) candidates.add(p);
    if (clock.elapsed > const Duration(minutes: 4)) {
      if (candidates.isNotEmpty) break;
      throw StateError('level $id: no level after $tries tries');
    }
  }
  candidates.sort((a, b) => a.difficulty.compareTo(b.difficulty));
  final picked = switch (slot.role) {
    Role.teach || Role.breather || Role.showpiece => candidates.first,
    Role.practice => candidates[candidates.length ~/ 2],
    Role.hard => candidates.last,
  };
  return picked.copyWith(
    id: id,
    chapter: chapter.number,
    mechanic: chapter.mechanic,
    tags: _tags(picked),
    teachColour: slot.role == Role.teach
        ? _teachColour(picked, chapter, slot)
        : null,
    showpiece: slot.showpiece,
  );
}

List<String> _tags(Puzzle p) => [
  if (p.hasCrossings) 'crossings',
  if (p.hasHoles) 'shapes',
  for (final k in FeatureKind.values)
    if (p.featureKinds.contains(k)) '${k.name}s',
  if (p.hasSpools) 'spools',
];

/// The thread the teaching finger traces: the one that shows the new idea.
int _teachColour(Puzzle p, Chapter chapter, Slot slot) {
  final w = Weave(p, p.solution);
  final kinds = slot.spec.minClues.keys.toSet();
  int score(Knot k) {
    var s = 0;
    for (final c in k.path) {
      switch (chapter.mechanic) {
        case 'crossings':
          if (p.isCrossing(c)) s += 10;
        case 'shapes':
          for (var d = 0; d < 4; d++) {
            final x = p.xOf(c) + dirDx[d], y = p.yOf(c) + dirDy[d];
            if (p.inside(x, y) && p.isHole(p.index(x, y))) s += 2;
          }
        case 'stitches':
          final f = p.features[c];
          if (f?.kind == FeatureKind.stitch && w.topColour(c) == k.colour) {
            s += 10;
          }
        default:
          final f = p.features[c];
          if (f != null && kinds.contains(f.kind)) s += 10;
      }
    }
    if (k.spool != null) s += 100;
    return s * 100 + k.path.length;
  }

  final sorted = List.of(p.knots)..sort((a, b) => score(b).compareTo(score(a)));
  return sorted.first.colour;
}

/// FNV-1a, so seeds do not depend on the Dart version's string hashing.
int _stableHash(String text) {
  var h = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}
