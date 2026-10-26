import 'package:flutter/material.dart';

import '../core/palette.dart';

/// The soft linen backdrop behind every screen.
class Linen extends StatelessWidget {
  const Linen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LinenPainter(), child: child);
}

class _LinenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cloth.backdrop);
    final p = Paint()
      ..color = Cloth.backdropDeep.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // A soft vignette keeps the eye in the middle.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, Cloth.woodDark.withValues(alpha: 0.12)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_LinenPainter old) => false;
}

/// A big, soft, wooden button.
class WoodButton extends StatelessWidget {
  const WoodButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Cloth.woodLight, Cloth.wood],
              ),
              border: Border.all(color: Cloth.woodDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Cloth.fabric, size: 26),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Cloth.fabric,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button in the hoop's wood and brass.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.glow = 0,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// 0..1, a gentle brass glow inviting a tap.
  final double glow;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(Cloth.fabric, const Color(0xFFF6E3A8), glow),
            border: Border.all(
              color: Color.lerp(Cloth.wood, Cloth.brass, glow)!,
              width: 2 + glow * 2,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x30000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
              if (glow > 0)
                BoxShadow(
                  color: Cloth.brass.withValues(alpha: 0.6 * glow),
                  blurRadius: 18 * glow,
                  spreadRadius: 4 * glow,
                ),
            ],
          ),
          child: Icon(icon, color: Cloth.ink, size: 26),
        ),
      ),
    ),
  );
}
