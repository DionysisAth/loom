extends SceneTree
## Regenerates levels/world_*.json.
## Usage: godot --headless --path . --script res://tools/generate_levels.gd


func _initialize() -> void:
	var gen := LevelGenerator.new()
	var worlds := gen.generate()
	var failed := false
	for world in worlds:
		var path := "res://levels/world_%d.json" % world.world
		var lines := PackedStringArray()
		for level in world.levels:
			var errors := LevelGenerator.check(level)
			if not errors.is_empty():
				push_error("%s: %s" % [level.id, ", ".join(errors)])
				failed = true
			lines.append("    " + JSON.stringify(_ordered(level)))
		var text := "{\n  \"world\": %d,\n  \"name\": %s,\n  \"mode\": %s,\n  \"palette\": %s,\n  \"levels\": [\n%s\n  ]\n}\n" % [
			world.world, JSON.stringify(world.name), JSON.stringify(world.mode),
			JSON.stringify(world.palette), ",\n".join(lines)]
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("wrote %s (%d levels)" % [path, world.levels.size()])
		for level in world.levels:
			print("  %-5s %-10s %dx%d k%d %-9s %s" % [level.id, level.mode, level.warp.size(),
				level.weft.size(), level.shafts, level.kind, level.name])
	quit(1 if failed else 0)


## Stable key order so diffs stay readable.
func _ordered(level: Dictionary) -> Dictionary:
	var out := {}
	for key in ["id", "name", "kind", "mode", "shafts", "tutorial", "warp", "weft", "solution", "start"]:
		if level.has(key):
			out[key] = level[key]
	return out
