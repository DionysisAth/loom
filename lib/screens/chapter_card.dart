import 'package:flutter/material.dart';

import '../board/icons.dart';
import '../core/palette.dart';

/// Shown between chapters: the next mechanic's icon, no words needed.
class ChapterCard extends StatefulWidget {
  const ChapterCard({
    super.key,
    required this.chapter,
    required this.mechanic,
    required this.onDone,
  });
  final int chapter;
  final String mechanic;
  final VoidCallback onDone;

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward().whenComplete(_done);
  bool _finished = false;

  void _done() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('chapter-card'),
    behavior: HitTestBehavior.opaque,
    onTap: _done,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final appear = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
        final fade = t > 0.8 ? 1 - (t - 0.8) / 0.2 : 1.0;
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.6 + 0.4 * appear,
                  child: MechanicIcon(widget.mechanic, size: 180),
                ),
                const SizedBox(height: 24),
                Text(
                  'Chapter ${widget.chapter}',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Cloth.inkSoft,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
