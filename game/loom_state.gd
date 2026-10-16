class_name LoomState
extends RefCounted
## The whole loom as plain data: four small arrays and one rule that gives
## every crossing its colour. No nodes, so the solver, generator and tests
## reuse it without a scene.

## A row's lifts changed. `old_mask` is the previous bitmask.
signal row_changed(row: int, old_mask: int)
## A warp's shaft changed. `old_shaft` is the previous shaft (or UNTIED).
signal column_changed(col: int, old_shaft: int)
## The whole state was replaced (restart).
signal reset

const UNTIED := -1
const MAX_SHAFTS := 4

var width := 0
var height := 0
var shafts := 2
var warp_colors := PackedInt32Array()
var weft_colors := PackedInt32Array()
## Shaft each warp is tied to, or UNTIED (an untied warp never lifts).
var threading := PackedInt32Array()
## Bitmask per row of which shafts are lifted.
var lifts := PackedInt32Array()
## Target colour per cell, index `r * width + c`.
var target := PackedInt32Array()
var given_threading := false
var given_lifts := false


## Builds the state a player starts a level with.
static func from_level(level: Dictionary) -> LoomState:
	var s := LoomState.new()
	s.width = level.warp.size()
	s.height = level.weft.size()
	s.shafts = level.shafts
	s.warp_colors = PackedInt32Array(level.warp)
	s.weft_colors = PackedInt32Array(level.weft)
	var mode: String = level.mode
	s.given_threading = mode == "lifting"
	s.given_lifts = mode == "threading"
	var sol: Dictionary = level.solution
	s.target = build_target(s.warp_colors, s.weft_colors,
			PackedInt32Array(sol.threading), PackedInt32Array(sol.lifts))
	var start: Dictionary = level.get("start", {})
	if s.given_threading:
		s.threading = PackedInt32Array(sol.threading)
	elif start.has("threading"):
		s.threading = PackedInt32Array(start.threading)
	else:
		s.threading = _filled(s.width, UNTIED)
	if s.given_lifts:
		s.lifts = PackedInt32Array(sol.lifts)
	elif start.has("lifts"):
		s.lifts = PackedInt32Array(start.lifts)
	else:
		s.lifts = _filled(s.height, 0)
	return s


## The cloth that a threading and lifts would weave.
static func build_target(warp: PackedInt32Array, weft: PackedInt32Array,
		thr: PackedInt32Array, lft: PackedInt32Array) -> PackedInt32Array:
	var w := warp.size()
	var h := weft.size()
	var out := PackedInt32Array()
	out.resize(w * h)
	for r in h:
		for c in w:
			var lifted := thr[c] >= 0 and ((lft[r] >> thr[c]) & 1) == 1
			out[r * w + c] = warp[c] if lifted else weft[r]
	return out


static func _filled(n: int, value: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(n)
	a.fill(value)
	return a


func copy() -> LoomState:
	var s := LoomState.new()
	s.width = width
	s.height = height
	s.shafts = shafts
	s.warp_colors = warp_colors.duplicate()
	s.weft_colors = weft_colors.duplicate()
	s.threading = threading.duplicate()
	s.lifts = lifts.duplicate()
	s.target = target.duplicate()
	s.given_threading = given_threading
	s.given_lifts = given_lifts
	return s


## Where a warp's shaft is lifted, the warp shows; otherwise the weft does.
func warp_on_top(c: int, r: int) -> bool:
	var s := threading[c]
	return s >= 0 and ((lifts[r] >> s) & 1) == 1


func cell_color(c: int, r: int) -> int:
	return warp_colors[c] if warp_on_top(c, r) else weft_colors[r]


func target_color(c: int, r: int) -> int:
	return target[r * width + c]


func cell_matches(c: int, r: int) -> bool:
	return cell_color(c, r) == target[r * width + c]


func row_matches(r: int) -> bool:
	for c in width:
		if not cell_matches(c, r):
			return false
	return true


func matches_target() -> bool:
	for r in height:
		if not row_matches(r):
			return false
	return true


func is_lifted(r: int, shaft: int) -> bool:
	return ((lifts[r] >> shaft) & 1) == 1


func all_shafts_mask() -> int:
	return (1 << shafts) - 1


func set_row_lifts(r: int, mask: int) -> void:
	mask &= all_shafts_mask()
	var old := lifts[r]
	if old == mask:
		return
	lifts[r] = mask
	row_changed.emit(r, old)


func toggle_lift(r: int, shaft: int) -> void:
	set_row_lifts(r, lifts[r] ^ (1 << shaft))


func set_threading(c: int, shaft: int) -> void:
	var old := threading[c]
	if old == shaft:
		return
	threading[c] = shaft
	column_changed.emit(c, old)


## Replaces the player-set parts with another state's (used by restart).
func load_setup(thr: PackedInt32Array, lft: PackedInt32Array) -> void:
	threading = thr.duplicate()
	lifts = lft.duplicate()
	reset.emit()


func columns_on_shaft(shaft: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in width:
		if threading[c] == shaft:
			out.append(c)
	return out


## Share of cells where warp and weft have the same colour, so either
## thread on top looks right.
func either_fraction() -> float:
	var n := 0
	for r in height:
		for c in width:
			if warp_colors[c] == weft_colors[r]:
				n += 1
	return float(n) / float(width * height)
