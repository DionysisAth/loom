import 'package:flutter/material.dart';

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
