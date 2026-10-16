class_name LoomSolver
extends RefCounted
## Solving, hints and solution checks for all three puzzle modes.
##
## Each target cell is marked "must show warp", "must show weft" or "either"
## (warp and weft share a colour). Lifting and threading are solved row by row
## or column by column; the full loom backtracks over columns.

enum Mark { EITHER, WARP, WEFT, NONE }

## Lift state of one (row, shaft) pair during the full-loom search.
const _FREE := 0
const _ON := 1
const _OFF := 2


static func marks(state: LoomState) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(state.width * state.height)
	for r in state.height:
		for c in state.width:
			var t := state.target[r * state.width + c]
			var wa := state.warp_colors[c] == t
			var we := state.weft_colors[r] == t
			var m := Mark.NONE
			if wa and we:
				m = Mark.EITHER
			elif wa:
				m = Mark.WARP
			elif we:
				m = Mark.WEFT
			out[r * state.width + c] = m
	return out


## Lifts that weave the target with the given threading, keeping the bits of
## `prefer` wherever a shaft is free. Returns an empty array on a conflict.
static func solve_lifts(state: LoomState, thr: PackedInt32Array,
		prefer: PackedInt32Array, mk := PackedInt32Array()) -> PackedInt32Array:
	if mk.is_empty():
		mk = marks(state)
	var out := PackedInt32Array()
	out.resize(state.height)
	var all := state.all_shafts_mask()
	for r in state.height:
		var must_on := 0
		var must_off := 0
		for c in state.width:
			var m := mk[r * state.width + c]
			if m == Mark.NONE:
				return PackedInt32Array()
			var s := thr[c]
			if s < 0:
				if m == Mark.WARP:
					return PackedInt32Array()
				continue
			if m == Mark.WARP:
				must_on |= 1 << s
			elif m == Mark.WEFT:
				must_off |= 1 << s
		if must_on & must_off:
			return PackedInt32Array()
		out[r] = ((prefer[r] & ~must_off) | must_on) & all
	return out


## Shafts each warp may sit on to weave the target with the given lifts.
## Returns an empty array when a column fits no shaft.
static func solve_threading(state: LoomState, lft: PackedInt32Array,
		prefer: PackedInt32Array, mk := PackedInt32Array()) -> PackedInt32Array:
	if mk.is_empty():
		mk = marks(state)
	var out := PackedInt32Array()
	out.resize(state.width)
	for c in state.width:
		var options := column_options(state, c, lft, mk)
		if options.is_empty():
			return PackedInt32Array()
		out[c] = prefer[c] if options.has(prefer[c]) else options[0]
	return out


## Shafts (real ones first, UNTIED last) column `c` may use with these lifts.
static func column_options(state: LoomState, c: int, lft: PackedInt32Array,
		mk: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var candidates: Array[int] = []
	candidates.assign(range(state.shafts))
	candidates.append(LoomState.UNTIED)
	for s in candidates:
		var ok := true
		for r in state.height:
			var m := mk[r * state.width + c]
			var lifted := s >= 0 and ((lft[r] >> s) & 1) == 1
			if m == Mark.NONE or (m == Mark.WARP and not lifted) \
					or (m == Mark.WEFT and lifted):
				ok = false
				break
		if ok:
			out.append(s)
	return out


## Backtracking search for a threading and lifts that weave the target with
## `shafts` shafts. Tries the shafts in `prefer_thr` first so the answer stays
## close to the player's setup. Returns {} when there is none.
static func solve_full(state: LoomState, prefer_thr: PackedInt32Array,
		prefer_lifts: PackedInt32Array, shafts := -1,
		mk := PackedInt32Array()) -> Dictionary:
	if shafts < 0:
		shafts = state.shafts
	if mk.is_empty():
		mk = marks(state)
	for m in mk:
		if m == Mark.NONE:
			return {}
	var lift_state := PackedInt32Array()
	lift_state.resize(state.height * LoomState.MAX_SHAFTS)
	lift_state.fill(_FREE)
	var thr := PackedInt32Array()
	thr.resize(state.width)
	thr.fill(LoomState.UNTIED)
	if not _search(state, mk, shafts, 0, thr, lift_state, prefer_thr):
		return {}
	var lft := PackedInt32Array()
	lft.resize(state.height)
	for r in state.height:
		var mask := 0
		for s in shafts:
			var v := lift_state[r * LoomState.MAX_SHAFTS + s]
			var bit := 1 << s
			if v == _ON or (v == _FREE and r < prefer_lifts.size() and prefer_lifts[r] & bit):
				mask |= bit
		lft[r] = mask
	return {"threading": thr, "lifts": lft}


static func _search(state: LoomState, mk: PackedInt32Array, shafts: int, c: int,
		thr: PackedInt32Array, lift_state: PackedInt32Array,
		prefer: PackedInt32Array) -> bool:
	if c == state.width:
		return true
	var order: Array[int] = []
	if c < prefer.size() and prefer[c] >= 0 and prefer[c] < shafts:
		order.append(prefer[c])
	for s in shafts:
		if not order.has(s):
			order.append(s)
	order.append(LoomState.UNTIED)
	for s in order:
		var changed: Array[int] = []
		var ok := true
		for r in state.height:
			var m := mk[r * state.width + c]
			if s < 0:
				if m == Mark.WARP:
					ok = false
					break
				continue
			if m == Mark.EITHER:
				continue
			var i := r * LoomState.MAX_SHAFTS + s
			var want := _ON if m == Mark.WARP else _OFF
			if lift_state[i] == _FREE:
				lift_state[i] = want
				changed.append(i)
			elif lift_state[i] != want:
				ok = false
				break
		if ok:
			thr[c] = s
			if _search(state, mk, shafts, c + 1, thr, lift_state, prefer):
				return true
		for i in changed:
			lift_state[i] = _FREE
	thr[c] = LoomState.UNTIED
	return false


## Any setup that weaves the target, respecting the parts the level gives.
## Returns {"threading", "lifts"} or {} when unsolvable.
static func find_solution(state: LoomState) -> Dictionary:
	var mk := marks(state)
	if state.given_threading:
		var lft := solve_lifts(state, state.threading, state.lifts, mk)
		return {} if lft.is_empty() else {"threading": state.threading.duplicate(), "lifts": lft}
	if state.given_lifts:
		var thr := solve_threading(state, state.lifts, state.threading, mk)
		return {} if thr.is_empty() else {"threading": thr, "lifts": state.lifts.duplicate()}
	return solve_full(state, state.threading, state.lifts, -1, mk)


static func is_solvable(state: LoomState) -> bool:
	return not find_solution(state).is_empty()


## The next correction: sets one row's lifts or one warp's shaft.
## Returns {"kind": "row", "row", "lifts"}, {"kind": "warp", "col", "shaft"}
## or {} when the cloth already matches (or the level cannot be solved).
static func hint(state: LoomState) -> Dictionary:
	if state.matches_target():
		return {}
	var mk := marks(state)
	if not state.given_lifts:
		# Keep the player's threading if it can still work; fix a row.
		var lft := solve_lifts(state, state.threading, state.lifts, mk)
		if not lft.is_empty():
			return _first_row_diff(state, lft)
		if state.given_threading:
			return {}
	# Keep the player's lifts if they can still work; fix a warp.
	var thr := solve_threading(state, state.lifts, state.threading, mk)
	if not thr.is_empty():
		var h := _first_warp_diff(state, thr)
		if not h.is_empty() or state.given_lifts:
			return h
	if state.given_lifts:
		return {}
	# Full loom with a dead-end setup: move the first warp that differs from
	# the solution nearest the player's threading.
	var sol := solve_full(state, state.threading, state.lifts, -1, mk)
	if sol.is_empty():
		return {}
	var fix := _first_warp_diff(state, sol.threading)
	return fix if not fix.is_empty() else _first_row_diff(state, sol.lifts)


static func _first_row_diff(state: LoomState, lft: PackedInt32Array) -> Dictionary:
	for r in state.height:
		if lft[r] != state.lifts[r]:
			return {"kind": "row", "row": r, "lifts": lft[r]}
	return {}


static func _first_warp_diff(state: LoomState, thr: PackedInt32Array) -> Dictionary:
	for c in state.width:
		if thr[c] != state.threading[c]:
			return {"kind": "warp", "col": c, "shaft": thr[c]}
	return {}


## One single tap or drag towards a solution, for the tutorial pointer.
## Returns {"kind": "lift", "row", "shaft"}, {"kind": "thread", "col", "shaft"}
## or {}.
static func next_move(state: LoomState) -> Dictionary:
	var h := hint(state)
	if h.is_empty():
		return h
	if h.kind == "warp":
		return {"kind": "thread", "col": h.col, "shaft": h.shaft}
	var diff: int = state.lifts[h.row] ^ int(h.lifts)
	for s in state.shafts:
		if diff & (1 << s):
			return {"kind": "lift", "row": h.row, "shaft": s}
	return {}
