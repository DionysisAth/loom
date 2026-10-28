import 'package:flutter/material.dart';

import '../board/icons.dart';
import '../core/game.dart';
import '../core/palette.dart';
import 'common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final s = game.settings;
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
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Cloth.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _Toggle(
                label: 'Sound',
                icon: Icons.music_note_rounded,
                value: s.sound,
                onChanged: (v) => game.updateSettings(s.copyWith(sound: v)),
              ),
              _Toggle(
                label: 'Vibration',
                icon: Icons.vibration_rounded,
                value: s.haptics,
                onChanged: (v) => game.updateSettings(s.copyWith(haptics: v)),
              ),
              _Toggle(
                label: 'Colour symbols',
                icon: Icons.category_rounded,
                value: s.symbols,
                onChanged: (v) => game.updateSettings(s.copyWith(symbols: v)),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Start again?'),
                      content: const Text(
                        'This clears your tapestry and takes you back to level 1.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Keep playing'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Start again'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await game.resetProgress();
                },
                child: const Text(
                  'Start again from level 1',
                  style: TextStyle(color: Cloth.warn),
                ),
              ),
              const SizedBox(height: 16),
              const _ChapterJump(),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Test build. Your progress and play statistics stay on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Cloth.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon, color: Cloth.ink),
    title: Text(label, style: const TextStyle(fontSize: 18, color: Cloth.ink)),
    value: value,
    activeThumbColor: Cloth.wood,
    onChanged: onChanged,
  );
}

/// Test builds: start any chapter, to try a new mechanic without replaying
/// everything before it. Not part of the finished game (no level select).
class _ChapterJump extends StatelessWidget {
  const _ChapterJump();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Column(
      children: [
        const Text(
          'Test build: jump to a chapter',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Cloth.inkSoft,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final ch in game.levels.chapters)
              GestureDetector(
                key: Key('jump-${ch.number}'),
                onTap: () async {
                  await game.jumpTo(ch.first);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    MechanicIcon(ch.mechanic, size: 46),
                    const SizedBox(height: 2),
                    Text(
                      '${ch.number}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ch.first == game.level
                            ? Cloth.ink
                            : Cloth.inkSoft,
                        fontWeight: ch.first == game.level
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
