extends Node
## Loads every world's level JSON, hands the current level to the game scene
## and knows what comes next.

const WORLD_FILES := [
	"res://levels/world_1.json",
	"res://levels/world_2.json",
	"res://levels/world_3.json",
]
const GAME_SCENE := "res://game/game.tscn"

var worlds: Array[Dictionary] = []
## Every level in play order.
var all: Array[Dictionary] = []
var current := 0


func _ready() -> void:
	for path in WORLD_FILES:
		var world := LevelLoader.load_world(path)
		if world.is_empty():
			continue
		world.first = all.size()
		worlds.append(world)
		for i in world.levels.size():
			var level: Dictionary = world.levels[i]
			level.index = all.size()
			level.number = all.size() + 1
			level.world_index = worlds.size() - 1
			all.append(level)


func count() -> int:
	return all.size()


func level(i: int) -> Dictionary:
	return all[i]


func current_level() -> Dictionary:
	return all[current]


func world_of(i: int) -> Dictionary:
	return worlds[all[i].world_index]


func palette(i: int) -> PackedColorArray:
	var out := PackedColorArray()
	for hex in world_of(i).palette:
		out.append(Color.html(hex))
	return out


func next_index(i: int) -> int:
	return i + 1 if i + 1 < all.size() else -1


func is_unlocked(i: int) -> bool:
	return i == 0 or Save.is_completed(all[i - 1].id) or Save.is_completed(all[i].id)


## The level the Play button continues from.
func first_unsolved() -> int:
	for i in all.size():
		if not Save.is_completed(all[i].id):
			return i
	return all.size() - 1


func play(i: int) -> void:
	current = clampi(i, 0, all.size() - 1)
	get_tree().change_scene_to_file(GAME_SCENE)
