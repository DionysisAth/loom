import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The shapes drawn on knots and threads so colours can be told apart
/// without relying on hue.
enum YarnSymbol {
  circle,
  square,
  triangle,
  diamond,
  star,
  plus,
  heart,
  hexagon,
  ring,
  cross,
  chevron,
  bar,
  dots,
  crescent,
}

class Yarn {
  const Yarn(this.name, this.color, this.symbol);
  final String name;
  final Color color;
  final YarnSymbol symbol;

  Color get dark => Color.lerp(color, const Color(0xFF1E1408), 0.35)!;
  Color get light => Color.lerp(color, Colors.white, 0.45)!;
}

/// Yarn palette. Level files refer to colours by index.
const List<Yarn> yarns = [
  Yarn('madder', Color(0xFFC8423B), YarnSymbol.circle),
  Yarn('cornflower', Color(0xFF3F6FD1), YarnSymbol.square),
  Yarn('saffron', Color(0xFFE5A42B), YarnSymbol.triangle),
  Yarn('moss', Color(0xFF4E9A3F), YarnSymbol.diamond),
  Yarn('plum', Color(0xFF8C4BA8), YarnSymbol.star),
  Yarn('teal', Color(0xFF1F9690), YarnSymbol.plus),
  Yarn('rose', Color(0xFFE0739B), YarnSymbol.heart),
  Yarn('marigold', Color(0xFFE2691F), YarnSymbol.hexagon),
  Yarn('walnut', Color(0xFF835537), YarnSymbol.ring),
  Yarn('ink', Color(0xFF34436B), YarnSymbol.cross),
  // Muted yarns for the background of picture levels, so the motif stands out.
  Yarn('sage', Color(0xFF8DA587), YarnSymbol.chevron),
  Yarn('mist', Color(0xFF8BA0B6), YarnSymbol.bar),
  Yarn('sand', Color(0xFFC6A577), YarnSymbol.dots),
  Yarn('heather', Color(0xFFA78FA7), YarnSymbol.crescent),
];

Yarn yarn(int index) => yarns[index % yarns.length];

/// Colours for the cloth, hoop and screen.
abstract final class Cloth {
  static const backdrop = Color(0xFFE9DFCF);
  static const backdropDeep = Color(0xFFDCCFBA);
  static const fabric = Color(0xFFF8F2E7);
  static const fabricShade = Color(0xFFEDE4D3);
  static const looseCloth = Color(0xFFD9CBB4);
  static const woodLight = Color(0xFFD6A970);
  static const wood = Color(0xFFBC8A52);
  static const woodDark = Color(0xFF8F6136);
  static const brass = Color(0xFFC9A54C);
  static const brassDark = Color(0xFF8C6F28);
  static const ink = Color(0xFF3B2F25);
  static const inkSoft = Color(0xFF7A6A5A);
  static const warn = Color(0xFFD2553F);
  static const pearl = Color(0xFFF4EFE8);
  static const steel = Color(0xFF9AA4AE);
}

/// Draws [symbol] centred on [c] with radius [r].
void paintSymbol(
  Canvas canvas,
  YarnSymbol symbol,
  Offset c,
  double r,
  Paint paint,
) {
  final path = Path();
  switch (symbol) {
    case YarnSymbol.circle:
      canvas.drawCircle(c, r * 0.8, paint);
      return;
    case YarnSymbol.square:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: c, radius: r * 0.72),
          Radius.circular(r * 0.15),
        ),
        paint,
      );
      return;
    case YarnSymbol.triangle:
      path
        ..moveTo(c.dx, c.dy - r * 0.9)
        ..lineTo(c.dx + r * 0.9, c.dy + r * 0.65)
        ..lineTo(c.dx - r * 0.9, c.dy + r * 0.65)
        ..close();
    case YarnSymbol.diamond:
      path
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.8, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.8, c.dy)
        ..close();
    case YarnSymbol.star:
      for (var i = 0; i < 10; i++) {
        final a = -1.5708 + i * 0.6283;
        final rr = i.isEven ? r : r * 0.45;
        final p = c + Offset(rr * _cos(a), rr * _sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
    case YarnSymbol.plus:
      final t = r * 0.32;
      path
        ..addRect(Rect.fromCenter(center: c, width: r * 1.8, height: t * 2))
        ..addRect(Rect.fromCenter(center: c, width: t * 2, height: r * 1.8));
    case YarnSymbol.heart:
      path
        ..moveTo(c.dx, c.dy + r * 0.85)
        ..cubicTo(
          c.dx - r * 1.3,
          c.dy - r * 0.1,
          c.dx - r * 0.55,
          c.dy - r * 1.05,
          c.dx,
          c.dy - r * 0.35,
        )
        ..cubicTo(
          c.dx + r * 0.55,
          c.dy - r * 1.05,
          c.dx + r * 1.3,
          c.dy - r * 0.1,
          c.dx,
          c.dy + r * 0.85,
        )
        ..close();
    case YarnSymbol.hexagon:
      for (var i = 0; i < 6; i++) {
        final a = i * 1.0472;
        final p = c + Offset(r * 0.85 * _cos(a), r * 0.85 * _sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
    case YarnSymbol.ring:
      final ring = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.38;
      canvas.drawCircle(c, r * 0.62, ring);
      return;
    case YarnSymbol.chevron:
      final v = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * 0.4;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - r * 0.75, c.dy - r * 0.35)
          ..lineTo(c.dx, c.dy + r * 0.45)
          ..lineTo(c.dx + r * 0.75, c.dy - r * 0.35),
        v,
      );
      return;
    case YarnSymbol.bar:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r * 1.8, height: r * 0.7),
          Radius.circular(r * 0.35),
        ),
        paint,
      );
      return;
    case YarnSymbol.dots:
      canvas
        ..drawCircle(c + Offset(-r * 0.45, 0), r * 0.38, paint)
        ..drawCircle(c + Offset(r * 0.45, 0), r * 0.38, paint);
      return;
    case YarnSymbol.crescent:
      path
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.85))
        ..addOval(
          Rect.fromCircle(
            center: c + Offset(r * 0.45, -r * 0.2),
            radius: r * 0.7,
          ),
        )
        ..fillType = PathFillType.evenOdd;
    case YarnSymbol.cross:
      final x = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.42;
      final d = r * 0.62;
      canvas
        ..drawLine(c + Offset(-d, -d), c + Offset(d, d), x)
        ..drawLine(c + Offset(d, -d), c + Offset(-d, d), x);
      return;
  }
  canvas.drawPath(path, paint);
}

double _cos(double a) => math.cos(a);
double _sin(double a) => math.sin(a);
