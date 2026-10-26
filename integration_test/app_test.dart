// Launches the app on a device, opens level 1 and clears it by dragging.
//
//   flutter test integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loom/app.dart';
import 'package:loom/board/layout.dart';
import 'package:loom/core/save.dart';
import 'package:loom/main.dart';

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens without crashing and clears level 1 by dragging', (
    tester,
  ) async {
    // Real services, but a fresh in-memory save so the run always starts at level 1.
    final game = createGame(store: MemorySaveStore());
    await tester.pumpWidget(LoomApp(game: game));
    await waitFor(tester, find.byKey(const Key('continue')));
    expect(find.text('Level 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue')));
    await waitFor(tester, find.byKey(const Key('board')));
    await tester.pump(const Duration(milliseconds: 600));

    final puzzle = game.levels.level(1);
    final rect = tester.getRect(find.byKey(const Key('board')));
    final layout = BoardLayout(puzzle, rect.size);
    for (final knot in puzzle.knots) {
      final gesture = await tester.startGesture(
        rect.topLeft + layout.centre(knot.path.first),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (final cell in knot.path.skip(1)) {
        // Move in small steps, like a finger.
        final from =
            rect.topLeft +
            layout.centre(knot.path[knot.path.indexOf(cell) - 1]);
        final to = rect.topLeft + layout.centre(cell);
        for (var i = 1; i <= 4; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 4)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await waitFor(
      tester,
      find.text('Level 2'),
      timeout: const Duration(seconds: 10),
    );
    expect(game.level, 2);
    expect(game.data.tapestry, [1]);
  });
}
