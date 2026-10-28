/// Pure-Dart model of a Loom level. No Flutter imports here, so the same code
/// runs in the app, in unit tests and in the command-line level tools.
library;

/// The kind of a cell in the hoop.
enum CellKind { normal, hole, crossing }

/// A local rule placed on a single cell.
enum FeatureKind {
  /// The thread must pass straight through.
  bead,

  /// The thread must turn here.
  pin,

  /// The thread of [Feature.colour] must pass through.
  eyelet,

  /// The thread on top must be [Feature.colour].
  stitch,

  /// A weave target on a crossing in a free-weave level: the front of the
  /// cloth must show [Feature.colour] and/or the back must show
  /// [Feature.back]. The player chooses which thread goes over.
  weave,
}

class Feature {
  const Feature(this.kind, [this.colour, this.back]);
  final FeatureKind kind;
  final int? colour;

  /// For [FeatureKind.weave]: the colour the back of the cloth must show.
  final int? back;

  @override
  bool operator ==(Object other) =>
      other is Feature &&
      other.kind == kind &&
      other.colour == colour &&
      other.back == back;

  @override
  int get hashCode => Object.hash(kind, colour, back);

  @override
  String toString() => switch ((colour, back)) {
    (null, null) => kind.name,
    (final c, null) => '${kind.name}($c)',
    (final c, final b) => '${kind.name}($c/$b)',
  };
}

/// Directions: 0 right, 1 down, 2 left, 3 up. Even directions are horizontal.
const List<int> dirDx = [1, 0, -1, 0];
const List<int> dirDy = [0, 1, 0, -1];

/// Axis of travel. Crossings hold one thread per axis.
const int axisH = 0;
const int axisV = 1;
int axisOfDir(int dir) => dir & 1;
int oppositeDir(int dir) => (dir + 2) & 3;

/// A pair of knots of one colour, with the stored solution thread between them.
class Knot {
  Knot({required this.colour, required this.path, this.spool});

  /// Index into the yarn palette.
  final int colour;

  /// The solution thread, as cell indices from one knot to the other.
  final List<int> path;

  /// When set, the thread must be exactly this many cells long (knots included).
  final int? spool;

  int get a => path.first;
  int get b => path.last;
  int twinOf(int cell) => cell == a ? b : a;
}

class Puzzle {
  Puzzle({
    required this.id,
    required this.chapter,
    required this.width,
    required this.height,
    required this.kinds,
    required this.features,
    required this.knots,
    this.mechanic = 'threads',
    this.tags = const [],
    this.difficulty = 0,
    this.teachColour,
    this.showpiece,
    this.freeWeave = false,
    this.solutionOver = const {},
  }) {
    _knotAt = List.filled(width * height, -1);
    for (final k in knots) {
      _knotAt[k.a] = k.colour;
      _knotAt[k.b] = k.colour;
    }
  }

  final int id;
  final int chapter;
  final String mechanic;
  final List<String> tags;
  final double difficulty;
  final int width;
  final int height;
  final List<CellKind> kinds;
  final Map<int, Feature> features;
  final List<Knot> knots;

  /// Colour whose solution thread the teaching finger traces (teaching levels).
  final int? teachColour;

  /// Name of the picture the finished threads form, for showpiece levels.
  final String? showpiece;

  /// In a free-weave level the player chooses, at every crossing, which
  /// thread goes over. Otherwise the fixed weave of [overAxis] applies.
  final bool freeWeave;

  /// The axis on top at each crossing in the stored solution (free weave).
  final Map<int, int> solutionOver;

  late final List<int> _knotAt;

  int get cellCount => width * height;
  int index(int x, int y) => y * width + x;
  int xOf(int cell) => cell % width;
  int yOf(int cell) => cell ~/ width;

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  bool isHole(int cell) => kinds[cell] == CellKind.hole;
  bool isCrossing(int cell) => kinds[cell] == CellKind.crossing;

  /// Colour of the knot on [cell], or -1.
  int knotColourAt(int cell) => _knotAt[cell];
  bool isKnot(int cell) => _knotAt[cell] >= 0;

  Knot knotOf(int colour) => knots.firstWhere((k) => k.colour == colour);

  /// The neighbouring cell in [dir], or -1 if outside the hoop or a hole.
  int neighbour(int cell, int dir) {
    final x = xOf(cell) + dirDx[dir];
    final y = yOf(cell) + dirDy[dir];
    if (!inside(x, y)) return -1;
    final n = index(x, y);
    return isHole(n) ? -1 : n;
  }

  /// Direction from [a] to adjacent cell [b], or -1 if not adjacent.
  int dirBetween(int a, int b) {
    final dx = xOf(b) - xOf(a);
    final dy = yOf(b) - yOf(a);
    for (var d = 0; d < 4; d++) {
      if (dirDx[d] == dx && dirDy[d] == dy) return d;
    }
    return -1;
  }

  /// The fixed weave: on even cells the horizontal thread is on top. In a
  /// free-weave level this is only where each crossing starts.
  bool horizontalOnTop(int cell) => (xOf(cell) + yOf(cell)).isEven;
  int overAxis(int cell) => horizontalOnTop(cell) ? axisH : axisV;

  /// Number of cell slots that must be filled (crossings count twice).
  int get slotCount {
    var n = 0;
    for (final k in kinds) {
      if (k == CellKind.normal) n += 1;
      if (k == CellKind.crossing) n += 2;
    }
    return n;
  }

  Map<int, List<int>> get solution => {for (final k in knots) k.colour: k.path};

  Set<FeatureKind> get featureKinds =>
      features.values.map((f) => f.kind).toSet();
  bool get hasSpools => knots.any((k) => k.spool != null);
  bool get hasHoles => kinds.contains(CellKind.hole);
  bool get hasCrossings => kinds.contains(CellKind.crossing);

  // ---------------------------------------------------------------- JSON --

  static const _gridChars = {
    CellKind.normal: '.',
    CellKind.hole: '#',
    CellKind.crossing: '+',
  };

  Map<String, Object?> toJson() {
    final rows = <String>[];
    for (var y = 0; y < height; y++) {
      final b = StringBuffer();
      for (var x = 0; x < width; x++) {
        final i = index(x, y);
        final f = features[i];
        if (f?.kind == FeatureKind.bead) {
          b.write('o');
        } else if (f?.kind == FeatureKind.pin) {
          b.write('x');
        } else {
          b.write(_gridChars[kinds[i]]);
        }
      }
      rows.add(b.toString());
    }
    List<int> xy(int c) => [xOf(c), yOf(c)];
    final eyelets = <List<int>>[];
    final stitches = <List<int>>[];
    final weaves = <List<int>>[];
    final sortedCells = features.keys.toList()..sort();
    for (final c in sortedCells) {
      final f = features[c]!;
      if (f.kind == FeatureKind.eyelet) eyelets.add([...xy(c), f.colour!]);
      if (f.kind == FeatureKind.stitch) stitches.add([...xy(c), f.colour!]);
      if (f.kind == FeatureKind.weave) {
        weaves.add([...xy(c), f.colour ?? -1, f.back ?? -1]);
      }
    }
    final overs = [
      for (final c in solutionOver.keys.toList()..sort())
        [...xy(c), solutionOver[c]!],
    ];
    return {
      'id': id,
      'chapter': chapter,
      'mechanic': mechanic,
      'tags': tags,
      'difficulty': double.parse(difficulty.toStringAsFixed(2)),
      if (teachColour != null) 'teach': teachColour,
      if (showpiece != null) 'showpiece': showpiece,
      'w': width,
      'h': height,
      'grid': rows,
      if (eyelets.isNotEmpty) 'eyelets': eyelets,
      if (stitches.isNotEmpty) 'stitches': stitches,
      if (freeWeave) 'weave': 'free',
      if (weaves.isNotEmpty) 'weaves': weaves,
      if (overs.isNotEmpty) 'over': overs,
      'knots': [
        for (final k in knots)
          {
            'c': k.colour,
            if (k.spool != null) 'spool': k.spool,
            'path': [for (final c in k.path) ...xy(c)],
          },
      ],
    };
  }

  factory Puzzle.fromJson(Map<String, Object?> j) {
    final w = j['w'] as int;
    final h = j['h'] as int;
    final rows = (j['grid'] as List).cast<String>();
    final kinds = List.filled(w * h, CellKind.normal);
    final features = <int, Feature>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        switch (rows[y][x]) {
          case '#':
            kinds[i] = CellKind.hole;
          case '+':
            kinds[i] = CellKind.crossing;
          case 'o':
            features[i] = const Feature(FeatureKind.bead);
          case 'x':
            features[i] = const Feature(FeatureKind.pin);
          case '.':
            break;
          default:
            throw FormatException('Unknown grid char ${rows[y][x]}');
        }
      }
    }
    for (final e in (j['eyelets'] as List? ?? const [])) {
      final l = (e as List).cast<int>();
      features[l[1] * w + l[0]] = Feature(FeatureKind.eyelet, l[2]);
    }
    for (final e in (j['stitches'] as List? ?? const [])) {
      final l = (e as List).cast<int>();
      features[l[1] * w + l[0]] = Feature(FeatureKind.stitch, l[2]);
    }
    for (final e in (j['weaves'] as List? ?? const [])) {
      final l = (e as List).cast<int>();
      features[l[1] * w + l[0]] = Feature(
        FeatureKind.weave,
        l[2] < 0 ? null : l[2],
        l[3] < 0 ? null : l[3],
      );
    }
    final solutionOver = <int, int>{
      for (final e in (j['over'] as List? ?? const []))
        ((e as List)[1] as int) * w + (e[0] as int): e[2] as int,
    };
    final knots = <Knot>[];
    for (final k in (j['knots'] as List).cast<Map<String, Object?>>()) {
      final flat = (k['path'] as List).cast<int>();
      final path = <int>[
        for (var i = 0; i < flat.length; i += 2) flat[i + 1] * w + flat[i],
      ];
      knots.add(
        Knot(colour: k['c'] as int, path: path, spool: k['spool'] as int?),
      );
    }
    return Puzzle(
      id: j['id'] as int,
      chapter: j['chapter'] as int,
      mechanic: j['mechanic'] as String? ?? 'threads',
      tags: (j['tags'] as List? ?? const []).cast<String>(),
      difficulty: (j['difficulty'] as num? ?? 0).toDouble(),
      teachColour: j['teach'] as int?,
      showpiece: j['showpiece'] as String?,
      freeWeave: j['weave'] == 'free',
      solutionOver: solutionOver,
      width: w,
      height: h,
      kinds: kinds,
      features: features,
      knots: knots,
    );
  }

  /// A copy without the stored solution's spools/features changed, used by
  /// the generator when it adds or removes clues.
  Puzzle copyWith({
    Map<int, Feature>? features,
    List<Knot>? knots,
    int? id,
    int? chapter,
    String? mechanic,
    List<String>? tags,
    double? difficulty,
    int? teachColour,
    String? showpiece,
    bool? freeWeave,
    Map<int, int>? solutionOver,
  }) => Puzzle(
    id: id ?? this.id,
    chapter: chapter ?? this.chapter,
    mechanic: mechanic ?? this.mechanic,
    tags: tags ?? this.tags,
    difficulty: difficulty ?? this.difficulty,
    teachColour: teachColour ?? this.teachColour,
    showpiece: showpiece ?? this.showpiece,
    freeWeave: freeWeave ?? this.freeWeave,
    solutionOver: solutionOver ?? this.solutionOver,
    width: width,
    height: height,
    kinds: kinds,
    features: features ?? this.features,
    knots: knots ?? this.knots,
  );
}
