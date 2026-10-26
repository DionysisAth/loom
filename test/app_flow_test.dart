import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loom/app.dart';
import 'package:loom/board/layout.dart';
import 'package:loom/core/analytics.dart';
import 'package:loom/core/audio.dart';
import 'package:loom/core/game.dart';
import 'package:loom/core/haptics.dart';
import 'package:loom/core/levels.dart';
import 'package:loom/core/save.dart';

Game testGame({SaveData data = const SaveData()}) => Game(
  store: MemorySaveStore(data),
  sfx: SilentSfx(),
  haptics: Haptics(),
  analytics: MemoryAnalytics(),
  levels: LevelRepository(),
);

Future<void> settle(WidgetTester tester, [int frames = 30]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Drags every solution thread of the level on screen, cell by cell.
Future<void> solveByDragging(WidgetTester tester, Game game, int id) async {
  final puzzle = game.levels.level(id);
  final rect = tester.getRect(find.byKey(const Key('board')));
  final layout = BoardLayout(puzzle, rect.size);
  for (final k in puzzle.knots) {
    final g = await tester.startGesture(
      rect.topLeft + layout.centre(k.path.first),
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (final c in k.path.skip(1)) {
      await g.moveTo(rect.topLeft + layout.centre(c));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  // Cached asset futures belong to the previous test's fake clock.
  setUp(() => rootBundle.clear());

  testWidgets('continue, clear level 1 by dragging, level 2 slides in', (
    tester,
  ) async {
    final game = testGame();
    await tester.pumpWidget(LoomApp(game: game));
    await settle(tester);
    expect(find.text('Level 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue')));
    await settle(tester);
    expect(find.byKey(const Key('board')), findsOneWidget);

    await solveByDragging(tester, game, 1);
    await settle(tester, 60);
    expect(game.level, 2);
    expect(game.data.tapestry, [1]);
    expect(find.text('Level 2'), findsOneWidget);
    final events = (game.analytics as MemoryAnalytics).events
        .map((e) => e.$1)
        .toList();
    expect(
      events,
      containsAllInOrder([
        'app_open',
        'level_start',
        'level_clear',
        'level_start',
      ]),
    );
    expect(
      (game.sfx as SilentSfx).played,
      containsAll(['pluck', 'knot', 'clear']),
    );
  });

  testWidgets('hints finish a level', (tester) async {
    final game = testGame(data: const SaveData(level: 23));
    await tester.pumpWidget(LoomApp(game: game));
    await settle(tester);
    await tester.tap(find.byKey(const Key('continue')));
    await settle(tester);
    for (var i = 0; i < 8 && game.level == 23; i++) {
      await tester.tap(find.byKey(const Key('hint')));
      await settle(tester, 30);
    }
    await settle(tester, 40);
    expect(game.level, 24);
    expect(game.data.hintsUsed, greaterThan(0));
  });

  testWidgets('a chapter card follows the showpiece', (tester) async {
    final game = testGame(data: const SaveData(level: 6));
    await tester.pumpWidget(LoomApp(game: game));
    await settle(tester);
    await tester.tap(find.byKey(const Key('continue')));
    await settle(tester);
    await solveByDragging(tester, game, 6);
    await settle(tester, 40);
    expect(find.byKey(const Key('chapter-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chapter-card')));
    await settle(tester, 20);
    expect(find.text('Level 7'), findsOneWidget);
  });

  testWidgets('home shows the tapestry once something is cleared', (
    tester,
  ) async {
    final game = testGame(data: const SaveData(level: 4, tapestry: [1, 2, 3]));
    await tester.pumpWidget(LoomApp(game: game));
    await settle(tester);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.byKey(const Key('tapestry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tapestry')));
    await settle(tester);
    expect(find.textContaining('Tapestry'), findsOneWidget);
  });
}
