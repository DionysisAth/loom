import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../board/board_view.dart';
import '../core/game.dart';
import '../core/levels.dart';
import '../core/palette.dart';
import '../puzzle/puzzle.dart';
import 'chapter_card.dart';
import 'common.dart';

/// Plays the current level. When the hoop clears, the piece lifts out and
/// the next level slides in, with a chapter card in between chapters.
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  /// No progress for this long makes the hint button glow.
  static const hintNudge = Duration(seconds: 90);

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen>
    with TickerProviderStateMixin {
  late Game _game;
  late int _id;
  late Puzzle _puzzle;
  final BoardController _board = BoardController();
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Turning the hoop over to see the back of the cloth.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _turnGlow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _back = false;
  bool _turnedOnce = false;
  ChapterInfo? _card;
  bool _done = false;
  bool _clearing = false;
  Timer? _idle;
  final Stopwatch _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    _game = GameScope.read(context);
    _load(_game.level);
  }

  void _load(int id) {
    _id = id;
    _puzzle = _game.levels.level(id);
    _game.analytics.levelStart(id);
    _clock
      ..reset()
      ..start();
    _lift.value = 0;
    _enter.forward(from: 0);
    _clearing = false;
    _back = false;
    _turn.value = 0;
    _turnedOnce = false;
    // Levels with targets on the back invite a turn until the player tries it.
    final backTargets = _puzzle.features.values.any(
      (f) => f.kind == FeatureKind.weave && f.back != null,
    );
    if (backTargets) {
      _turnGlow.repeat(reverse: true);
    } else {
      _turnGlow
        ..stop()
        ..value = 0;
    }
    _resetIdle();
  }

  Future<void> _turnHoop() async {
    if (_turn.isAnimating || _clearing) return;
    _turnedOnce = true;
    _turnGlow
      ..stop()
      ..value = 0;
    _game.haptics.tick();
    await _turn.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _back = !_back;
      _turn.value = 0;
    });
  }

  void _resetIdle() {
    _idle?.cancel();
    if (_glow.isAnimating) {
      _glow.stop();
      _glow.value = 0;
    }
    _idle = Timer(LevelScreen.hintNudge, () {
      if (mounted) _glow.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    if (!_clearing && _board.started && !_done) {
      _game.analytics.quitMidLevel(_id, seconds: _clock.elapsed.inSeconds);
    }
    _idle?.cancel();
    _lift.dispose();
    _enter.dispose();
    _turn.dispose();
    _turnGlow.dispose();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _cleared(ClearStats s) async {
    _clearing = true;
    _idle?.cancel();
    _glow.stop();
    _glow.value = 0;
    await _game.levelCleared(
      _id,
      seconds: s.seconds,
      hints: s.hints,
      restarts: s.restarts,
      cuts: s.cuts,
    );
    await _lift.forward(from: 0);
    if (!mounted) return;
    if (_game.finished) {
      setState(() => _done = true);
      return;
    }
    final next = _game.levels.chapterAfter(_id);
    if (next != null) {
      setState(() => _card = next);
      return;
    }
    setState(() => _load(_id + 1));
  }

  void _cardDone() {
    if (!mounted) return;
    setState(() {
      _card = null;
      _load(_id + 1);
    });
  }

  void _hint() {
    if (_clearing) return;
    if (_board.hint()) {
      _game.hintUsed(_id);
      _resetIdle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final chapter = game.levels.chapterOf(_id);
    return Scaffold(
      body: Linen(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.home_rounded,
                      tooltip: 'Home',
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _done ? '' : 'Level $_id',
                            key: const Key('level-title'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Cloth.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!_done && _card == null)
                            _ChapterDots(chapter: chapter, current: _id),
                        ],
                      ),
                    ),
                    if (_puzzle.freeWeave && _card == null && !_done) ...[
                      AnimatedBuilder(
                        animation: _turnGlow,
                        builder: (context, _) => RoundButton(
                          key: const Key('turn'),
                          icon: Icons.flip_rounded,
                          tooltip: _back ? 'Show the front' : 'Show the back',
                          glow: _turnedOnce
                              ? 0
                              : Curves.easeInOut.transform(_turnGlow.value),
                          onPressed: _turnHoop,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    RoundButton(
                      icon: Icons.replay_rounded,
                      tooltip: 'Clear the hoop',
                      onPressed: _card == null && !_done
                          ? _board.restart
                          : null,
                    ),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _glow,
                      builder: (context, _) => RoundButton(
                        key: const Key('hint'),
                        icon: Icons.lightbulb_outline_rounded,
                        tooltip: 'Hint',
                        glow: Curves.easeInOut.transform(_glow.value),
                        onPressed: _card == null && !_done ? _hint : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _body(game),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Game game) {
    if (_done) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Every hoop is finished.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Cloth.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for testing Loom.',
              style: TextStyle(fontSize: 16, color: Cloth.inkSoft),
            ),
            const SizedBox(height: 24),
            WoodButton(label: 'Home', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }
    final card = _card;
    if (card != null) {
      return ChapterCard(
        chapter: card.number,
        mechanic: card.mechanic,
        onDone: _cardDone,
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_lift, _enter, _turn]),
      builder: (context, _) {
        final lift = Curves.easeInCubic.transform(_lift.value);
        final enter = Curves.easeOutCubic.transform(_enter.value);
        // Turning over: rotate to edge-on, swap sides, rotate back flat.
        final turn = Curves.easeInOut.transform(_turn.value);
        final showBack = turn < 0.5 ? _back : !_back;
        final angle = turn < 0.5 ? turn * pi : (turn - 1) * pi;
        final board = BoardView(
          key: const Key('board'),
          puzzle: _puzzle,
          controller: _board,
          sfx: game.sfx,
          haptics: game.haptics,
          symbols: game.settings.symbols,
          back: showBack,
          onProgress: _resetIdle,
          onCleared: _cleared,
        );
        return Opacity(
          opacity: (1 - lift) * enter,
          child: Transform.translate(
            offset: Offset(0, -70 * lift + 90 * (1 - enter)),
            child: Transform.scale(
              scale: 1 + 0.06 * lift - 0.04 * (1 - enter),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: board,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One dot per level in the chapter: filled for cleared, ringed for current.
class _ChapterDots extends StatelessWidget {
  const _ChapterDots({required this.chapter, required this.current});
  final ChapterInfo chapter;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var id = chapter.first; id <= chapter.last; id++)
        Container(
          width: id == chapter.last ? 11 : 8,
          height: id == chapter.last ? 11 : 8,
          margin: EdgeInsets.symmetric(
            horizontal: max(2, 3 - chapter.length / 6),
          ),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: id < current ? Cloth.wood : Colors.transparent,
            border: Border.all(
              color: id == current ? Cloth.ink : Cloth.wood,
              width: id == current ? 2 : 1.4,
            ),
          ),
        ),
    ],
  );
}
