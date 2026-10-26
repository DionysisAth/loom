import 'package:flutter/material.dart';

import '../board/icons.dart';
import '../core/game.dart';
import '../core/palette.dart';
import 'common.dart';
import 'level_screen.dart';
import 'settings_screen.dart';
import 'tapestry_screen.dart';

/// The level number, one big Continue button, and the tapestry so far.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final finished = game.finished;
    final chapter = finished
        ? game.levels.chapters.last
        : game.levels.chapterOf(game.level);
    return Scaffold(
      body: Linen(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    RoundButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Settings',
                      onPressed: () => Navigator.push(
                        context,
                        _fade(const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              const Text(
                'Loom',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Cloth.ink,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              MechanicIcon(chapter.mechanic, size: 110),
              const SizedBox(height: 20),
              Text(
                finished ? 'Every hoop is finished' : 'Level ${game.level}',
                key: const Key('home-level'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Cloth.ink,
                ),
              ),
              if (finished)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'More hoops are on their way.',
                    style: TextStyle(color: Cloth.inkSoft, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 28),
              WoodButton(
                key: const Key('continue'),
                label: 'Continue',
                icon: Icons.play_arrow_rounded,
                onPressed: finished
                    ? null
                    : () => Navigator.push(context, _fade(const LevelScreen())),
              ),
              const Spacer(flex: 2),
              if (game.data.tapestry.isNotEmpty)
                GestureDetector(
                  key: const Key('tapestry'),
                  onTap: () =>
                      Navigator.push(context, _fade(const TapestryScreen())),
                  child: _TapestryStrip(cleared: game.data.tapestry),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The most recent pieces of the tapestry, as a band along the bottom.
class _TapestryStrip extends StatelessWidget {
  const _TapestryStrip({required this.cleared});
  final List<int> cleared;

  @override
  Widget build(BuildContext context) {
    final shown = cleared.length > 24
        ? cleared.sublist(cleared.length - 24)
        : cleared;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cloth.fabric.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cloth.wood.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in shown)
                TapestryTile(id: id, cleared: true, size: 34),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${cleared.length} ${cleared.length == 1 ? 'piece' : 'pieces'} in your tapestry',
            style: const TextStyle(color: Cloth.inkSoft, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

PageRoute<void> _fade(Widget page) => PageRouteBuilder(
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) =>
      FadeTransition(opacity: a, child: child),
  transitionDuration: const Duration(milliseconds: 280),
);
