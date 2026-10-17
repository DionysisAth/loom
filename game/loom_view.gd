class_name LoomView
extends Control
## Draws the woven cloth and animates flips. A flip squashes the top thread
## and swaps it in FLIP seconds, staggered STAGGER seconds along the line, so a
## row ripples like a real shed opening.
##
## The cloth is also a control: press a crossing and every crossing on the
## same shaft in that row lights up; release to flip them all (the same move
## as that row's switch). Slide off the row to cancel. On threading levels a
## tap moves the column's warp to the next shaft.

## Release on a crossing whose shaft is tied: flip that shaft in the row.
signal lift_requested(row: int, shaft: int)
## Release on a column in a threading level: move its warp to the next shaft.
signal cycle_requested(col: int)
## Tap on a loose (untied) warp where a lift was wanted.
signal untied_tapped(col: int)

const FLIP := 0.1
const STAGGER := 0.025
const FLASH := 0.9

var state: LoomState
var palette := PackedColorArray()
var colorblind := false
var show_mismatch := true
## While true the target is shown over the cloth (hold-to-compare).
var compare := false:
	set(v):
		compare = v
		queue_redraw()
var cell := 48.0

## Per cell: what is shown once animations finish, what was shown before,
## and when the current flip starts (in _clock seconds).
var _final := PackedByteArray()
var _from := PackedByteArray()
var _start := PackedFloat32Array()
var _clock := 0.0
var _busy_until := 0.0
var _flash_row := -1
var _flash_col := -1
var _flash_t := -10.0
## The pressed crossing and the cells that will flip on release.
var _press := Vector2i(-1, -1)
var _preview: Array[Vector2i] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(s: LoomState, pal: PackedColorArray) -> void:
	state = s
	palette = pal
	var n := s.width * s.height
	_final.resize(n)
	_from.resize(n)
	_start.resize(n)
	for r in s.height:
		for c in s.width:
			var i := r * s.width + c
			_final[i] = 1 if s.warp_on_top(c, r) else 0
			_from[i] = _final[i]
			_start[i] = -10.0
	s.row_changed.connect(func(r, _old): _refresh_line(r, true))
	s.column_changed.connect(func(c, _old): _refresh_line(c, false))
	s.reset.connect(_refresh_all)
	queue_redraw()


func cloth_size() -> Vector2:
	return Vector2(state.width, state.height) * cell


func cell_rect(c: int, r: int) -> Rect2:
	return Rect2(Vector2(c, r) * cell, Vector2(cell, cell))


func _refresh_line(index: int, is_row: bool) -> void:
	var n := state.width if is_row else state.height
	var k := 0
	for j in n:
		var c := j if is_row else index
		var r := index if is_row else j
		if _retarget(c, r, _clock + k * STAGGER):
			k += 1
	_wake(0.6)


func _refresh_all() -> void:
	for r in state.height:
		for c in state.width:
			_retarget(c, r, _clock + (r + c) * STAGGER * 0.6)
	_wake(0.6)


func _retarget(c: int, r: int, at: float) -> bool:
	var i := r * state.width + c
	var now := 1 if state.warp_on_top(c, r) else 0
	if now == _final[i]:
		return false
	_from[i] = _visible(i)
	_final[i] = now
	_start[i] = at
	_busy_until = maxf(_busy_until, at + FLIP)
	set_process(true)
	return true


func _wake(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _clock + seconds)
	set_process(true)


## What the cell currently shows (mid-flip it is the old side, then the new).
func _visible(i: int) -> int:
	var t := (_clock - _start[i]) / FLIP
	return _from[i] if t < 0.5 else _final[i]


func flash_row(r: int) -> void:
	_flash_row = r
	_flash_col = -1
	_flash_t = _clock
	_wake(FLASH)


func flash_column(c: int) -> void:
	_flash_col = c
	_flash_row = -1
	_flash_t = _clock
	_wake(FLASH)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _clock > _busy_until + 0.05:
		set_process(false)


func _shown(c: int, r: int) -> bool:
	return _visible(r * state.width + c) == 1


# --- Input -------------------------------------------------------------------

func _cell_at(pos: Vector2) -> Vector2i:
	var c := int(floorf(pos.x / cell))
	var r := int(floorf(pos.y / cell))
	if c < 0 or r < 0 or c >= state.width or r >= state.height:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


## Cells that a press on (c, r) would change.
func affected(c: int, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not state.given_lifts:
		var s := state.threading[c]
		if s < 0:
			return out
		for cc in state.width:
			if state.threading[cc] == s:
				out.append(Vector2i(cc, r))
	elif not state.given_threading:
		for rr in state.height:
			out.append(Vector2i(c, rr))
	return out


func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var at := _cell_at(event.position)
			if at.x < 0:
				return
			accept_event()
			if not state.given_lifts and state.threading[at.x] < 0:
				untied_tapped.emit(at.x)
				return
			_press = at
			_preview = affected(at.x, at.y)
			queue_redraw()
		elif _press.x >= 0:
			accept_event()
			var at := _cell_at(event.position)
			var p := _press
			_cancel()
			if at.x < 0:
				return
			if not state.given_lifts:
				if at.y == p.y and state.threading[at.x] == state.threading[p.x]:
					lift_requested.emit(p.y, state.threading[p.x])
			elif at.x == p.x:
				cycle_requested.emit(p.x)
	elif event is InputEventMouseMotion and _press.x >= 0:
		var at := _cell_at(event.position)
		var still := at.x >= 0 and (at.y == _press.y if not state.given_lifts else at.x == _press.x)
		if not still:
			_cancel()


func _cancel() -> void:
	_press = Vector2i(-1, -1)
	_preview.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _press.x >= 0:
		_cancel()


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, cloth_size()), ThreadTextures.GAP_COLOR)
	for r in state.height:
		for c in state.width:
			var i := r * state.width + c
			var t := clampf((_clock - _start[i]) / FLIP, 0.0, 1.0)
			var squash := 1.0
			if t > 0.0 and t < 1.0:
				squash = maxf(0.08, absf(1.0 - 2.0 * t))
			var top := _shown(c, r)
			var a: bool
			var b: bool
			if top:
				a = r > 0 and not _shown(c, r - 1)
				b = r < state.height - 1 and not _shown(c, r + 1)
			else:
				a = c > 0 and _shown(c - 1, r)
				b = c < state.width - 1 and _shown(c + 1, r)
			var wid := state.warp_colors[c]
			var fid := state.weft_colors[r]
			ThreadTextures.draw_crossing(self, cell_rect(c, r), top, palette[wid], palette[fid],
					squash, colorblind, wid, fid, a, b)
	var ft := (_clock - _flash_t) / FLASH
	if ft >= 0.0 and ft < 1.0:
		var glow := Color(1, 0.97, 0.75, 0.6 * (1.0 - ft))
		if _flash_row >= 0:
			draw_rect(Rect2(0, _flash_row * cell, state.width * cell, cell), glow)
		elif _flash_col >= 0:
			draw_rect(Rect2(_flash_col * cell, 0, cell, state.height * cell), glow)
	if compare:
		_draw_compare()
		return
	if show_mismatch:
		_draw_mismatches()
	_draw_preview()


## Small dots on crossings that do not match the target yet.
func _draw_mismatches() -> void:
	for r in state.height:
		for c in state.width:
			var i := r * state.width + c
			if _clock - _start[i] < FLIP:
				continue
			var shown := state.warp_colors[c] if _shown(c, r) else state.weft_colors[r]
			if shown == state.target[i]:
				continue
			var center := cell_rect(c, r).get_center()
			var rad := maxf(4.0, cell * 0.12)
			draw_circle(center + Vector2(0, 1.5), rad + 2.5, Color(0.25, 0.05, 0.2, 0.25), true, -1.0, true)
			draw_circle(center, rad + 2.5, Color.WHITE, true, -1.0, true)
			draw_circle(center, rad, palette[state.target[i]], true, -1.0, true)


## Outline every crossing the current press would flip.
func _draw_preview() -> void:
	if _preview.is_empty():
		return
	for p in _preview:
		var r := cell_rect(p.x, p.y).grow(-cell * 0.04)
		draw_rect(r, Color(1, 1, 1, 0.28))
		draw_rect(r, Color.WHITE, false, maxf(3.0, cell * 0.07), true)
	var pr := cell_rect(_press.x, _press.y).grow(-cell * 0.04)
	draw_rect(pr, LoomTheme.GOLD, false, maxf(4.0, cell * 0.09), true)


## The target laid over the cloth while the player holds the target swatch.
func _draw_compare() -> void:
	for r in state.height:
		for c in state.width:
			var i := r * state.width + c
			var rect := cell_rect(c, r).grow(-cell * 0.05)
			var col := palette[state.target[i]]
			draw_rect(rect, Color(col, 0.92))
			if colorblind:
				ThreadTextures.draw_pattern(self, rect, state.target[i], col, true, 1.0)
			var shown := state.warp_colors[c] if state.warp_on_top(c, r) else state.weft_colors[r]
			if shown != state.target[i]:
				draw_rect(rect.grow(-cell * 0.06), Color.WHITE, false, maxf(2.0, cell * 0.06), true)
