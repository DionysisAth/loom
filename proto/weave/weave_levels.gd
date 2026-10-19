class_name WeaveLevels
extends RefCounted
## Hand-made levels for prototype A. Colour ids index PALETTE.

const PALETTE := ["#f7f0e3", "#5b8def", "#ef6f6c", "#f2b84b", "#4fbf9a"]

const LEVELS := [
	{
		"name": "First Shed",
		"tutorial": "Press a pedal, then swipe the shuttle through",
		"shafts": 2,
		"threading": [0, 1, 0, 1, 0, 1],
		"warp": [1, 1, 1, 1, 1, 1],
		"weft": [0, 0, 0, 0, 0, 0],
		"solution": {"tieup": [1, 2], "sequence": [0, 1, 0, 1, 0, 1]},
	},
	{
		"name": "Twill",
		"tutorial": "Read the next row and pick the pedal that weaves it",
		"shafts": 3,
		"threading": [0, 1, 2, 0, 1, 2, 0],
		"warp": [2, 2, 2, 2, 2, 2, 2],
		"weft": [0, 0, 0, 0, 0, 0, 0],
		"pedals": [5, 3, 6],
		"solution": {"tieup": [3, 6, 5], "sequence": [0, 1, 2, 0, 1, 2, 0]},
	},
	{
		"name": "Tie Your Pedals",
		"tutorial": "Tap the A B C knobs to choose what each pedal lifts",
		"shafts": 3,
		"editable": true,
		"threading": [0, 1, 2, 2, 1, 0, 1],
		"warp": [4, 4, 4, 4, 4, 4, 4],
		"weft": [0, 3, 0, 0, 3, 0, 0, 3],
		"solution": {"tieup": [1, 6], "sequence": [0, 1, 0, 0, 1, 0, 0, 1]},
	},
]


static func palette() -> PackedColorArray:
	var out := PackedColorArray()
	for hex in PALETTE:
		out.append(Color.html(hex))
	return out
