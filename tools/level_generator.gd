class_name LevelGenerator
extends RefCounted
## Builds Loom's levels from real weave structures so every solved cloth
## looks like fabric, then mutates them for variety. Editor/CI-only: the
## results are committed as levels/world_*.json.
##
## 1. Start from a seed structure (plain, twill, basket, point, border...).
## 2. Pick warp and weft colours from the world palette.
## 3. Build the target, then hide the parts the mode asks the player to set.
## 4. Reject if the start already matches, a shaft is never needed, more than
##    20% of cells are "either", or (full loom) fewer shafts would do.
## 5. Score and pick per slot so difficulty ramps within each world.

const MAX_EITHER := 0.2
const CANDIDATES := 400

const PALETTES := [
	["#f7f0e3", "#5b8def", "#ef6f6c", "#f2b84b", "#4fbf9a"],
	["#f6eef3", "#9a7bd8", "#f0905a", "#46b5c4", "#e8c547"],
	["#eef6f1", "#e86f95", "#5a86e0", "#f0b856", "#8f6fd6"],
]
const WORLD_NAMES := ["Lifting", "Threading", "Full Loom"]
const MODES := ["lifting", "threading", "full"]

const NAMES := {
	"plain": ["Plain Weave", "Tabby", "Linen", "Muslin", "Calico", "Homespun", "Batiste", "Voile"],
	"basket": ["Basket", "Hopsack", "Oxford", "Panama", "Matt Weave", "Monk's Cloth"],
	"rib": ["Warp Rib", "Cord", "Rep", "Grosgrain", "Ottoman", "Faille"],
	"twill": ["Twill", "Serge", "Drill", "Denim", "Jean", "Gabardine", "Chino", "Cavalry",
		"Whipcord", "Tweel"],
	"broken": ["Broken Twill", "Crow's Foot", "Dornik", "Satinet", "Cassimere", "Swansdown"],
	"point": ["Zigzag", "Chevron", "Herringbone", "Ripple", "Waves", "Arrowhead", "Fern",
		"Lightning", "Mountains"],
	"diamond": ["Diamond", "Goose Eye", "Bird's Eye", "Rosepath", "Lozenge", "Star", "Rose",
		"Snowflake", "Lantern", "Compass"],
	"border": ["Border", "Selvedge", "Frame", "Hem", "Window", "Ribbon", "Picture Frame",
		"Mantel", "Banner"],
	"blocks": ["Monk's Belt", "Blocks", "Squares", "Tiles", "Bricks", "Summer & Winter",
		"Windowpane", "Courtyard", "Stepping Stones"],
	"random": ["Sampler", "Scrap", "Patchwork", "Tweed", "Kilim", "Weaver's Note",
		"Remnant", "Fancy", "Homestead", "Pebble", "Bramble", "Lattice", "Heather",
		"Harvest", "Driftwood", "Orchard", "Meadow", "Hearth", "Bluebell", "Thistle"],
}
const SHOWPIECES := ["diamond", "point", "border", "blocks"]

var rng := RandomNumberGenerator.new()
var _used_names := {}
var _seen := {}


func _init(seed_value := 20261009) -> void:
	rng.seed = seed_value


## Returns the three worlds as JSON-ready dictionaries.
func generate() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	for w in 3:
		var levels: Array = []
		if w == 0:
			levels.append_array(tutorial_levels())
		for slot in _schedule(w):
			if levels.size() >= 20:
				break
			if slot is String and slot == "treadle_tutorials":
				levels.append_array(treadle_tutorials())
				continue
			levels.append(_make(w, slot, levels.size()))
		for i in levels.size():
			levels[i].id = "%d-%d" % [w + 1, i + 1]
		worlds.append({
			"world": w + 1,
			"name": WORLD_NAMES[w],
			"mode": MODES[w],
			"palette": PALETTES[w],
			"levels": levels,
		})
	return worlds


## The first five levels teach the loom: one switch on one row, then two rows,
## then several switches, a third shaft, and finally one drag.
func tutorial_levels() -> Array:
	return [
		_hand("First Lift", "lifting", 2, [1, 1, 1, 1], [0],
				[0, 1, 0, 1], [1], "tap"),
		_hand("Two Rows", "lifting", 2, [1, 1, 1, 1], [0, 0],
				[0, 1, 0, 1], [1, 2], "rows"),
		_hand("Stripes", "lifting", 2, [2, 2, 2, 2], [0, 0, 0, 0],
				[0, 0, 1, 1], [1, 3, 2, 0], "match"),
		_hand("Third Shaft", "lifting", 3, [1, 1, 1, 1, 1, 1], [0, 0, 0],
				[0, 1, 2, 0, 1, 2], [1, 2, 4], "shaft"),
		_hand("Tie a Thread", "threading", 2, [1, 1, 1, 1], [3, 3, 3, 3],
				[0, 1, 0, 1], [1, 2, 1, 2], "drag", {"threading": [0, 1, 0, -1]}),
	]


## Levels 11 and 12 introduce treadles: rows pegged to the same treadle move
## together, and tapping a row's peg moves it to the next treadle.
func treadle_tutorials() -> Array:
	var a := _hand("Treadles", "lifting", 2, [1, 1, 1, 1], [0, 0, 0, 0],
			[0, 0, 1, 1], [1, 2, 2, 1], "treadle", {"treadling": [0, 1, 1, 0]})
	a.treadles = 2
	a.solution.treadling = [0, 1, 1, 0]
	a.solution.tieup = [1, 2]
	var b := _hand("Move a Row", "lifting", 2, [2, 2, 2, 2], [0, 0, 0, 0],
			[0, 1, 0, 1], [1, 2, 1, 2], "peg")
	b.treadles = 2
	b.solution.treadling = [0, 1, 0, 1]
	b.solution.tieup = [1, 2]
	return [a, b]


func _hand(level_name: String, mode: String, shafts: int, warp: Array, weft: Array,
		thr: Array, lifts: Array, tutorial: String, start := {}) -> Dictionary:
	var level := {
		"name": level_name, "mode": mode, "shafts": shafts, "kind": "tutorial",
		"warp": warp, "weft": weft,
		"solution": {"threading": thr, "lifts": lifts},
		"tutorial": tutorial,
	}
	if not start.is_empty():
		level.start = start
	_seen[_key(level)] = true
	return level


## Loom size, shafts, kind and treadles for each generated slot of a world.
## World 1: plain lifting, then treadles from level 11.
func _schedule(w: int) -> Array:
	var s := []
	match w:
		0:
			s = [[4, 4, 2], [4, 4, 2], [5, 4, 2], [5, 5, 2], [5, 5, 2, "showpiece"],
				"treadle_tutorials",
				[4, 4, 2, "normal", 2], [5, 4, 2, "normal", 2], [4, 5, 2, "breather", 2],
				[5, 5, 2, "normal", 2], [5, 5, 3, "normal", 2], [5, 6, 3, "normal", 3],
				[6, 6, 3, "normal", 3], [6, 6, 3, "showpiece", 3]]
		1:
			s = [[5, 5, 3], [6, 5, 3], [6, 6, 3], [6, 6, 3], [5, 5, 3, "breather"],
				[6, 6, 3], [6, 6, 3], [7, 6, 3], [7, 7, 3], [7, 7, 3, "showpiece"],
				[7, 6, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3], [6, 6, 3, "breather"],
				[7, 7, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3, "showpiece"]]
		2:
			s = [[5, 5, 2], [6, 5, 2], [6, 6, 3], [6, 6, 3], [5, 5, 2, "breather"],
				[6, 6, 3], [6, 6, 3], [7, 6, 3], [7, 7, 3], [7, 7, 3, "showpiece"],
				[7, 6, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3], [6, 6, 3, "breather"],
				[7, 7, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3], [7, 7, 3, "showpiece"]]
	return s


func _make(w: int, slot: Array, position: int) -> Dictionary:
	var width: int = slot[0]
	var height: int = slot[1]
	var shafts: int = slot[2]
	var kind: String = slot[3] if slot.size() > 3 else "normal"
	var treadles: int = slot[4] if slot.size() > 4 else 0
	var mode: String = MODES[w]
	var pool: Array[Dictionary] = []
	for i in CANDIDATES:
		var structure: String
		if kind == "showpiece":
			structure = SHOWPIECES[rng.randi() % SHOWPIECES.size()]
		else:
			structure = _pick_structure(shafts)
		var cand := _candidate(w, mode, width, height, shafts, structure, kind)
		if treadles > 0 and not cand.is_empty():
			_add_treadles(cand, treadles)
		if cand.is_empty() or _seen.has(_key(cand)):
			continue
		if check(cand).is_empty():
			cand.score = score(cand)
			pool.append(cand)
	assert(not pool.is_empty(), "no valid candidate for world %d slot %d" % [w + 1, position + 1])
	pool.sort_custom(func(a, b): return a.score < b.score)
	var pick: Dictionary
	match kind:
		"breather":
			pick = pool[0]
		"showpiece":
			var sym := pool.filter(func(c): return _symmetric(c))
			pick = (sym if not sym.is_empty() else pool)[-1]
		_:
			# Ramp from the easier half to the harder half across the world.
			var t := clampf(float(position) / 19.0, 0.0, 1.0)
			pick = pool[int(lerpf(0.25, 0.85, t) * (pool.size() - 1))]
	_seen[_key(pick)] = true
	pick.erase("score")
	pick.erase("structure_name")
	pick.name = _name_for(pick.structure)
	pick.erase("structure")
	pick.kind = kind
	return pick


## Replaces a candidate's lifts with a treadled version: a few distinct
## tie-ups and a treadling pattern that uses every treadle.
func _add_treadles(cand: Dictionary, treadles: int) -> void:
	var k: int = cand.shafts
	var all := (1 << k) - 1
	var masks := []
	var guard := 0
	while masks.size() < treadles and guard < 50:
		guard += 1
		var m := 1 + rng.randi() % (all - 1) if all > 2 else 1 + rng.randi() % all
		if not masks.has(m):
			masks.append(m)
	if masks.size() < treadles:
		cand.clear()
		return
	var h: int = cand.weft.size()
	var pattern := []
	var style := rng.randi() % 4
	for r in h:
		match style:
			0:
				pattern.append(r % treadles)
			1:
				var cycle := range(treadles) + range(treadles - 2, 0, -1)
				pattern.append(cycle[r % cycle.size()])
			2:
				pattern.append((r / 2) % treadles)
			_:
				pattern.append(rng.randi() % treadles)
	for t in treadles:
		if not pattern.has(t):
			cand.clear()
			return
	var lifts := []
	for r in h:
		lifts.append(masks[pattern[r]])
	cand.treadles = treadles
	cand.solution.lifts = lifts
	cand.solution.treadling = pattern
	cand.solution.tieup = masks


func _pick_structure(shafts: int) -> String:
	var opts := ["plain", "basket", "rib", "random", "blocks", "border"] if shafts == 2 \
			else ["twill", "broken", "point", "diamond", "border", "blocks", "random", "random"]
	return opts[rng.randi() % opts.size()]


func _candidate(w: int, mode: String, width: int, height: int, shafts: int,
		structure: String, kind: String) -> Dictionary:
	var thr := _threading(structure, width, shafts)
	var lifts := _lifts(structure, height, shafts)
	if thr.is_empty() or lifts.is_empty():
		return {}
	if kind != "showpiece" and kind != "breather" and rng.randf() < 0.6:
		_mutate(thr, lifts, shafts)
	var colors := _colors(width, height, kind == "showpiece")
	return {
		"mode": mode, "shafts": shafts,
		"warp": colors[0], "weft": colors[1],
		"solution": {"threading": thr, "lifts": lifts},
		"structure": structure,
	}


func _threading(structure: String, width: int, k: int) -> Array:
	var t := []
	for c in width:
		match structure:
			"plain", "twill":
				t.append(c % k)
			"rib":
				t.append(c % 2)
			"basket":
				t.append((c / 2) % k)
			"broken":
				t.append([0, 1, 2, 1, 2, 0][c % 6] % k)
			"point", "diamond":
				var cycle := range(k) + range(k - 2, 0, -1)
				t.append(cycle[c % cycle.size()])
			"border":
				if c == 0 or c == width - 1:
					t.append(0)
				else:
					t.append(1 + (c - 1) % (k - 1))
			"blocks":
				var b := 2 if width < 7 else 3
				t.append((c / b) % k)
			_:
				t.append(rng.randi() % k)
	return t


func _lifts(structure: String, height: int, k: int) -> Array:
	var all := (1 << k) - 1
	var l := []
	for r in height:
		match structure:
			"plain", "basket":
				var step := r if structure == "plain" else r / 2
				l.append(1 << (step % 2) if k == 2 else [1, 6][step % 2])
			"rib":
				l.append([1, 2][(r / 2) % 2] if k == 2 else [1, 6][(r / 2) % 2])
			"twill", "broken":
				var base := 1 << (r % k)
				l.append(base if (structure == "twill") == (rng.randf() < 0.5) else all ^ base)
			"point", "diamond":
				var cycle := range(k) + range(k - 2, 0, -1)
				var s: int = cycle[r % cycle.size()]
				var mask := 1 << s
				if structure == "diamond":
					mask = all ^ mask
				l.append(mask)
			"border":
				if r == 0 or r == height - 1:
					l.append(1)
				else:
					l.append(all ^ 1 if k == 2 else (1 << (1 + (r - 1) % (k - 1))) | (r % 2))
			"blocks":
				var b := 2 if height < 7 else 3
				l.append((1 << ((r / b) % k)) | (1 if k > 2 and (r / b) % 2 == 1 else 0))
			_:
				l.append(1 + rng.randi() % (all - 1))
	return l


func _mutate(thr: Array, lifts: Array, k: int) -> void:
	for i in 1 + rng.randi() % 2:
		if rng.randf() < 0.5:
			thr[rng.randi() % thr.size()] = rng.randi() % k
		else:
			var r := rng.randi() % lifts.size()
			lifts[r] = lifts[r] ^ (1 << (rng.randi() % k))


## Warp and weft colour ids: at most three colours per level, and warp and
## weft draw from different colours so few cells are "either".
func _colors(width: int, height: int, symmetric: bool) -> Array:
	var ids := [0, 1, 2, 3, 4]
	_shuffle(ids)
	var warp_ids: Array = [ids[0]]
	var weft_ids: Array = [ids[1]]
	match rng.randi() % 3:
		0:
			warp_ids.append(ids[2])
		1:
			weft_ids.append(ids[2])
	return [_stripes(width, warp_ids, symmetric), _stripes(height, weft_ids, symmetric)]


func _stripes(n: int, palette: Array, symmetric: bool) -> Array:
	var out := []
	var scheme := rng.randi() % 4
	if palette.size() == 1:
		scheme = 0
	for i in n:
		var j := mini(i, n - 1 - i) if symmetric else i
		match scheme:
			0:
				out.append(palette[0])
			1:
				out.append(palette[(j / 2) % palette.size()])
			2:
				out.append(palette[1] if j == 0 else palette[0])
			_:
				out.append(palette[1] if j % 3 == 2 else palette[0])
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Problems that disqualify a level; empty when it is fine.
static func check(level: Dictionary) -> PackedStringArray:
	var errors := LevelLoader.validate(level)
	if not errors.is_empty():
		return errors
	var state := LoomState.from_level(level)
	if state.either_fraction() > MAX_EITHER:
		errors.append("too many either cells (%.0f%%)" % (state.either_fraction() * 100.0))
	if state.matches_target():
		errors.append("already solved at start")
	if not LoomSolver.is_solvable(state):
		errors.append("unsolvable")
	var thr: Array = level.solution.threading
	var lifts: Array = level.solution.lifts
	var warp_cells := 0
	for v in state.target.size():
		var c := v % state.width
		var r := v / state.width
		if thr[c] >= 0 and (lifts[r] >> thr[c]) & 1:
			warp_cells += 1
	var share := float(warp_cells) / state.target.size()
	if level.get("kind", "") != "tutorial" and (share < 0.2 or share > 0.8):
		errors.append("cloth is almost all warp or all weft")
	for s in level.shafts:
		if not thr.has(s):
			errors.append("shaft %d has no warps" % s)
			continue
		var lifted_rows := 0
		for m in lifts:
			if m & (1 << s):
				lifted_rows += 1
		if lifted_rows == 0 and level.get("kind", "") != "tutorial":
			errors.append("shaft %d never lifts" % s)
		elif lifted_rows == lifts.size() and level.mode != "lifting":
			errors.append("shaft %d always lifts" % s)
	if level.mode == "threading":
		var mk := LoomSolver.marks(state)
		for c in state.width:
			var options := LoomSolver.column_options(state, c, state.lifts, mk)
			var real := 0
			for o in options:
				if o >= 0:
					real += 1
			if real != 1:
				errors.append("warp %d fits %d shafts" % [c, real])
				break
	if level.get("treadles", 0) > 0:
		var none := PackedInt32Array()
		if not LoomSolver.solve_treadles(state, none, none, level.treadles - 1).is_empty():
			errors.append("solvable with fewer treadles")
	if level.mode == "full" and level.shafts > 2:
		var empty := PackedInt32Array()
		if not LoomSolver.solve_full(state, empty, empty, level.shafts - 1).is_empty():
			errors.append("solvable with fewer shafts")
	return errors


## Grid size + shafts x 3 + columns per shaft, plus 10 for full-loom levels.
static func score(level: Dictionary) -> float:
	var w: int = level.warp.size()
	var h: int = level.weft.size()
	var s: float = w * h / 4.0 + level.shafts * 3.0 + float(w) / level.shafts
	var switches := 0
	for m in level.solution.lifts:
		for b in level.shafts:
			if m & (1 << b):
				switches += 1
	s += switches * 0.3
	var distinct := {}
	for m in level.solution.lifts:
		distinct[m] = true
	s += distinct.size()
	if level.mode == "full":
		s += 10.0
	s += level.get("treadles", 0) * 4.0
	return s


static func _symmetric(level: Dictionary) -> bool:
	var state := LoomState.from_level(level)
	for r in state.height:
		for c in state.width / 2:
			if state.target_color(c, r) != state.target_color(state.width - 1 - c, r):
				return false
	return true


func _key(level: Dictionary) -> String:
	var t := LoomState.build_target(PackedInt32Array(level.warp), PackedInt32Array(level.weft),
			PackedInt32Array(level.solution.threading), PackedInt32Array(level.solution.lifts))
	return "%s|%s|%s|%s" % [level.mode, level.warp, level.weft, t]


func _name_for(structure: String) -> String:
	var pool: Array = NAMES.get(structure, NAMES.random)
	for n in pool:
		if not _used_names.has(n):
			_used_names[n] = true
			return n
	for n in NAMES.random:
		if not _used_names.has(n):
			_used_names[n] = true
			return n
	var base: String = pool[rng.randi() % pool.size()]
	var i := 2
	while _used_names.has("%s %d" % [base, i]):
		i += 1
	_used_names["%s %d" % [base, i]] = true
	return "%s %d" % [base, i]
