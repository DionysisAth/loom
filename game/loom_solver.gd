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
	if state.has_treadles():
		return solve_treadles(state, state.treadling, state.tieup, -1, mk)
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
	if state.has_treadles():
		return _treadle_hint(state, mk)
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
	match h.kind:
		"warp":
			return {"kind": "thread", "col": h.col, "shaft": h.shaft}
		"peg":
			return {"kind": "peg", "row": h.row, "treadle": h.treadle}
		"tieup":
			var rows := state.rows_on_treadle(h.treadle)
			var diff: int = state.tieup[h.treadle] ^ int(h.lifts)
			for s in state.shafts:
				if diff & (1 << s):
					return {"kind": "lift", "row": rows[0] if not rows.is_empty() else 0, "shaft": s}
			return {}
	var diff: int = state.lifts[h.row] ^ int(h.lifts)
	for s in state.shafts:
		if diff & (1 << s):
			return {"kind": "lift", "row": h.row, "shaft": s}
	return {}


# --- Treadles ---------------------------------------------------------------

## What each row needs with the given threading: [must_on, must_off] masks per
## row, or an empty array if some row cannot be woven at all.
static func row_needs(state: LoomState, thr: PackedInt32Array, mk: PackedInt32Array) -> Array:
	var out := []
	for r in state.height:
		var on := 0
		var off := 0
		for c in state.width:
			var m := mk[r * state.width + c]
			if m == Mark.NONE:
				return []
			var sh := thr[c]
			if sh < 0:
				if m == Mark.WARP:
					return []
				continue
			if m == Mark.WARP:
				on |= 1 << sh
			elif m == Mark.WEFT:
				off |= 1 << sh
		if on & off:
			return []
		out.append([on, off])
	return out


## Pegs rows onto at most `treadles` treadles so rows sharing a treadle need
## compatible lifts, preferring the player's current pegs. Returns
## {"treadling", "tieup", "lifts"} or {}.
static func solve_treadles(state: LoomState, prefer_treadling: PackedInt32Array,
		prefer_tieup: PackedInt32Array, treadles := -1, mk := PackedInt32Array()) -> Dictionary:
	if treadles < 0:
		treadles = state.treadle_count
	if mk.is_empty():
		mk = marks(state)
	var needs := row_needs(state, state.threading, mk)
	if needs.is_empty():
		return {}
	var on := PackedInt32Array()
	var off := PackedInt32Array()
	on.resize(treadles)
	off.resize(treadles)
	var assign := PackedInt32Array()
	assign.resize(state.height)
	if not _peg(needs, 0, treadles, assign, on, off, prefer_treadling):
		return {}
	var tie := PackedInt32Array()
	tie.resize(treadles)
	for t in treadles:
		var keep := prefer_tieup[t] if t < prefer_tieup.size() else 0
		tie[t] = (on[t] | (keep & ~off[t])) & state.all_shafts_mask()
	var lft := PackedInt32Array()
	lft.resize(state.height)
	for r in state.height:
		lft[r] = tie[assign[r]]
	return {"treadling": assign, "tieup": tie, "lifts": lft, "threading": state.threading.duplicate()}


static func _peg(needs: Array, r: int, treadles: int, assign: PackedInt32Array,
		on: PackedInt32Array, off: PackedInt32Array, prefer: PackedInt32Array) -> bool:
	if r == needs.size():
		return true
	var order: Array[int] = []
	if r < prefer.size() and prefer[r] >= 0 and prefer[r] < treadles:
		order.append(prefer[r])
	for t in treadles:
		if not order.has(t):
			order.append(t)
	var n_on: int = needs[r][0]
	var n_off: int = needs[r][1]
	for t in order:
		if (on[t] | n_on) & (off[t] | n_off):
			continue
		var save_on := on[t]
		var save_off := off[t]
		on[t] |= n_on
		off[t] |= n_off
		assign[r] = t
		if _peg(needs, r + 1, treadles, assign, on, off, prefer):
			return true
		on[t] = save_on
		off[t] = save_off
	return false


static func _treadle_hint(state: LoomState, mk: PackedInt32Array) -> Dictionary:
	var sol := solve_treadles(state, state.treadling, state.tieup, -1, mk)
	if sol.is_empty():
		return {}
	for r in state.height:
		if sol.treadling[r] != state.treadling[r]:
			return {"kind": "peg", "row": r, "treadle": sol.treadling[r]}
	for t in state.treadle_count:
		if sol.tieup[t] != state.tieup[t]:
			return {"kind": "tieup", "treadle": t, "lifts": sol.tieup[t]}
	return {}


# --- Par ----------------------------------------------------------------------

## The fewest taps a level should take from its start: lifts to switch on,
## warps to tie and pegs to move (a peg tap moves a row to the next treadle).
static func par(level: Dictionary) -> int:
	var state := LoomState.from_level(level)
	var mk := marks(state)
	var sol: Dictionary = level.solution
	if state.has_treadles():
		var needs := row_needs(state, state.threading, mk)
		var best := 1 << 30
		var t_count := state.treadle_count
		for perm in _permutations(t_count):
			var cost := 0
			var tie := PackedInt32Array()
			tie.resize(t_count)
			for r in state.height:
				var t: int = perm[sol.treadling[r]]
				cost += posmod(t - state.treadling[r], t_count)
				tie[t] |= needs[r][0]
			for t in t_count:
				cost += _bits(tie[t] ^ state.tieup[t])
			best = mini(best, cost)
		return best
	var cost := 0
	if not state.given_threading:
		for c in state.width:
			if sol.threading[c] != state.threading[c]:
				cost += 1
	if not state.given_lifts:
		var needs := row_needs(state, PackedInt32Array(sol.threading), mk)
		for r in state.height:
			if needs.is_empty():
				cost += _bits(sol.lifts[r] ^ state.lifts[r])
				continue
			# Shafts that must go up and are down, plus ones that must go down and are up.
			var on: int = needs[r][0]
			var off: int = needs[r][1]
			cost += _bits(on & ~state.lifts[r]) + _bits(off & state.lifts[r])
	return cost


static func _bits(x: int) -> int:
	var n := 0
	while x:
		n += x & 1
		x >>= 1
	return n


static func _permutations(n: int) -> Array:
	if n <= 1:
		return [[0]]
	var out := []
	for p in _permutations(n - 1):
		for i in n:
			var q: Array = p.duplicate()
			q.insert(i, n - 1)
			out.append(q)
	return out
