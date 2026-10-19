extends Screen
## The game scene: reads the current level from Levels, wires the loom board
## to the undo stack, and handles hints, stars, winning and the tutorial.

const LEVEL_SELECT := "res://core/ui/level_select.tscn"
const MAIN_MENU := "res://core/ui/main_menu.tscn"
const MODE_NAMES := {"lifting": "Lifting", "threading": "Threading", "full": "Full Loom"}
const CAPTIONS := {
	"tap": "Tap the cloth to lift a thread",
	"rows": "Each row lifts on its own",
	"match": "Make each thread match the colour around it",
	"shaft": "Threads on the same shaft lift together",
	"drag": "Drag the loose thread onto a shaft",
	"treadle": "Rows with the same peg lift together",
	"peg": "Tap a peg to move its row to another treadle",
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
var _eye_btn: IconButton
var _taps_chip: Chip
## The level's start, for restart, and the fewest taps it takes.
var _start := {}
var _par := 0
## Player moves currently in the undo stack (hints and undone moves excluded).
var _taps := 0
var _dots_used := false
var _won := false
var _used_undo := false
var _undos := 0
var _hints := 0
var _moves := 0
var _started_ms := 0
var _matched_rows := 0


func build() -> void:
	level = Levels.current_level()
	state = LoomState.from_level(level)
	_start = state.snapshot()
	_par = LoomSolver.par(level)
	var palette := Levels.palette(level.index)
	var colorblind: bool = Save.get_setting("colorblind")

	# Top bar: menu, title, hint, undo, restart.
	var bar := HBoxContainer.new()
	var menu := IconButton.new("menu", LoomTheme.INK, 74.0)
	menu.pressed.connect(_open_pause)
	bar.add_child(menu)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 2)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(Chip.new("%s  ·  %s" % [level.id, MODE_NAMES.get(level.mode, "")],
			LoomTheme.world_color(level.world_index)))
	titles.add_child(chips)
	_title = Label.new()
	_title.text = level.name
	_title.add_theme_font_override("font", LoomTheme.font(650))
	_title.add_theme_font_size_override("font_size", 36)
	_title.clip_text = true
	titles.add_child(_title)
	bar.add_child(titles)
	_eye_btn = IconButton.new("eye", LoomTheme.GRAPE, 74.0)
	_eye_btn.pressed.connect(_on_eye)
	bar.add_child(_eye_btn)
	_hint_btn = IconButton.new("hint", LoomTheme.SUN_DARK, 74.0)
	_hint_btn.pressed.connect(_on_hint)
	bar.add_child(_hint_btn)
	_undo_btn = IconButton.new("undo", LoomTheme.SKY, 74.0)
	_undo_btn.pressed.connect(_on_undo)
	bar.add_child(_undo_btn)
	_restart_btn = IconButton.new("restart", LoomTheme.ACCENT, 74.0)
	_restart_btn.pressed.connect(_on_restart)
	bar.add_child(_restart_btn)
	content.add_child(bar)

	# Target card: hold it to lay the target over the cloth.
	var target_row := HBoxContainer.new()
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_theme_constant_override("separation", 22)
	target.show_level(level, palette, false)
	target.colorblind = colorblind
	target.holdable = true
	target.hold_changed.connect(_on_compare)
	var aspect := target.aspect()
	var th := 210.0 if aspect <= 1.6 else 210.0 * 1.6 / aspect
	target.custom_minimum_size = Vector2(th * aspect, th) + Vector2(24, 24)
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 4)
	var goal := Label.new()
	goal.text = "Target"
	goal.add_theme_font_override("font", LoomTheme.font(650))
	goal.add_theme_font_size_override("font_size", 34)
	labels.add_child(goal)
	_taps_chip = Chip.new("", LoomTheme.INK_SOFT, 21)
	labels.add_child(_taps_chip)
	var hold := Label.new()
	hold.text = "Hold it to\ncompare"
	hold.theme_type_variation = &"SoftLabel"
	hold.add_theme_font_size_override("font_size", 22)
	labels.add_child(hold)
	target_row.add_child(labels)
	target_row.add_child(target)
	content.add_child(target_row)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override("font", LoomTheme.font(600))
	_caption.add_theme_color_override("font_color", LoomTheme.ACCENT_DARK)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.text = CAPTIONS.get(level.tutorial, "")
	_caption.visible = not _caption.text.is_empty()
	content.add_child(_caption)

	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.setup(state, palette, colorblind)
	board.view.show_mismatch = false
	board.view.animate = Save.get_setting("motion")
	_matched_rows = _rows_matched()
	board.lift_toggled.connect(_on_lift)
	board.warp_threaded.connect(_on_thread)
	board.peg_tapped.connect(_on_peg)
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
	_update_taps()
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
	_taps += 1
	Audio.play("clack")
	Haptics.tap()
	_after_move()


func _on_thread(c: int, s: int) -> void:
	if _won:
		return
	undo.push(LoomCommands.SetThreading.new(state, c, s))
	_taps += 1
	Audio.play("pluck", 0.04)
	Haptics.snap()
	_after_move()


func _on_peg(r: int) -> void:
	if _won:
		return
	undo.push(LoomCommands.CycleTreadle.new(state, r))
	_taps += 1
	Audio.play("pluck", 0.06)
	Haptics.snap()
	_after_move()


func _on_undo() -> void:
	if _won or not undo.can_undo():
		return
	var cmd := undo.undo()
	if cmd != null and not cmd.is_hint:
		_taps -= 1
	_used_undo = true
	_undos += 1
	_after_move()


func _on_restart() -> void:
	if _won or not undo.can_undo():
		return
	state.restore(_start)
	undo.clear()
	_taps = 0
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
	match h.kind:
		"row", "peg":
			board.view.flash_row(h.row)
			Audio.play("clack", 0.02)
		"tieup":
			var rows := state.rows_on_treadle(h.treadle)
			if not rows.is_empty():
				board.view.flash_row(rows[0])
			Audio.play("clack", 0.02)
		_:
			board.view.flash_column(h.col)
			Audio.play("pluck", 0.02)
	Haptics.snap()
	_after_move()


func _after_move() -> void:
	_moves += 1
	_update_buttons()
	_update_taps()
	_reward_rows()
	if state.matches_target():
		_win()
	else:
		_update_tutorial()


func _update_buttons() -> void:
	var can := undo.can_undo() and not _won
	_undo_btn.set_disabled_state(not can)
	_restart_btn.set_disabled_state(not can)
	_hint_btn.set_disabled_state(_won)


## A soft click and buzz whenever another row comes right.
func _reward_rows() -> void:
	var n := _rows_matched()
	if n > _matched_rows and not state.matches_target():
		Audio.play("tap", 0.02, -2.0)
		Haptics.snap()
	_matched_rows = n


func _rows_matched() -> int:
	var n := 0
	for r in state.height:
		if state.row_matches(r):
			n += 1
	return n


func _on_compare(held: bool) -> void:
	board.view.compare = held
	if held:
		Audio.play("tap", 0.03, -8.0)


func _update_taps() -> void:
	_taps_chip.set_text("%d / %d taps" % [_taps, _par])


## Show or hide the mismatch dots. Using them caps the level at 2 stars.
func _on_eye() -> void:
	if _won:
		return
	board.view.show_mismatch = not board.view.show_mismatch
	board.view.queue_redraw()
	if board.view.show_mismatch:
		_dots_used = true
	_eye_btn.icon_name = "eye_off" if board.view.show_mismatch else "eye"
	_eye_btn.queue_redraw()


## 3 stars for weaving it in the fewest taps without help; 2 with extra taps
## or the dots; 1 with a hint. Undo is always free.
func stars() -> int:
	if _hints > 0:
		return 1
	if _dots_used or _taps > _par:
		return 2
	return 3


func _update_tutorial() -> void:
	if level.tutorial.is_empty() or _won:
		pointer.clear()
		return
	var move := LoomSolver.next_move(state)
	if move.is_empty():
		pointer.clear()
	elif move.kind == "lift":
		pointer.point_tap(board.crossing_rect(_crossing_for(move.row, move.shaft), move.row))
	elif move.kind == "peg":
		pointer.point_tap(board.peg_rect(move.row))
	else:
		var from := board.slot_rect(move.col, maxi(state.threading[move.col], 0))
		if state.threading[move.col] < 0:
			# The loose end hangs at the top of the threading.
			from.size.y *= 0.5
		pointer.point_drag(from, board.slot_rect(move.col, move.shaft))


## A crossing on the given shaft in a row to point the tutorial at,
## preferring one that does not match the target yet.
func _crossing_for(r: int, shaft: int) -> int:
	var first := -1
	for c in state.width:
		if state.threading[c] != shaft:
			continue
		if first < 0:
			first = c
		if not state.cell_matches(c, r):
			return c
	return maxi(first, 0)


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
		win_panel.open(level, Levels.palette(level.index), earned, has_next, _taps, _par))


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
	board.view.animate = Save.get_setting("motion")
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

