import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../puzzle/puzzle.dart';
import '../puzzle/rules.dart';
import 'board_painter.dart';

/// The icon for a chapter's mechanic, shown on chapter cards and at home.
class MechanicIcon extends StatelessWidget {
  const MechanicIcon(this.mechanic, {super.key, this.size = 120});
  final String mechanic;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MechanicPainter(mechanic)),
  );
}

class _MechanicPainter extends CustomPainter {
  _MechanicPainter(this.mechanic);
  final String mechanic;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final cell = s / 4;
    final w = cell * 0.42;
    // A round patch of fabric with a wooden rim.
    canvas.drawCircle(
      c + Offset(0, s * 0.03),
      s * 0.48,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(c, s * 0.48, Paint()..color = Cloth.wood);
    canvas.drawCircle(c, s * 0.42, Paint()..color = Cloth.fabric);

    void thread(List<Offset> pts, int colour) => paintYarn(
      canvas,
      smoothPath([for (final p in pts) c + p * cell], cell * 0.3),
      yarn(colour),
      w,
      cell: cell,
    );
    void knot(Offset p, int colour) {
      final y = yarn(colour);
      canvas.drawCircle(c + p * cell, cell * 0.34, Paint()..color = y.dark);
      canvas.drawCircle(c + p * cell, cell * 0.28, Paint()..color = y.color);
    }

    switch (mechanic) {
      case 'threads':
        thread([
          const Offset(-1, -0.6),
          const Offset(0, -0.6),
          const Offset(0, 0.6),
          const Offset(1, 0.6),
        ], 0);
        knot(const Offset(-1, -0.6), 0);
        knot(const Offset(1, 0.6), 0);
      case 'crossings':
        thread([const Offset(0, -1.2), const Offset(0, 1.2)], 1);
        thread([const Offset(-1.2, 0), const Offset(1.2, 0)], 0);
      case 'shapes':
        final heart = Path()
          ..moveTo(c.dx, c.dy + s * 0.28)
          ..cubicTo(
            c.dx - s * 0.42,
            c.dy,
            c.dx - s * 0.22,
            c.dy - s * 0.32,
            c.dx,
            c.dy - s * 0.12,
          )
          ..cubicTo(
            c.dx + s * 0.22,
            c.dy - s * 0.32,
            c.dx + s * 0.42,
            c.dy,
            c.dx,
            c.dy + s * 0.28,
          );
        final dash = Paint()
          ..color = Cloth.inkSoft
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..strokeCap = StrokeCap.round;
        for (final m in heart.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += s * 0.07) {
            canvas.drawPath(m.extractPath(d, d + s * 0.04), dash);
          }
        }
      case 'beads':
        thread([const Offset(-1.2, -0.5), const Offset(1.2, -0.5)], 3);
        _bead(canvas, c + Offset(0, -0.5 * cell), cell);
        thread([
          const Offset(-1, 1.2),
          const Offset(-1, 0.6),
          const Offset(1, 0.6),
        ], 2);
        _pin(canvas, c + Offset(-1 * cell, 0.6 * cell), cell);
      case 'eyelets':
        thread([const Offset(-1.2, 0), const Offset(1.2, 0)], 4);
        _ring(canvas, c, cell);
      case 'stitches':
        final d = cell * 0.7;
        final p = Paint()
          ..strokeWidth = cell * 0.3
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(
            c + Offset(-d, -d),
            c + Offset(d, d),
            p..color = yarn(6).color,
          )
          ..drawLine(
            c + Offset(d, -d),
            c + Offset(-d, d),
            p..color = yarn(6).dark,
          );
      case 'spools':
        knot(Offset.zero, 5);
        final tp = TextPainter(
          text: TextSpan(
            text: '7',
            style: TextStyle(
              color: Cloth.fabric,
              fontSize: cell * 0.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.drawCircle(c, cell * 0.6, Paint()..color = yarn(5).dark);
        canvas.drawCircle(c, cell * 0.5, Paint()..color = yarn(5).color);
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: cell * 0.78),
          -pi / 2,
          pi * 1.4,
          false,
          Paint()
            ..color = Cloth.brassDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.12
            ..strokeCap = StrokeCap.round,
        );
      default:
        thread([const Offset(0, -1.2), const Offset(0, 1.2)], 1);
        thread([const Offset(-1.2, 0), const Offset(1.2, 0)], 0);
        _bead(canvas, c + Offset(-0.8 * cell, 0), cell * 0.8);
        _ring(canvas, c + Offset(0, 0.8 * cell), cell * 0.7);
    }
  }

  void _bead(Canvas canvas, Offset o, double cell) {
    final rect = Rect.fromCenter(
      center: o,
      width: cell * 0.9,
      height: cell * 0.7,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Colors.white, Cloth.pearl, Color(0xFFCFC6B8)],
        ).createShader(rect),
    );
  }

  void _pin(Canvas canvas, Offset o, double cell) {
    canvas.drawLine(
      o,
      o + Offset(cell * 0.4, cell * 0.45),
      Paint()
        ..color = Cloth.steel
        ..strokeWidth = cell * 0.08,
    );
    canvas.drawCircle(o, cell * 0.22, Paint()..color = const Color(0xFF7D8894));
  }

  void _ring(Canvas canvas, Offset o, double cell) {
    canvas.drawCircle(
      o,
      cell * 0.55,
      Paint()
        ..color = Cloth.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.2,
    );
  }

  @override
  bool shouldRepaint(_MechanicPainter old) => old.mechanic != mechanic;
}

/// A small finished piece for the tapestry: the solved threads on fabric.
class MiniHoop extends StatelessWidget {
  const MiniHoop(this.puzzle, {super.key});
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MiniPainter(puzzle));
}

class _MiniPainter extends CustomPainter {
  _MiniPainter(this.p);
  final Puzzle p;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = min(size.width / p.width, size.height / p.height);
    final origin = Offset(
      (size.width - cell * p.width) / 2,
      (size.height - cell * p.height) / 2,
    );
    Offset centre(int c) =>
        origin + Offset((p.xOf(c) + 0.5) * cell, (p.yOf(c) + 0.5) * cell);
    final weave = Weave(p, p.solution);
    for (final k in p.knots) {
      canvas.drawPath(
        smoothPath([for (final c in k.path) centre(c)], cell * 0.3),
        Paint()
          ..color = yarn(k.colour).color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.62
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var c = 0; c < p.cellCount; c++) {
      if (!p.isCrossing(c)) continue;
      final axis = p.overAxis(c);
      final colour = weave.occupant(c, axis);
      if (colour < 0) continue;
      final d = axis == axisH ? Offset(cell * 0.5, 0) : Offset(0, cell * 0.5);
      canvas.drawLine(
        centre(c) - d,
        centre(c) + d,
        Paint()
          ..color = yarn(colour).color
          ..strokeWidth = cell * 0.62,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) => old.p != p;
}
