import 'package:flutter/material.dart';

import '../board/icons.dart';
import '../core/game.dart';
import '../core/palette.dart';
import 'common.dart';

/// Every cleared level as a small finished piece. View only.
class TapestryScreen extends StatelessWidget {
  const TapestryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final cleared = game.data.tapestry.toSet();
    return Scaffold(
      body: Linen(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Tapestry · ${cleared.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Cloth.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final ch in game.levels.chapters)
                      if (cleared.any((id) => id >= ch.first && id <= ch.last))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MechanicIcon(ch.mechanic, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var id = ch.first; id <= ch.last; id++)
                                      TapestryTile(
                                        id: id,
                                        cleared: cleared.contains(id),
                                        size: 56,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TapestryTile extends StatelessWidget {
  const TapestryTile({
    super.key,
    required this.id,
    required this.cleared,
    required this.size,
  });
  final int id;
  final bool cleared;
  final double size;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.read(context);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: cleared
            ? Cloth.fabric
            : Cloth.backdropDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(size * 0.14),
        border: Border.all(
          color: cleared ? Cloth.wood : Cloth.backdropDeep,
          width: 1.5,
        ),
      ),
      child: cleared ? MiniHoop(game.levels.level(id)) : null,
    );
  }
}
