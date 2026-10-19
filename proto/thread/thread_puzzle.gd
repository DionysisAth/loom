class_name ThreadPuzzle
extends RefCounted
## Prototype B: lay threads through a frame to weave a picture.
##
## Each colour has two knots. Drag from a knot to lay that thread cell by cell
## to its other knot. A cell holds one thread, except at crossings, where a
## horizontal and a vertical thread pass straight through each other, one
## over and one under (the weave decides which). The level is woven when every
## thread reaches its other knot and every cell is filled.

signal changed

var width := 0
var height := 0
## [{"color": int, "a": Vector2i, "b": Vector2i}]
var pegs: Array[Dictionary] = []
var crossings := {}
## Colour id -> cells of that thread, starting at one of its knots.
var paths := {}


static func from_level(lv: Dictionary) -> ThreadPuzzle:
	var p := ThreadPuzzle.new()
	p.width = lv.size[0]
	p.height = lv.size[1]
	for k in lv.knots:
		p.pegs.append({"color": int(k[0]), "a": Vector2i(k[1][0], k[1][1]), "b": Vector2i(k[2][0], k[2][1])})
	for x in lv.get("crossings", []):
		p.crossings[Vector2i(x[0], x[1])] = true
	return p


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func peg_color(cell: Vector2i) -> int:
	for p in pegs:
		if p.a == cell or p.b == cell:
			return p.color
	return -1


func other_end(color: int, cell: Vector2i) -> Vector2i:
	for p in pegs:
		if p.color == color:
			return p.b if p.a == cell else p.a
	return Vector2i(-1, -1)


func is_crossing(cell: Vector2i) -> bool:
	return crossings.has(cell)


func path(color: int) -> Array:
	return paths.get(color, [])


## Colours whose thread passes through a cell.
func occupants(cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for color in paths:
		if paths[color].has(cell):
			out.append(color)
	return out


func connected(color: int) -> bool:
	var p := path(color)
	return p.size() >= 2 and p[-1] == other_end(color, p[0])


## The axis (true = horizontal) a thread uses through a cell, or null if it
## only ends there or turns.
func axis_through(color: int, cell: Vector2i) -> Variant:
	var p := path(color)
	var i := p.find(cell)
	if i < 0:
		return null
	var dirs: Array[Vector2i] = []
	if i > 0:
		dirs.append(cell - p[i - 1])
	if i < p.size() - 1:
		dirs.append(p[i + 1] - cell)
	if dirs.is_empty():
		return null
	var horiz := dirs[0].y == 0
	for d in dirs:
		if (d.y == 0) != horiz:
			return null
	return horiz


## Starts drawing at a cell: a knot restarts its thread; a cell on a thread
## cuts the thread back to there. Returns the colour, or -1.
func begin(cell: Vector2i) -> int:
	var pc := peg_color(cell)
	if pc >= 0:
		paths[pc] = [cell]
		changed.emit()
		return pc
	var occ := occupants(cell)
	if occ.is_empty():
		return -1
	var color := occ[-1]
	var p: Array = paths[color]
	paths[color] = p.slice(0, p.find(cell) + 1)
	changed.emit()
	return color


## Extends a thread into a neighbouring cell (or backs it up). Returns true if
## the thread changed.
func extend(color: int, cell: Vector2i) -> bool:
	if not inside(cell) or not paths.has(color):
		return false
	var p: Array = paths[color]
	var last: Vector2i = p[-1]
	if cell == last:
		return false
	if absi(cell.x - last.x) + absi(cell.y - last.y) != 1:
		return false
	# Backing up or looping onto itself cuts the thread there.
	var at := p.find(cell)
	if at >= 0:
		paths[color] = p.slice(0, at + 1)
		changed.emit()
		return true
	if connected(color):
		return false
	var dir := cell - last
	# Through a crossing a thread must go straight.
	if is_crossing(last) and p.size() >= 2 and last - p[-2] != dir:
		return false
	var pc := peg_color(cell)
	if pc >= 0 and pc != color:
		return false
	if pc == color and cell != other_end(color, p[0]):
		return false
	for other in occupants(cell):
		if other == color:
			continue
		if is_crossing(cell) and occupants(cell).size() == 1:
			var axis = axis_through(other, cell)
			var through: Array = paths[other]
			var ends_here: bool = through[-1] == cell
			if ends_here and through.size() >= 2:
				axis = (cell - through[-2]).y == 0
			if axis != null and axis != (dir.y == 0):
				continue
		# Drawing over another thread pulls that thread back.
		var op: Array = paths[other]
		paths[other] = op.slice(0, op.find(cell))
		if (paths[other] as Array).is_empty():
			paths.erase(other)
	p.append(cell)
	paths[color] = p
	changed.emit()
	return true


func filled() -> int:
	var seen := {}
	for color in paths:
		for c in paths[color]:
			seen[c] = true
	return seen.size()


func complete() -> bool:
	for pg in pegs:
		if not connected(pg.color):
			return false
	return filled() == width * height


## At a crossing the horizontal thread is on top on even cells.
func horizontal_on_top(cell: Vector2i) -> bool:
	return (cell.x + cell.y) % 2 == 0


func clear() -> void:
	paths.clear()
	changed.emit()
