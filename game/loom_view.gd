class_name LoomView
extends Control
## Draws the woven cloth and animates flips. A flip squashes the top thread
## and swaps it in FLIP seconds, staggered STAGGER seconds along the line, so a
## row ripples like a real shed opening.

const FLIP := 0.1
const STAGGER := 0.025
const FLASH := 0.9

var state: LoomState
var palette := PackedColorArray()
var colorblind := false
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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _refresh_line(index: int, is_row: bool) -> void:
	var n := state.width if is_row else state.height
	var k := 0
	for j in n:
		var c := j if is_row else index
		var r := index if is_row else j
		if _retarget(c, r, _clock + k * STAGGER):
			k += 1


func _refresh_all() -> void:
	for r in state.height:
		for c in state.width:
			_retarget(c, r, _clock + (r + c) * STAGGER * 0.6)


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


## What the cell currently shows (mid-flip it is the old side, then the new).
func _visible(i: int) -> int:
	var t := (_clock - _start[i]) / FLIP
	return _from[i] if t < 0.5 else _final[i]


func flash_row(r: int) -> void:
	_flash_row = r
	_flash_col = -1
	_flash_t = _clock
	_busy_until = maxf(_busy_until, _clock + FLASH)
	set_process(true)


func flash_column(c: int) -> void:
	_flash_col = c
	_flash_row = -1
	_flash_t = _clock
	_busy_until = maxf(_busy_until, _clock + FLASH)
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _clock > _busy_until + 0.05:
		set_process(false)


func _shown(c: int, r: int) -> bool:
	return _visible(r * state.width + c) == 1


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
			ThreadTextures.draw_crossing(self, Rect2(Vector2(c, r) * cell, Vector2(cell, cell)),
					top, palette[wid], palette[fid], squash, colorblind, wid, fid, a, b)
	var ft := (_clock - _flash_t) / FLASH
	if ft >= 0.0 and ft < 1.0:
		var glow := Color(1, 0.95, 0.7, 0.55 * (1.0 - ft))
		if _flash_row >= 0:
			draw_rect(Rect2(0, _flash_row * cell, state.width * cell, cell), glow)
		elif _flash_col >= 0:
			draw_rect(Rect2(_flash_col * cell, 0, cell, state.height * cell), glow)
