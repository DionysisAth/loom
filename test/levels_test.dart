import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loom/puzzle/puzzle.dart';
import 'package:loom/puzzle/rules.dart';
import 'package:loom/puzzle/solver.dart';

void main() {
  final index = jsonDecode(
    File('assets/levels/index.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final chapters = (index['chapters'] as List).cast<Map<String, Object?>>();
  final levels = <Puzzle>[];
  for (final c in chapters) {
    final j = jsonDecode(
      File('assets/levels/${c['file']}').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final l in (j['levels'] as List).cast<Map<String, Object?>>()) {
      levels.add(Puzzle.fromJson(l));
    }
  }

  test('60 levels in 8 chapters, numbered in order', () {
    expect(chapters.length, 8);
    expect(levels.length, 60);
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].id, i + 1);
    }
    for (final c in chapters) {
      final inChapter = levels
          .where((l) => l.chapter == c['chapter'])
          .map((l) => l.id)
          .toList();
      expect(inChapter.first, c['first']);
      expect(inChapter.last, c['last']);
      expect(inChapter.length, inInclusiveRange(6, 11));
    }
  });

  test('every chapter ends with a showpiece and starts by teaching', () {
    for (final c in chapters) {
      final last = levels[(c['last'] as int) - 1];
      expect(last.showpiece, isNotNull, reason: 'level ${last.id}');
      if (c['mechanic'] != 'mix') {
        final first = levels[(c['first'] as int) - 1];
        expect(first.teachColour, isNotNull, reason: 'level ${first.id}');
      }
    }
  });

  test('sizes grow from 3x3 to at most 9x9 with at most 7 threads', () {
    expect(levels.first.width, 3);
    expect(levels.first.height, 3);
    for (final p in levels) {
      expect(p.width, lessThanOrEqualTo(9));
      expect(p.height, lessThanOrEqualTo(9));
      expect(p.knots.length, inInclusiveRange(2, 7));
      expect(p.knots.map((k) => k.colour).toSet().length, p.knots.length);
    }
  });

  test('no two levels are the same', () {
    final seen = <String>{};
    for (final p in levels) {
      final key = jsonEncode(
        {...p.toJson()}
          ..remove('id')
          ..remove('difficulty')
          ..remove('chapter')
          ..remove('tags')
          ..remove('mechanic')
          ..remove('teach')
          ..remove('showpiece'),
      );
      expect(
        seen.add(key),
        isTrue,
        reason: 'level ${p.id} repeats an earlier level',
      );
    }
  });

  for (final p in levels) {
    test('level ${p.id}: stored solution clears it and is the only one', () {
      final w = Weave(p, p.solution);
      expect(w.errors, isEmpty);
      expect(w.isCleared, isTrue);
      final r = Solver(p).solve(limit: 2, maxNodes: 2000000);
      expect(r.gaveUp, isFalse);
      expect(r.count, 1);
      for (final k in p.knots) {
        final found = r.solutions.first[k.colour]!;
        final same =
            _same(found, k.path) || _same(found.reversed.toList(), k.path);
        expect(same, isTrue, reason: 'thread ${k.colour} differs');
      }
    });
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
