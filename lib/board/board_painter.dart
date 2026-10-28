import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../puzzle/puzzle.dart';
import '../puzzle/rules.dart';
import 'layout.dart';

/// Everything the painter needs for one frame.
class BoardScene {
  const BoardScene({
    required this.puzzle,
    required this.threads,
    required this.weave,
    this.active,
    this.finger,
    this.tailAmount = 0,
    this.symbols = true,
    this.teachCells = const {},
    this.knotPulse = const {},
    this.growColour,
    this.grow = 1,
    this.tighten = 0,
    this.ghostPath,
    this.ghostT = 0,
    this.time = 0,
    this.showViolations = true,
    this.back = false,
    this.flipPulse = const {},
    this.ghostTap,
  });

  final Puzzle puzzle;
  final Map<int, List<int>> threads;
  final Weave weave;

  /// The thread being dragged and where the finger is.
  final int? active;
  final Offset? finger;

  /// How far the loose end follows the finger (1 while dragging, easing to 0
  /// on release so the end snaps into its cell).
  final double tailAmount;
  final bool symbols;

  /// Cells to gently highlight on teaching levels.
  final Set<int> teachCells;

  /// Colour -> 0..1, a knot tightening after its thread arrived.
  final Map<int, double> knotPulse;

  /// A hint thread growing into place.
  final int? growColour;
  final double grow;

  /// 0..1, the threads drawing tight as the hoop clears.
  final double tighten;

  /// The teaching finger: the path it traces and its progress (0..1).
  final List<int>? ghostPath;
  final double ghostT;

  /// Seconds, for slow ambient pulses.
  final double time;
  final bool showViolations;

  /// Seen from the back of the cloth: mirrored, under-threads on top.
  final bool back;

  /// Crossing cell -> 0..1, a ripple after the player flipped it.
  final Map<int, double> flipPulse;

  /// The teaching finger tapping this crossing (uses [ghostT] for timing).
  final int? ghostTap;
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.scene);
  final BoardScene scene;

  late BoardLayout _l;
  double get _c => _l.cell;
  Puzzle get _p => scene.puzzle;

  @override
  void paint(Canvas canvas, Size size) {
    _l = BoardLayout(_p, size, mirrored: scene.back);
    _hoopShadow(canvas);
    _fabric(canvas);
    _hoop(canvas);
    for (var c = 0; c < _p.cellCount; c++) {
      if (_p.isCrossing(c)) _crossingPatch(canvas, c);
      final f = _p.features[c];
      if (f?.kind == FeatureKind.stitch) _stitchUnder(canvas, c, f!.colour!);
    }
    _teach(canvas);
    _ghostTrail(canvas);
    _threads(canvas);
    for (var c = 0; c < _p.cellCount; c++) {
      final f = _p.features[c];
      if (f == null) continue;
      switch (f.kind) {
        case FeatureKind.bead:
          _bead(canvas, c);
        case FeatureKind.pin:
          _pin(canvas, c);
        case FeatureKind.eyelet:
          _eyelet(canvas, c, f.colour!);
        case FeatureKind.stitch:
          _stitchCorner(canvas, c, f.colour!);
        case FeatureKind.weave:
          break; // drawn with the crossings
      }
    }
    for (final e in _p.features.entries) {
      if (e.value.kind == FeatureKind.weave) {
        _weaveTarget(canvas, e.key, e.value);
      }
    }
    _flipPulses(canvas);
    _knots(canvas);
    if (scene.showViolations) _violations(canvas);
    _ghostFinger(canvas);
    _ghostTapFinger(canvas);
  }

  /// The axis whose thread is seen on top from the side we are looking at.
  int _visibleOver(int c) {
    final over = scene.weave.overAxisAt(c);
    return scene.back ? 1 - over : over;
  }

  // ------------------------------------------------------------ the hoop --

  RRect get _outer => RRect.fromRectAndRadius(
    _l.grid.inflate(_c * 0.5),
    Radius.circular(_c * 0.62),
  );
  RRect get _inner => RRect.fromRectAndRadius(
    _l.grid.inflate(_c * 0.1),
    Radius.circular(_c * 0.28),
  );

  void _hoopShadow(Canvas canvas) {
    canvas.drawRRect(
      _outer.shift(Offset(0, _c * 0.12)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _c * 0.22),
    );
  }

  void _fabric(Canvas canvas) {
    final inner = _inner;
    // Loose backing cloth shows where the hoop's shape has no fabric.
    canvas.drawRRect(
      inner,
      Paint()..color = _p.hasHoles ? Cloth.looseCloth : Cloth.fabric,
    );
    final shape = _fabricShape();
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawPath(
      shape,
      Paint()..color = scene.back ? Cloth.fabricBack : Cloth.fabric,
    );
    // Linen weave.
    canvas.save();
    canvas.clipPath(shape);
    final weave = Paint()
      ..color = Cloth.fabricShade
      ..strokeWidth = max(0.6, _c * 0.012);
    final step = max(3.0, _c * 0.07);
    final r = inner.outerRect;
    for (var x = r.left; x < r.right; x += step) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), weave);
    }
    for (var y = r.top; y < r.bottom; y += step) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), weave);
    }
    // Faint cell guides: tiny cross marks at the cell corners.
    final mark = Paint()
      ..color = Cloth.inkSoft.withValues(alpha: 0.28)
      ..strokeWidth = max(1.0, _c * 0.025)
      ..strokeCap = StrokeCap.round;
    final m = _c * 0.06;
    for (var y = 1; y < _p.height; y++) {
      for (var x = 1; x < _p.width; x++) {
        final o = _l.origin + Offset(x * _c, y * _c);
        canvas
          ..drawLine(o + Offset(-m, -m), o + Offset(m, m), mark)
          ..drawLine(o + Offset(m, -m), o + Offset(-m, m), mark);
      }
    }
    canvas.restore();
    if (_p.hasHoles) _runningStitch(canvas, shape);
    canvas.restore();
  }

  Path _fabricShape() {
    var path = Path();
    for (var c = 0; c < _p.cellCount; c++) {
      if (_p.isHole(c)) continue;
      path.addRect(_l.cellRect(c).inflate(0.5));
    }
    if (!_p.hasHoles) return path;
    // Merge the cells into one outline.
    path = Path.combine(PathOperation.union, Path(), path);
    return path;
  }

  void _runningStitch(Canvas canvas, Path shape) {
    final paint = Paint()
      ..color = Cloth.inkSoft.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, _c * 0.03)
      ..strokeCap = StrokeCap.round;
    final dash = _c * 0.14, gap = _c * 0.1;
    // Inset slightly so the stitches sit on the fabric.
    for (final metric in shape.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  void _hoop(Canvas canvas) {
    final ring = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Cloth.woodLight, Cloth.wood, Cloth.woodDark],
        stops: const [0, 0.55, 1],
      ).createShader(_outer.outerRect);
    canvas.drawDRRect(_outer, _inner, ring);
    // Wood grain and edges.
    canvas.drawRRect(
      _outer.deflate(_c * 0.04),
      Paint()
        ..color = Cloth.woodLight.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.03,
    );
    canvas.drawRRect(
      _inner,
      Paint()
        ..color = Cloth.woodDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.035,
    );
    final mid = RRect.fromRectAndRadius(
      _l.grid.inflate(_c * 0.3),
      Radius.circular(_c * 0.45),
    );
    canvas.drawRRect(
      mid,
      Paint()
        ..color = Cloth.woodDark.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.025,
    );
    // Brass clasp at the top.
    final top = _outer.outerRect.topCenter;
    final clasp = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: top + Offset(0, _c * 0.2),
        width: _c * 0.7,
        height: _c * 0.5,
      ),
      Radius.circular(_c * 0.12),
    );
    canvas.drawRRect(
      clasp.shift(Offset(0, _c * 0.05)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      clasp,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8CF85), Cloth.brass, Cloth.brassDark],
        ).createShader(clasp.outerRect),
    );
    canvas.drawCircle(
      clasp.center,
      _c * 0.11,
      Paint()..color = Cloth.brassDark,
    );
    canvas.drawLine(
      clasp.center + Offset(-_c * 0.07, 0),
      clasp.center + Offset(_c * 0.07, 0),
      Paint()
        ..color = const Color(0xFFE8CF85)
        ..strokeWidth = _c * 0.03,
    );
  }

  // ------------------------------------------------------ cell markings --

  void _crossingPatch(Canvas canvas, int c) {
    final o = _l.centre(c);
    final w = _c * 0.16, len = _c * 0.78;
    final under = Paint()..color = Cloth.looseCloth.withValues(alpha: 0.9);
    final over = Paint()..color = Cloth.looseCloth;
    final h = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: len, height: w),
      Radius.circular(w / 2),
    );
    final v = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: w, height: len),
      Radius.circular(w / 2),
    );
    final hOnTop = _visibleOver(c) == axisH;
    canvas.drawRRect(hOnTop ? v : h, under);
    final top = hOnTop ? h : v;
    canvas.drawRRect(
      top.shift(Offset(0, _c * 0.02)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRRect(top, over);
    canvas.drawRRect(
      top,
      Paint()
        ..color = Cloth.woodDark.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.02,
    );
  }

  void _stitchUnder(Canvas canvas, int c, int colour) {
    final o = _l.centre(c);
    final y = yarn(colour);
    final d = _c * 0.24;
    final paint = Paint()
      ..color = y.color.withValues(alpha: 0.85)
      ..strokeWidth = _c * 0.11
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(o + Offset(-d, -d), o + Offset(d, d), paint)
      ..drawLine(o + Offset(d, -d), o + Offset(-d, d), paint..color = y.dark);
  }

  void _stitchCorner(Canvas canvas, int c, int colour) {
    final r = _l.cellRect(c);
    final y = yarn(colour);
    final at = r.topLeft + Offset(_c * 0.15, _c * 0.15);
    canvas.drawCircle(at, _c * 0.12, Paint()..color = Cloth.fabric);
    final d = _c * 0.07;
    final paint = Paint()
      ..color = y.color
      ..strokeWidth = _c * 0.05
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(at + Offset(-d, -d), at + Offset(d, d), paint)
      ..drawLine(at + Offset(d, -d), at + Offset(-d, d), paint);
  }

  void _teach(Canvas canvas) {
    if (scene.teachCells.isEmpty) return;
    final pulse = 0.5 + 0.5 * sin(scene.time * 3.2);
    for (final c in scene.teachCells) {
      canvas.drawCircle(
        _l.centre(c),
        _c * (0.46 + 0.05 * pulse),
        Paint()
          ..color = Cloth.brass.withValues(alpha: 0.25 + 0.25 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.06,
      );
    }
  }

  // ---------------------------------------------------------- the yarn --

  double get _yarnWidth => _c * 0.42;

  double _tightenScale(int index) {
    if (scene.tighten <= 0) return 1;
    final x = (scene.tighten - index * 0.07) / 0.45;
    if (x <= 0 || x >= 1) return 1;
    return 1 - 0.24 * sin(pi * x);
  }

  List<Offset> _points(int colour, List<int> path) {
    final pts = [for (final c in path) _l.centre(c)];
    final f = scene.finger;
    if (colour == scene.active &&
        f != null &&
        scene.tailAmount > 0 &&
        path.isNotEmpty) {
      final head = pts.last;
      var v = f - head;
      final maxLen = _c * 0.55;
      if (v.distance > maxLen) v = v / v.distance * maxLen;
      final end = head + v * scene.tailAmount;
      if ((end - head).distance > 0.5) pts.add(end);
    }
    return pts;
  }

  void _threads(Canvas canvas) {
    final order = scene.threads.keys.toList()..sort();
    // The thread in hand is drawn last so it sits on top while moving.
    if (scene.active != null && order.remove(scene.active)) {
      order.add(scene.active!);
    }
    final paths = <int, Path>{};
    for (var i = 0; i < order.length; i++) {
      final colour = order[i];
      final cells = scene.threads[colour]!;
      if (cells.length < 2 &&
          !(colour == scene.active && scene.finger != null)) {
        continue;
      }
      var path = smoothPath(_points(colour, cells), _c * 0.32);
      if (colour == scene.growColour && scene.grow < 1) {
        final metric = path.computeMetrics().toList();
        if (metric.isEmpty) continue;
        path = metric.first.extractPath(0, metric.first.length * scene.grow);
      }
      paths[colour] = path;
      paintYarn(
        canvas,
        path,
        yarn(colour),
        _yarnWidth * _tightenScale(i),
        symbols: scene.symbols,
        cell: _c,
      );
    }
    // At each full crossing, redraw the top thread across it.
    for (var c = 0; c < _p.cellCount; c++) {
      if (!_p.isCrossing(c) || !scene.weave.isFilled(c)) continue;
      final axis = _visibleOver(c);
      final colour = scene.weave.occupant(c, axis);
      if (colour < 0 || !paths.containsKey(colour)) continue;
      if (colour == scene.growColour && scene.grow < 1) continue;
      final o = _l.centre(c);
      final d = axis == axisH ? Offset(_c * 0.5, 0) : Offset(0, _c * 0.5);
      final seg = Path()
        ..moveTo((o - d).dx, (o - d).dy)
        ..lineTo((o + d).dx, (o + d).dy);
      paintYarn(
        canvas,
        seg,
        yarn(colour),
        _yarnWidth * _tightenScale(order.indexOf(colour)),
        symbols: false,
        cell: _c,
        caps: false,
      );
    }
  }

  // ------------------------------------------------------------ weaving --

  /// A weave target: a solid cross-stitch in the corner for the colour this
  /// side must show, and a small ring for the colour the other side must show.
  void _weaveTarget(Canvas canvas, int c, Feature f) {
    final r = _l.cellRect(c);
    final facing = scene.back ? f.back : f.colour;
    final other = scene.back ? f.colour : f.back;
    final bad =
        scene.weave.isFilled(c) &&
        const WeaveRule().violations(scene.weave).contains(c);
    if (facing != null) {
      final y = yarn(facing);
      final at = r.topLeft + Offset(_c * 0.2, _c * 0.2);
      canvas.drawCircle(at, _c * 0.19, Paint()..color = Cloth.fabric);
      canvas.drawCircle(
        at,
        _c * 0.19,
        Paint()
          ..color = (bad ? Cloth.warn : y.dark).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.025,
      );
      final d = _c * 0.095;
      final paint = Paint()
        ..color = y.color
        ..strokeWidth = _c * 0.07
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(at + Offset(-d, -d), at + Offset(d, d), paint)
        ..drawLine(at + Offset(d, -d), at + Offset(-d, d), paint);
    }
    if (other != null) {
      final y = yarn(other);
      final at = r.bottomRight - Offset(_c * 0.2, _c * 0.2);
      canvas.drawCircle(at, _c * 0.17, Paint()..color = Cloth.fabric);
      canvas.drawCircle(
        at,
        _c * 0.11,
        Paint()
          ..color = y.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.05,
      );
      // A little turn arrow: "on the other side".
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: _c * 0.16),
        -pi * 0.9,
        pi * 0.8,
        false,
        Paint()
          ..color = Cloth.inkSoft.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.02,
      );
    }
  }

  void _flipPulses(Canvas canvas) {
    for (final e in scene.flipPulse.entries) {
      final t = e.value;
      canvas.drawCircle(
        _l.centre(e.key),
        _c * (0.3 + 0.35 * t),
        Paint()
          ..color = Cloth.brass.withValues(alpha: 0.6 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.06 * (1 - t) + 1,
      );
    }
  }

  /// The teaching finger tapping a crossing: comes in, presses, lets go.
  void _ghostTapFinger(Canvas canvas) {
    final c = scene.ghostTap;
    if (c == null) return;
    final t = scene.ghostT;
    final pos = _l.centre(c) + Offset(_c * 0.08, _c * 0.12);
    var alpha = 1.0, scale = 1.0;
    if (t < 0.25) {
      alpha = t / 0.25;
      scale = 1.35 - 0.35 * (t / 0.25);
    } else if (t < 0.4) {
      scale = 1 - 0.18 * sin(pi * (t - 0.25) / 0.15);
    } else if (t > 0.7) {
      alpha = max(0, 1 - (t - 0.7) / 0.3);
    }
    if (t >= 0.3 && t < 0.7) {
      final rt = (t - 0.3) / 0.4;
      canvas.drawCircle(
        _l.centre(c),
        _c * (0.25 + 0.3 * rt),
        Paint()
          ..color = Cloth.ink.withValues(alpha: 0.3 * (1 - rt))
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.04,
      );
    }
    final r = _c * 0.3 * scale;
    canvas.drawCircle(
      pos + Offset(_c * 0.04, _c * 0.07),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _c * 0.08),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = Cloth.ink.withValues(alpha: 0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.03,
    );
  }

  // ---------------------------------------------------------- features --

  void _bead(Canvas canvas, int c) {
    final o = _l.centre(c);
    final links = scene.weave.links(c);
    final r = _c * 0.2;
    final vertical = links == (1 << 1 | 1 << 3);
    final rect = Rect.fromCenter(
      center: o,
      width: vertical ? r * 1.7 : r * 2.3,
      height: vertical ? r * 2.3 : r * 1.7,
    );
    canvas.drawOval(
      rect.shift(Offset(0, _c * 0.04)),
      Paint()..color = const Color(0x40000000),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: const [Colors.white, Cloth.pearl, Color(0xFFCFC6B8)],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = Cloth.inkSoft.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.02,
    );
    if (links == 0) {
      canvas.drawCircle(
        o,
        r * 0.28,
        Paint()..color = Cloth.inkSoft.withValues(alpha: 0.6),
      );
    }
  }

  void _pin(Canvas canvas, int c) {
    final o = _l.centre(c);
    final head = o + Offset(-_c * 0.06, -_c * 0.08);
    final tip = o + Offset(_c * 0.2, _c * 0.24);
    canvas.drawLine(
      head + Offset(_c * 0.03, _c * 0.05),
      tip + Offset(_c * 0.03, _c * 0.05),
      Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = _c * 0.05
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      head,
      tip,
      Paint()
        ..color = Cloth.steel
        ..strokeWidth = _c * 0.04
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      head + Offset(_c * 0.02, _c * 0.04),
      _c * 0.15,
      Paint()..color = const Color(0x40000000),
    );
    final r = Rect.fromCircle(center: head, radius: _c * 0.15);
    canvas.drawCircle(
      head,
      _c * 0.15,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFF2F4F7), Color(0xFF8E99A6), Color(0xFF4F5966)],
          stops: [0, 0.5, 1],
        ).createShader(r),
    );
  }

  void _eyelet(Canvas canvas, int c, int colour) {
    final o = _l.centre(c);
    final y = yarn(colour);
    canvas.drawCircle(
      o + Offset(0, _c * 0.03),
      _c * 0.3,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.1,
    );
    canvas.drawCircle(
      o,
      _c * 0.3,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Cloth.brass,
            Color(0xFFEBD48C),
            Cloth.brassDark,
            Cloth.brass,
          ],
        ).createShader(Rect.fromCircle(center: o, radius: _c * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.1,
    );
    canvas.drawCircle(
      o,
      _c * 0.23,
      Paint()
        ..color = y.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.045,
    );
    if (scene.weave.occupant(c) < 0) {
      canvas.drawCircle(
        o,
        _c * 0.12,
        Paint()..color = y.color.withValues(alpha: 0.85),
      );
      if (scene.symbols) {
        paintSymbol(
          canvas,
          y.symbol,
          o,
          _c * 0.07,
          Paint()..color = Cloth.fabric,
        );
      }
    }
  }

  // ------------------------------------------------------------- knots --

  void _knots(Canvas canvas) {
    for (final k in _p.knots) {
      final y = yarn(k.colour);
      final connected = scene.weave.isComplete(k.colour);
      final pulse = scene.knotPulse[k.colour] ?? 0;
      final squeeze = 1 - 0.14 * sin(pi * pulse);
      final scale = _tightenScale(_p.knots.indexOf(k)) * squeeze;
      for (final end in [k.a, k.b]) {
        final o = _l.centre(end);
        final r = _c * 0.33 * scale;
        canvas.drawCircle(
          o + Offset(0, _c * 0.05),
          r,
          Paint()
            ..color = const Color(0x55000000)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _c * 0.05),
        );
        canvas.drawCircle(o, r, Paint()..color = y.dark);
        canvas.drawCircle(
          o,
          r * 0.86,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: [y.light, y.color, y.color],
              stops: const [0, 0.45, 1],
            ).createShader(Rect.fromCircle(center: o, radius: r)),
        );
        // A tied knot shows a wrapped ring.
        if (connected) {
          canvas.drawCircle(
            o,
            r * 0.64,
            Paint()
              ..color = y.dark.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = _c * 0.035,
          );
        }
        if (k.spool != null) {
          _spool(canvas, o, r, k, y);
        } else if (scene.symbols) {
          paintSymbol(
            canvas,
            y.symbol,
            o,
            r * 0.42,
            Paint()..color = Cloth.fabric.withValues(alpha: 0.95),
          );
        }
      }
    }
  }

  void _spool(Canvas canvas, Offset o, double r, Knot k, Yarn y) {
    final len = scene.threads[k.colour]?.length ?? 0;
    final want = k.spool!;
    // Progress ring: how much of the spool is used.
    final frac = (len / want).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r + _c * 0.07),
      -pi / 2,
      2 * pi * frac,
      false,
      Paint()
        ..color = len > want ? Cloth.warn : Cloth.brassDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.05
        ..strokeCap = StrokeCap.round,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$want',
        style: TextStyle(
          color: Cloth.fabric,
          fontSize: r * (want >= 10 ? 0.95 : 1.1),
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _violations(Canvas canvas) {
    final bad = scene.weave.violations;
    if (bad.isEmpty) return;
    final pulse = 0.5 + 0.5 * sin(scene.time * 6);
    for (final c in bad) {
      canvas.drawCircle(
        _l.centre(c),
        _c * 0.44,
        Paint()
          ..color = Cloth.warn.withValues(alpha: 0.35 + 0.35 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _c * 0.07,
      );
    }
  }

  // ---------------------------------------------------- teaching finger --

  List<Offset>? get _ghostPoints {
    final path = scene.ghostPath;
    if (path == null || path.length < 2) return null;
    return [for (final c in path) _l.centre(c)];
  }

  /// 0..1 progress along the path for the current phase of the loop.
  double get _ghostTravel => ((scene.ghostT - 0.15) / 0.65).clamp(0.0, 1.0);

  void _ghostTrail(Canvas canvas) {
    final pts = _ghostPoints;
    if (pts == null) return;
    final metric = smoothPath(pts, _c * 0.32).computeMetrics().first;
    final trail = metric.extractPath(0, metric.length * _ghostTravel);
    final fade = scene.ghostT > 0.85 ? 1 - (scene.ghostT - 0.85) / 0.15 : 1.0;
    canvas.drawPath(
      trail,
      Paint()
        ..color = Cloth.ink.withValues(alpha: 0.16 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _yarnWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _ghostFinger(Canvas canvas) {
    final pts = _ghostPoints;
    if (pts == null) return;
    final t = scene.ghostT;
    final metric = smoothPath(pts, _c * 0.32).computeMetrics().first;
    final pos = metric
        .getTangentForOffset(metric.length * _ghostTravel)!
        .position;
    var alpha = 1.0;
    var press = 1.0;
    if (t < 0.15) {
      alpha = t / 0.15;
      press = 1.3 - 0.3 * (t / 0.15);
    } else if (t > 0.85) {
      alpha = 1 - (t - 0.85) / 0.15;
      press = 1 + 0.3 * (t - 0.85) / 0.15;
    }
    final r = _c * 0.3 * press;
    final tipOffset = Offset(_c * 0.05, _c * 0.08);
    canvas.drawCircle(
      pos + tipOffset,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _c * 0.08),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = Cloth.ink.withValues(alpha: 0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _c * 0.03,
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}

/// A polyline with rounded corners.
Path smoothPath(List<Offset> pts, double radius) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final p0 = pts[i - 1], p1 = pts[i], p2 = pts[i + 1];
    final d1 = p1 - p0, d2 = p2 - p1;
    final l1 = d1.distance, l2 = d2.distance;
    if (l1 < 0.01 || l2 < 0.01) continue;
    final r = min(radius, min(l1, l2) / 2);
    final a = p1 - d1 / l1 * r;
    final b = p1 + d2 / l2 * r;
    path
      ..lineTo(a.dx, a.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, b.dx, b.dy);
  }
  if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// Draws a length of yarn along [path]: shadow, body, sheen, twisted plies
/// and (optionally) the colour's symbol every few cells.
void paintYarn(
  Canvas canvas,
  Path path,
  Yarn y,
  double width, {
  required double cell,
  bool symbols = false,
  bool caps = true,
}) {
  final cap = caps ? StrokeCap.round : StrokeCap.butt;
  canvas.drawPath(
    path.shift(Offset(0, width * 0.14)),
    Paint()
      ..color = const Color(0x38000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.12),
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = y.dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = y.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.8
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round,
  );
  final twist = Paint()
    ..color = y.dark.withValues(alpha: 0.5)
    ..strokeWidth = width * 0.09
    ..strokeCap = StrokeCap.round;
  final sheen = Paint()
    ..color = y.light.withValues(alpha: 0.55)
    ..strokeWidth = width * 0.07
    ..strokeCap = StrokeCap.round;
  final step = width * 0.42;
  final half = width * 0.36;
  var symbolAt = cell * 1.5;
  for (final metric in path.computeMetrics()) {
    for (var d = step * 0.5; d < metric.length; d += step) {
      final t = metric.getTangentForOffset(d);
      if (t == null) continue;
      final a = -t.angle + 0.95;
      final v = Offset(cos(a), sin(a)) * half;
      canvas.drawLine(t.position - v, t.position + v, twist);
      final s = Offset(cos(a), sin(a)) * half * 0.55;
      final shift =
          Offset(cos(-t.angle - pi / 2), sin(-t.angle - pi / 2)) * width * 0.12;
      canvas.drawLine(
        t.position - s + shift + v * 0.3,
        t.position + s * 0.3 + shift + v * 0.3,
        sheen,
      );
    }
    if (symbols) {
      for (; symbolAt < metric.length - cell * 0.6; symbolAt += cell * 3) {
        final t = metric.getTangentForOffset(symbolAt);
        if (t == null) continue;
        canvas.drawCircle(t.position, width * 0.3, Paint()..color = y.color);
        paintSymbol(
          canvas,
          y.symbol,
          t.position,
          width * 0.22,
          Paint()..color = y.light.withValues(alpha: 0.95),
        );
      }
    }
  }
}
