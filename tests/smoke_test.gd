extends SceneTree
## Drives the real scenes: every menu, taps on the loom through the input
## system, and plays levels of each mode to the win panel.
##
## godot --headless --path . --script res://tests/smoke_test.gd
## Add `-- --shots=<dir>` (with a display, not --headless) to save screenshots.

var _failures: Array[String] = []
var _shots_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	var save: Node = root.get_node("Save")
	save.path = "user://smoke_save.json"
	save.data = save._fresh()
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL ", msg)
	else:
		print("ok   ", msg)


func _frames(n := 3) -> void:
	for i in n:
		await process_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _goto(path: String) -> Node:
	change_scene_to_file(path)
	await _frames(4)
	return current_scene


func _shot(name: String) -> void:
	if _shots_dir.is_empty():
		return
	await _frames(2)
	var img := root.get_texture().get_image()
	if img:
		img.save_png(_shots_dir.path_join(name + ".png"))


## Window coordinates of a point inside a control.
func _screen(control: Control, local: Vector2) -> Vector2:
	return root.get_final_transform() * (control.get_global_transform_with_canvas() * local)


func _tap(control: Control, local: Vector2) -> void:
	var pos := _screen(control, local)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	root.push_input(down)
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up)


func _drag(control: Control, from: Vector2, to: Vector2) -> void:
	var a := _screen(control, from)
	var b := _screen(control, to)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	root.push_input(down)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = b
	move.relative = b - a
	root.push_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	root.push_input(up)


func _run() -> void:
	var levels: Node = root.get_node("Levels")
	var save: Node = root.get_node("Save")
	_check(levels.count() == 60, "60 levels loaded")

	var menu := await _goto("res://core/ui/main_menu.tscn")
	_check(menu != null and menu.name == "MainMenu", "main menu opens")
	await _shot("01_main_menu")

	# Level 1 by real taps: the tutorial points at row 0, shaft A.
	levels.current = 0
	var game := await _goto("res://game/game.tscn")
	_check(game != null and game.name == "Game", "game opens")
	await _frames(3)
	await _shot("02_tutorial")
	var board: LoomBoard = game.board
	_check(game.pointer.visible, "tutorial pointer shows")
	var sw := board.switches
	_tap(sw, sw.switch_rect(0, 1).get_center())
	await _frames(2)
	_check(game.state.lifts[0] == 2, "tap on switch B lifts shaft B")
	game._on_undo()
	_check(game.state.lifts[0] == 0, "undo lowers it")
	_tap(sw, sw.switch_rect(0, 0).get_center())
	await _frames(2)
	_check(game._won, "lifting shaft A wins level 1")
	_check(game.stars() == 2, "an undo gives 2 stars")
	await _seconds(1.2)
	_check(game.win_panel.visible, "win panel shows")
	await _shot("03_win")
	_check(save.stars("1-1") == 2, "win saved with 2 stars")

	# Level 5: drag the loose warp onto shaft B.
	levels.current = 4
	game = await _goto("res://game/game.tscn")
	await _frames(3)
	await _shot("04_drag_tutorial")
	var draft: ThreadingDraft = game.board.draft
	_drag(draft, draft.slot_rect(3, 0).get_center(), draft.slot_rect(3, 1).get_center())
	await _frames(2)
	_check(game.state.threading[3] == 1, "drag ties warp 4 onto shaft B")
	_check(game._won and game.stars() == 3, "level 5 won with 3 stars")

	# One level of each mode solved by hints, mid-way screenshots.
	for i in [12, 29, 49]:
		levels.current = i
		game = await _goto("res://game/game.tscn")
		await _frames(3)
		for k in 2:
			game._on_hint()
		await _seconds(0.4)
		await _shot("05_level_%d" % (i + 1))
		var guard := 0
		while not game._won and guard < 40:
			game._on_hint()
			guard += 1
		_check(game._won, "hints solve level %s" % game.level.id)
		_check(game.stars() == 1, "hinted win gives 1 star")
		await _seconds(1.0)
		_check(game.win_panel.visible, "win panel on level %s" % game.level.id)

	# Restart and pause.
	levels.current = 20
	game = await _goto("res://game/game.tscn")
	game._on_hint()
	game._on_restart()
	_check(game.state.threading == game._start_threading, "restart resets the loom")
	game._open_pause()
	await _frames(2)
	_check(game.pause_panel.visible, "pause panel opens")
	await _shot("06_pause")
	game.go_back()
	_check(not game.pause_panel.visible, "back closes pause")

	save.set_setting("colorblind", true)
	await _frames(2)
	await _shot("07_colorblind")
	save.set_setting("colorblind", false)

	var sel := await _goto("res://core/ui/level_select.tscn")
	_check(sel.name == "LevelSelect", "level select opens")
	await _shot("08_levels")
	var quilt := await _goto("res://core/ui/quilt.tscn")
	_check(quilt.name == "Quilt", "quilt opens")
	await _shot("09_quilt")
	var settings := await _goto("res://core/ui/settings.tscn")
	_check(settings.name == "Settings", "settings opens")
	await _shot("10_settings")
	settings.go_back()
	await _frames(4)
	_check(current_scene.name == "MainMenu", "back returns to the menu")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	print("%d smoke failures" % _failures.size())
	quit(1 if _failures.size() > 0 else 0)
