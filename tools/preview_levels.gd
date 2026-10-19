extends SceneTree
## Prints every level's target cloth as text, for reviewing generated levels.
## Usage: godot --headless --path . --script res://tools/preview_levels.gd [-- 2-5]

const GLYPHS := ".#ox+*"


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for path in ["res://levels/world_1.json", "res://levels/world_2.json", "res://levels/world_3.json"]:
		var world := LevelLoader.load_world(path)
		for level in world.levels:
			if not only.is_empty() and not only.has(level.id):
				continue
			var state := LoomState.from_level(level)
			print("%s %s  [%s, %d shafts, %d treadles, %s] either=%d%% score=%.1f par=%d" % [level.id,
				level.name, level.mode, level.shafts, level.treadles, level.kind,
				int(state.either_fraction() * 100), LevelGenerator.score(level), LoomSolver.par(level)])
			if level.treadles > 0:
				print("   treadling ", level.solution.treadling, " tieup ", level.solution.tieup)
			for r in state.height:
				var line := "   "
				for c in state.width:
					line += GLYPHS[state.target_color(c, r)] + " "
				print(line)
	quit()
