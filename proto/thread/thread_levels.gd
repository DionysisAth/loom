class_name ThreadLevels
extends RefCounted
## Hand-made levels for prototype B. Cells are [column, row]. Each level keeps
## one known solution (used by tests).

const PALETTE := ["#ef6f6c", "#5b8def", "#f2b84b", "#4fbf9a", "#9a7bd8"]

const LEVELS := [
	{
		"name": "First Thread",
		"tutorial": "Drag from a knot to its twin and fill the frame",
		"size": [4, 4],
		"knots": [[0, [0, 0], [0, 1]], [1, [0, 2], [0, 3]]],
		"solution": {
			0: [[0, 0], [1, 0], [2, 0], [3, 0], [3, 1], [2, 1], [1, 1], [0, 1]],
			1: [[0, 2], [1, 2], [2, 2], [3, 2], [3, 3], [2, 3], [1, 3], [0, 3]],
		},
	},
	{
		"name": "Over and Under",
		"tutorial": "At a crossing two threads can pass straight through each other",
		"size": [5, 5],
		"crossings": [[2, 2]],
		"knots": [[0, [0, 0], [4, 0]], [1, [1, 1], [2, 4]], [2, [1, 3], [1, 4]], [3, [3, 3], [3, 4]]],
		"solution": {
			0: [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [4, 1], [4, 0]],
			1: [[1, 1], [1, 0], [2, 0], [3, 0], [3, 1], [2, 1], [2, 2], [2, 3], [2, 4]],
			2: [[1, 3], [0, 3], [0, 4], [1, 4]],
			3: [[3, 3], [4, 3], [4, 4], [3, 4]],
		},
	},
	{
		"name": "Two Crossings",
		"tutorial": "",
		"size": [6, 6],
		"crossings": [[1, 1], [4, 4]],
		"knots": [[0, [0, 0], [5, 0]], [1, [4, 0], [2, 5]], [2, [1, 3], [5, 5]],
			[3, [2, 2], [3, 5]], [4, [2, 3], [3, 3]]],
		"solution": {
			0: [[0, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [5, 0]],
			1: [[4, 0], [3, 0], [2, 0], [1, 0], [1, 1], [1, 2], [0, 2], [0, 3], [0, 4], [0, 5], [1, 5], [2, 5]],
			2: [[1, 3], [1, 4], [2, 4], [3, 4], [4, 4], [5, 4], [5, 5]],
			3: [[2, 2], [3, 2], [4, 2], [5, 2], [5, 3], [4, 3], [4, 4], [4, 5], [3, 5]],
			4: [[2, 3], [3, 3]],
		},
	},
]


static func palette() -> PackedColorArray:
	var out := PackedColorArray()
	for hex in PALETTE:
		out.append(Color.html(hex))
	return out
