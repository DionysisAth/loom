import 'package:loom/puzzle/generator.dart';
import 'package:loom/puzzle/puzzle.dart';

/// How a level slot is picked from its candidates.
enum Role {
  /// Teaching level: the easiest candidate, with a demo thread.
  teach,

  /// Practice: a middling candidate.
  practice,

  /// The hardest candidate.
  hard,

  /// An easy rest between harder levels.
  breather,

  /// Hand-designed picture level that ends a chapter.
  showpiece,
}

class Slot {
  const Slot(this.role, this.spec, {this.showpiece});
  final Role role;
  final GenSpec spec;
  final String? showpiece;
}

class Chapter {
  const Chapter(this.number, this.mechanic, this.slots);
  final int number;
  final String mechanic;
  final List<Slot> slots;
}

// ------------------------------------------------------------ hoop shapes --

const round5 = ['#...#', '.....', '.....', '.....', '#...#'];

const heart7x6 = [
  '#..#..#',
  '.......',
  '.......',
  '#.....#',
  '##...##',
  '###.###',
];

const mitten6x7 = [
  '#...##',
  '#....#',
  '.....#',
  '......',
  '#.....',
  '#.....',
  '#....#',
];

const star7 = [
  '###.###',
  '##...##',
  '.......',
  '#.....#',
  '##...##',
  '#..#..#',
  '#.###.#',
];

const ring6 = ['......', '......', '..##..', '..##..', '......', '......'];

const diamond7 = [
  '###.###',
  '##...##',
  '#.....#',
  '.......',
  '#.....#',
  '##...##',
  '###.###',
];

const bell8 = [
  '###..###',
  '##....##',
  '#......#',
  '#......#',
  '#......#',
  '........',
  '........',
  '###..###',
];

const cloud8 = [
  '##..##..',
  '#.......',
  '........',
  '........',
  '........',
  '#......#',
  '##....##',
  '########',
];

const clover9 = [
  '#..#.#..#',
  '.........',
  '.........',
  '#.......#',
  '....#....',
  '#.......#',
  '.........',
  '.........',
  '#..#.#..#',
];

const cushion7 = [
  '#.....#',
  '.......',
  '.......',
  '.......',
  '.......',
  '.......',
  '#.....#',
];

// --------------------------------------------------------- showpiece art --
// Letters are regions; every thread stays inside one region, so the finished
// threads draw the picture. '#' is a hole.

// Palette: 0 red, 1 blue, 2 saffron, 3 moss, 4 plum, 5 teal, 6 rose,
// 7 marigold, 8 walnut, 9 ink; muted backgrounds: 10 sage, 11 mist,
// 12 sand, 13 heather.

const heartArt = [
  '.......',
  '.HH.HH.',
  '.HHHHH.',
  '.HHHHH.',
  '..HHH..',
  '...H...',
  '.......',
];

const fishArt = [
  '........',
  '.F..FF..',
  '.FFFFFF.',
  '..FFFFFF',
  '.FFFFFF.',
  '.F..FF..',
  '........',
];

const flowerArt = [
  '#PP#PP#',
  'PPPPPPP',
  'PPYYYPP',
  'PPPPPPP',
  '#PPGPP#',
  '###G###',
  '###G###',
];

const treeArt = [
  '###LL###',
  '##LLLL##',
  '#LLLLLL#',
  '#LLLLLL#',
  '##LLLL##',
  '###TT###',
  '###TT###',
  'GGGTTGGG',
];

const boatArt = [
  '........',
  '...S....',
  '...SS...',
  '...SSS..',
  '...SSSS.',
  '.HHHHHH.',
  '..HHHH..',
  'WWWWWWWW',
];

const butterflyArt = [
  'LL....RR',
  'LLL..RRR',
  'LLLBBRRR',
  'LLLBBRRR',
  'LLLBBRRR',
  'LLLBBRRR',
  'LLL..RRR',
  'LL....RR',
];

const houseArt = [
  '###RR###',
  '##RRRR##',
  '#RRRRRR#',
  'RRRRRRRR',
  'GWWWWWWG',
  'GWWDDWWG',
  'GWWDDWWG',
  'GGGGGGGG',
];

const moonArt = [
  '.........',
  '..MMM....',
  '.MM......',
  '.MM...S..',
  '.MM..SSS.',
  '.MM...S..',
  '..MMM....',
  '.........',
  '.........',
];

GenSpec _art(
  List<String> art,
  Map<String, List<int>> colours, {
  int minThreads = 4,
  int maxThreads = 7,
  Set<FeatureKind> clues = const {},
  bool spools = false,
  int crossings = 0,
  List<(int, int)> fixedCrossings = const [],
  Map<FeatureKind, int> minClues = const {},
  int minSpools = 0,
}) => GenSpec(
  width: art.first.length,
  height: art.length,
  minThreads: minThreads,
  maxThreads: maxThreads,
  motif: art,
  regionColours: colours,
  clueKinds: clues,
  spools: spools,
  crossings: crossings,
  fixedCrossings: fixedCrossings,
  minClues: minClues,
  minSpools: minSpools,
);

GenSpec _g(
  int w,
  int h,
  int minT,
  int maxT, {
  int crossings = 0,
  List<String>? shape,
  Set<FeatureKind> clues = const {},
  bool spools = false,
  Map<FeatureKind, int> minClues = const {},
  int minSpools = 0,
}) => GenSpec(
  width: w,
  height: h,
  minThreads: minT,
  maxThreads: maxT,
  crossings: crossings,
  shape: shape,
  clueKinds: clues,
  spools: spools,
  minClues: minClues,
  minSpools: minSpools,
);

const _bp = {FeatureKind.bead, FeatureKind.pin};
const _eye = {FeatureKind.eyelet};
const _st = {FeatureKind.stitch};
const _all = {
  FeatureKind.bead,
  FeatureKind.pin,
  FeatureKind.eyelet,
  FeatureKind.stitch,
};

final List<Chapter> chapters = [
  Chapter(1, 'threads', [
    Slot(Role.teach, _g(3, 3, 2, 3)),
    Slot(Role.teach, _g(4, 4, 3, 3)),
    Slot(Role.practice, _g(4, 4, 3, 4)),
    Slot(Role.practice, _g(5, 5, 3, 4)),
    Slot(Role.hard, _g(5, 5, 4, 5)),
    Slot(
      Role.showpiece,
      _art(
        heartArt,
        {
          'H': [0, 6, 7],
          '.': [11, 10, 13, 12],
        },
        minThreads: 6,
        maxThreads: 7,
      ),
      showpiece: 'heart',
    ),
  ]),
  Chapter(2, 'crossings', [
    Slot(Role.teach, _g(5, 5, 3, 4, crossings: 1)),
    Slot(Role.teach, _g(5, 5, 3, 4, crossings: 1)),
    Slot(Role.practice, _g(6, 6, 4, 5, crossings: 1)),
    Slot(Role.practice, _g(6, 6, 4, 5, crossings: 2)),
    Slot(Role.breather, _g(5, 5, 3, 4, crossings: 1)),
    Slot(Role.hard, _g(7, 7, 5, 6, crossings: 2)),
    Slot(
      Role.showpiece,
      _art(
        fishArt,
        {
          'F': [7, 2, 0, 6],
          '.': [11, 10, 13, 12],
        },
        crossings: 1,
        minThreads: 5,
        maxThreads: 7,
      ),
      showpiece: 'fish',
    ),
  ]),
  Chapter(3, 'shapes', [
    Slot(Role.teach, _g(5, 5, 3, 4, shape: round5)),
    Slot(Role.teach, _g(7, 6, 4, 5, shape: heart7x6)),
    Slot(Role.practice, _g(6, 7, 4, 5, shape: mitten6x7)),
    Slot(Role.practice, _g(7, 7, 4, 6, shape: star7)),
    Slot(Role.breather, _g(6, 6, 4, 5, shape: ring6)),
    Slot(Role.hard, _g(7, 7, 5, 6, shape: diamond7, crossings: 1)),
    Slot(
      Role.showpiece,
      _art(
        flowerArt,
        {
          'P': [6, 0, 4, 7, 1],
          'Y': [2],
          'G': [3],
        },
        minThreads: 6,
        maxThreads: 7,
      ),
      showpiece: 'flower',
    ),
  ]),
  Chapter(4, 'beads', [
    Slot(
      Role.teach,
      _g(
        6,
        6,
        4,
        5,
        clues: {FeatureKind.bead},
        minClues: {FeatureKind.bead: 2},
      ),
    ),
    Slot(
      Role.teach,
      _g(6, 6, 4, 5, clues: {FeatureKind.pin}, minClues: {FeatureKind.pin: 2}),
    ),
    Slot(Role.practice, _g(7, 7, 5, 6, clues: _bp)),
    Slot(Role.practice, _g(7, 7, 5, 6, clues: _bp, crossings: 1)),
    Slot(Role.breather, _g(6, 6, 4, 5, clues: _bp)),
    Slot(Role.hard, _g(7, 7, 5, 6, clues: _bp, shape: cushion7)),
    Slot(
      Role.showpiece,
      _art(
        treeArt,
        {
          'L': [3, 5],
          'T': [8],
          'G': [7, 2],
        },
        minThreads: 5,
        clues: _bp,
        minClues: {FeatureKind.bead: 1, FeatureKind.pin: 1},
      ),
      showpiece: 'tree',
    ),
  ]),
  Chapter(5, 'eyelets', [
    Slot(
      Role.teach,
      _g(6, 6, 4, 5, clues: _eye, minClues: {FeatureKind.eyelet: 1}),
    ),
    Slot(
      Role.teach,
      _g(6, 6, 4, 5, clues: _eye, minClues: {FeatureKind.eyelet: 2}),
    ),
    Slot(Role.practice, _g(7, 7, 5, 6, clues: _eye)),
    Slot(Role.practice, _g(7, 7, 5, 6, clues: _eye, crossings: 1)),
    Slot(Role.breather, _g(6, 6, 4, 5, clues: _eye)),
    Slot(Role.hard, _g(8, 8, 5, 7, clues: {..._eye, ..._bp}, shape: bell8)),
    Slot(
      Role.showpiece,
      _art(
        boatArt,
        {
          'S': [2, 0],
          'H': [8],
          'W': [1],
          '.': [11, 13, 12],
        },
        clues: {..._eye, ..._bp},
        minClues: {FeatureKind.eyelet: 2},
      ),
      showpiece: 'boat',
    ),
  ]),
  Chapter(6, 'stitches', [
    Slot(
      Role.teach,
      _g(
        6,
        6,
        4,
        5,
        crossings: 1,
        clues: _st,
        minClues: {FeatureKind.stitch: 1},
      ),
    ),
    Slot(
      Role.teach,
      _g(
        6,
        6,
        4,
        5,
        crossings: 2,
        clues: _st,
        minClues: {FeatureKind.stitch: 2},
      ),
    ),
    Slot(Role.practice, _g(7, 7, 5, 6, crossings: 2, clues: _st)),
    Slot(Role.practice, _g(7, 7, 5, 6, crossings: 2, clues: {..._st, ..._eye})),
    Slot(Role.breather, _g(6, 6, 4, 5, crossings: 1, clues: _st)),
    Slot(Role.hard, _g(8, 8, 5, 7, crossings: 3, clues: {..._st, ..._bp})),
    Slot(
      Role.showpiece,
      _art(
        butterflyArt,
        {
          'L': [4, 6],
          'R': [6, 4, 0],
          'B': [9],
          '.': [10, 12],
        },
        crossings: 2,
        clues: {..._st, ..._bp},
        minClues: {FeatureKind.stitch: 2},
      ),
      showpiece: 'butterfly',
    ),
  ]),
  Chapter(7, 'spools', [
    Slot(Role.teach, _g(6, 6, 4, 5, spools: true, minSpools: 1)),
    Slot(Role.teach, _g(6, 6, 4, 5, spools: true, minSpools: 2)),
    Slot(Role.practice, _g(7, 7, 5, 6, spools: true)),
    Slot(Role.practice, _g(7, 7, 5, 6, spools: true, crossings: 1)),
    Slot(Role.breather, _g(6, 6, 4, 5, spools: true)),
    Slot(Role.practice, _g(8, 8, 5, 7, spools: true, clues: _bp)),
    Slot(Role.hard, _g(8, 8, 5, 7, spools: true, clues: _eye, shape: cloud8)),
    Slot(
      Role.showpiece,
      _art(
        houseArt,
        {
          'R': [0, 7],
          'W': [2, 6],
          'D': [8],
          'G': [3],
        },
        minThreads: 4,
        spools: true,
        minSpools: 2,
        clues: _bp,
      ),
      showpiece: 'house',
    ),
  ]),
  Chapter(8, 'mix', [
    Slot(Role.practice, _g(8, 8, 5, 7, crossings: 2, clues: _st, spools: true)),
    Slot(Role.practice, _g(8, 8, 5, 7, shape: bell8, clues: {..._bp, ..._eye})),
    Slot(
      Role.practice,
      _g(8, 8, 5, 7, crossings: 2, clues: {..._eye, FeatureKind.pin}),
    ),
    Slot(Role.breather, _g(7, 7, 5, 6, crossings: 1, clues: _all)),
    Slot(
      Role.practice,
      _g(9, 9, 6, 7, shape: clover9, crossings: 2, clues: _st),
    ),
    Slot(Role.practice, _g(9, 9, 6, 7, clues: _bp, spools: true)),
    Slot(Role.hard, _g(9, 9, 6, 7, crossings: 2, clues: _all, spools: true)),
    Slot(Role.breather, _g(8, 8, 5, 7, crossings: 1, clues: _all)),
    Slot(Role.hard, _g(9, 9, 6, 7, crossings: 3, clues: _all, spools: true)),
    Slot(Role.hard, _g(9, 9, 7, 7, crossings: 3, clues: _all, spools: true)),
    Slot(
      Role.showpiece,
      _art(
        moonArt,
        {
          'M': [2, 7],
          'S': [0, 6],
          '.': [9, 11, 13, 1],
        },
        fixedCrossings: const [(6, 4)],
        clues: _all,
        spools: true,
      ),
      showpiece: 'moon',
    ),
  ]),
];
