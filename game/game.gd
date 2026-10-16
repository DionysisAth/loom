extends Screen
## The game scene: reads the current level from Levels, wires the loom board
## to the undo stack, and handles hints, stars, winning and the tutorial.

const LEVEL_SELECT := "res://core/ui/level_select.tscn"
const MAIN_MENU := "res://core/ui/main_menu.tscn"
const MODE_NAMES := {"lifting": "Lifting", "threading": "Threading", "full": "Full Loom"}
const CAPTIONS := {
	"tap": "Tap a switch to lift its threads",
	"rows": "Every row has its own switches",
	"match": "Weave the cloth to match the target",
	"shaft": "A third shaft lifts other threads",
	"drag": "Drag the loose thread onto a shaft",
}

var level: Dictionary
var state: LoomState
var undo := UndoStack.new()
var board := LoomBoard.new()
var target := Swatch.new()
var pointer := TutorialPointer.new()
var win_panel := WinPanel.new()
var pause_panel := PausePanel.new()

var _title: Label
var _caption: Label
var _undo_btn: IconButton
var _restart_btn: IconButton
var _hint_btn: IconButton
var _start_threading: PackedInt32Array
var _start_lifts: PackedInt32Array
var _won := false
var _used_undo := false
var _undos := 0
var _hints := 0
var _moves := 0
var _started_ms := 0


func build() -> void:
	level = Levels.current_level()
	state = LoomState.from_level(level)
	_start_threading = state.threading.duplicate()
	_start_lifts = state.lifts.duplicate()
	var palette := Levels.palette(level.index)
	var colorblind: bool = Save.get_setting("colorblind")

	# Top bar: menu, title, hint, undo, restart.
	var bar := HBoxContainer.new()
	var menu := IconButton.new("menu")
	menu.pressed.connect(_open_pause)
	bar.add_child(menu)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	var number := Label.new()
	number.text = "%s  ·  %s" % [level.id, MODE_NAMES.get(level.mode, "")]
	number.theme_type_variation = &"SoftLabel"
	titles.add_child(number)
	_title = Label.new()
	_title.text = level.name
	_title.add_theme_font_size_override("font_size", 34)
	_title.clip_text = true
	titles.add_child(_title)
	bar.add_child(titles)
	_hint_btn = IconButton.new("hint")
	_hint_btn.pressed.connect(_on_hint)
	bar.add_child(_hint_btn)
	_undo_btn = IconButton.new("undo")
	_undo_btn.pressed.connect(_on_undo)
	bar.add_child(_undo_btn)
	_restart_btn = IconButton.new("restart")
	_restart_btn.pressed.connect(_on_restart)
	bar.add_child(_restart_btn)
	content.add_child(bar)

	# Target swatch.
	var target_box := CenterContainer.new()
	target_box.custom_minimum_size = Vector2(0, 230)
	target.show_level(level, palette, false)
	target.colorblind = colorblind
	var aspect := target.aspect()
	var th := 200.0 if aspect <= 1.6 else 200.0 * 1.6 / aspect
	target.custom_minimum_size = Vector2(th * aspect, th)
	target_box.add_child(target)
	content.add_child(target_box)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.theme_type_variation = &"SoftLabel"
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.text = CAPTIONS.get(level.tutorial, "")
	_caption.visible = not _caption.text.is_empty()
	content.add_child(_caption)

	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.setup(state, palette, colorblind)
	board.lift_toggled.connect(_on_lift)
	board.warp_threaded.connect(_on_thread)
	content.add_child(board)

	add_child(pointer)
	add_child(win_panel)
	win_panel.next_pressed.connect(_on_next)
	win_panel.replay_pressed.connect(func(): Levels.play(level.index))
	win_panel.levels_pressed.connect(func(): Screen.goto(LEVEL_SELECT))
	add_child(pause_panel)
	pause_panel.restart_pressed.connect(_on_restart)
	pause_panel.levels_pressed.connect(func(): Screen.goto(LEVEL_SELECT))
	pause_panel.menu_pressed.connect(func(): Screen.goto(MAIN_MENU))
	Save.settings_changed.connect(_on_settings_changed)

	state.row_changed.connect(func(_r, _o): Audio.play("swish", 0.15, -10.0))
	undo.changed.connect(_update_buttons)
	_update_buttons()
	_started_ms = Time.get_ticks_msec()
	Analytics.track("level_start", {"level": level.id})
	# Wait for layout before pointing at anything.
	board.resized.connect(_update_tutorial, CONNECT_DEFERRED)
	_update_tutorial.call_deferred()


func _on_lift(r: int, s: int) -> void:
	if _won:
		return
	undo.push(LoomCommands.ToggleLift.new(state, r, s))
	Audio.play("clack")
	Haptics.tap()
	_after_move()


func _on_thread(c: int, s: int) -> void:
	if _won:
		return
	undo.push(LoomCommands.SetThreading.new(state, c, s))
	Audio.play("pluck", 0.04)
	Haptics.snap()
	_after_move()


func _on_undo() -> void:
	if _won or not undo.can_undo():
		return
	undo.undo()
	_used_undo = true
	_undos += 1
	_after_move()


func _on_restart() -> void:
	if _won or not undo.can_undo():
		return
	state.load_setup(_start_threading, _start_lifts)
	undo.clear()
	_used_undo = true
	_undos += 1
	Audio.play("swish", 0.05, -4.0)
	_after_move()


func _on_hint() -> void:
	if _won:
		return
	var h := LoomSolver.hint(state)
	var cmd := LoomCommands.from_hint(state, h)
	if cmd == null:
		return
	undo.push(cmd)
	_hints += 1
	Analytics.track("hint_used", {"level": level.id, "kind": h.kind})
	if h.kind == "row":
		board.view.flash_row(h.row)
		Audio.play("clack", 0.02)
	else:
		board.view.flash_column(h.col)
		Audio.play("pluck", 0.02)
	Haptics.snap()
	_after_move()


func _after_move() -> void:
	_moves += 1
	_update_buttons()
	if state.matches_target():
		_win()
	else:
		_update_tutorial()


func _update_buttons() -> void:
	var can := undo.can_undo() and not _won
	_undo_btn.set_disabled_state(not can)
	_restart_btn.set_disabled_state(not can)
	_hint_btn.set_disabled_state(_won)


func stars() -> int:
	if _hints > 0:
		return 1
	return 2 if _used_undo else 3


func _update_tutorial() -> void:
	if level.tutorial.is_empty() or _won:
		pointer.clear()
		return
	var move := LoomSolver.next_move(state)
	if move.is_empty():
		pointer.clear()
	elif move.kind == "lift":
		pointer.point_tap(board.lift_rect(move.row, move.shaft))
	else:
		var from := board.slot_rect(move.col, maxi(state.threading[move.col], 0))
		if state.threading[move.col] < 0:
			# The loose end hangs at the top of the threading.
			from.size.y *= 0.5
		pointer.point_drag(from, board.slot_rect(move.col, move.shaft))


func _win() -> void:
	_won = true
	pointer.clear()
	_update_buttons()
	var earned := stars()
	Save.record_win(level.id, earned)
	Analytics.track("level_complete", {
		"level": level.id, "stars": earned, "undo_count": _undos, "hints": _hints,
		"moves": _moves, "seconds": (Time.get_ticks_msec() - _started_ms) / 1000,
	})
	Audio.play("chime", 0.0, -2.0)
	Haptics.success()
	var has_next := Levels.next_index(level.index) >= 0
	get_tree().create_timer(0.55).timeout.connect(func():
		win_panel.open(level, Levels.palette(level.index), earned, has_next))


func _on_next() -> void:
	var nxt := Levels.next_index(level.index)
	if nxt < 0:
		Screen.goto(LEVEL_SELECT)
	else:
		Levels.play(nxt)


func _open_pause() -> void:
	if not _won:
		pause_panel.open()


func _on_settings_changed() -> void:
	var cb: bool = Save.get_setting("colorblind")
	board.set_colorblind(cb)
	target.colorblind = cb
	target.queue_redraw()


func go_back() -> void:
	if win_panel.visible:
		Screen.goto(LEVEL_SELECT)
	elif pause_panel.visible:
		pause_panel.close()
	else:
		_open_pause()


func _exit_tree() -> void:
	if not _won and not level.is_empty():
		Analytics.track("quit_mid_level", {"level": level.id, "moves": _moves,
			"undo_count": _undos, "hints": _hints,
			"seconds": (Time.get_ticks_msec() - _started_ms) / 1000})

