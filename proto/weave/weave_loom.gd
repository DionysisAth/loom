class_name WeaveLoom
extends RefCounted
## Prototype A: weave the cloth row by row like a real loom.
##
## Each warp is tied to a shaft (threading). Each pedal lifts some shafts
## (its tie-up). Pressing a pedal opens a shed: the lifted warps rise, and the
## shuttle passes under them and over the rest, so a woven row shows the warp
## where its shaft was lifted. The cloth grows one row at a time, bottom up.

signal changed

var width := 0
var shafts := 2
var threading := PackedInt32Array()
var warp_colors := PackedInt32Array()
## Weft colour per row, in weaving order (row 0 is woven first, at the bottom).
var weft_colors := PackedInt32Array()
## Lift mask per pedal.
var pedals := PackedInt32Array()
## Whether the player ties the pedals (taps shaft knobs) or they come tied.
var editable := false
## Target: lift mask per row, from the level's solution.
var target_lifts := PackedInt32Array()
## Lift mask used for each row woven so far.
var woven := PackedInt32Array()
var mistakes_made := 0


static func from_level(lv: Dictionary) -> WeaveLoom:
	var l := WeaveLoom.new()
	l.width = lv.threading.size()
	l.shafts = lv.shafts
	l.threading = PackedInt32Array(lv.threading)
	l.warp_colors = PackedInt32Array(lv.warp)
	l.weft_colors = PackedInt32Array(lv.weft)
	l.editable = lv.get("editable", false)
	var sol: Dictionary = lv.solution
	for p in sol.sequence:
		l.target_lifts.append(sol.tieup[p])
	if l.editable:
		l.pedals.resize(sol.tieup.size())
		l.pedals.fill(0)
	else:
		l.pedals = PackedInt32Array(lv.get("pedals", sol.tieup))
	return l


func height() -> int:
	return weft_colors.size()


func lifted(c: int, mask: int) -> bool:
	return ((mask >> threading[c]) & 1) == 1


## The colour id a crossing shows for a given lift mask.
func color_for(c: int, r: int, mask: int) -> int:
	return warp_colors[c] if lifted(c, mask) else weft_colors[r]


func target_color(c: int, r: int) -> int:
	return color_for(c, r, target_lifts[r])


func woven_color(c: int, r: int) -> int:
	return color_for(c, r, woven[r])


func cell_correct(c: int, r: int) -> bool:
	return woven_color(c, r) == target_color(c, r)


func row_correct(r: int) -> bool:
	for c in width:
		if not cell_correct(c, r):
			return false
	return true


## Weaves the next row with a pedal. Returns whether the row is right.
func weave(pedal: int) -> bool:
	if woven.size() >= height():
		return false
	woven.append(pedals[pedal])
	var ok := row_correct(woven.size() - 1)
	if not ok:
		mistakes_made += 1
	changed.emit()
	return ok


## Pulls the last row back out.
func unpick() -> bool:
	if woven.is_empty():
		return false
	woven.resize(woven.size() - 1)
	changed.emit()
	return true


func restart() -> void:
	woven.resize(0)
	if editable:
		pedals.fill(0)
	changed.emit()


func toggle_tie(pedal: int, shaft: int) -> void:
	pedals[pedal] ^= 1 << shaft
	changed.emit()


func next_row() -> int:
	return woven.size()


func complete() -> bool:
	if woven.size() != height():
		return false
	for r in height():
		if not row_correct(r):
			return false
	return true


## The pedal that weaves the next row right, or -1 if none does.
func right_pedal() -> int:
	var r := next_row()
	if r >= height():
		return -1
	for p in pedals.size():
		var ok := true
		for c in width:
			if color_for(c, r, pedals[p]) != target_color(c, r):
				ok = false
				break
		if ok:
			return p
	return -1
