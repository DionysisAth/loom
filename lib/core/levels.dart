import 'dart:convert';

import 'package:flutter/services.dart';

import '../puzzle/puzzle.dart';

class ChapterInfo {
  const ChapterInfo(
    this.number,
    this.mechanic,
    this.first,
    this.last,
    this.file,
  );
  final int number;
  final String mechanic;
  final int first;
  final int last;
  final String file;

  int get length => last - first + 1;

  factory ChapterInfo.fromJson(Map<String, Object?> j) => ChapterInfo(
    j['chapter'] as int,
    j['mechanic'] as String,
    j['first'] as int,
    j['last'] as int,
    j['file'] as String,
  );
}

/// The levels bundled in assets/levels.
class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final List<ChapterInfo> chapters = [];
  final Map<int, Puzzle> _levels = {};

  Future<void> load() async {
    if (chapters.isNotEmpty) return;
    final index = jsonDecode(
      await _bundle.loadString('assets/levels/index.json'),
    ) as Map<String, Object?>;
    for (final c in (index['chapters'] as List).cast<Map<String, Object?>>()) {
      chapters.add(ChapterInfo.fromJson(c));
    }
    for (final c in chapters) {
      final j = jsonDecode(
        await _bundle.loadString('assets/levels/${c.file}'),
      ) as Map<String, Object?>;
      for (final l in (j['levels'] as List).cast<Map<String, Object?>>()) {
        final p = Puzzle.fromJson(l);
        _levels[p.id] = p;
      }
    }
  }

  int get total => chapters.isEmpty ? 0 : chapters.last.last;

  Puzzle level(int id) => _levels[id]!;

  ChapterInfo chapterOf(int id) =>
      chapters.firstWhere((c) => id >= c.first && id <= c.last);

  bool isChapterEnd(int id) => chapterOf(id).last == id;

  /// The chapter that starts after level [id], if [id] ends a chapter.
  ChapterInfo? chapterAfter(int id) {
    if (!isChapterEnd(id)) return null;
    for (final c in chapters) {
      if (c.first == id + 1) return c;
    }
    return null;
  }
}
