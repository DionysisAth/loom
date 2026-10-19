extends Screen
## Prototype A screen: pattern card, loom, pedals; unpick and restart.

const LAB := "res://proto/lab.tscn"

static var level_index := 0

var level: Dictionary
var loom: WeaveLoom
var board := WeaveBoard.new()
var draft := WeaveDraft.new()
var pointer := TutorialPointer.new()
var win := ProtoWin.new()
var _caption: Label
var _unpick: IconButton
var _done := false


func build() -> void:
	level = WeaveLevels.LEVELS[level_index]
	loom = WeaveLoom.from_level(level)
	var palette := WeaveLevels.palette()
	var bar := HBoxContainer.new()
	var back := IconButton.new("back", LoomTheme.ACCENT, 74.0)
	back.pressed.connect(go_back)
	bar.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(Chip.new("A%d · Weave it" % (level_index + 1), LoomTheme.SKY))
	var t := Label.new()
	t.text = level.name
	t.add_theme_font_override("font", LoomTheme.font(650))
	t.add_theme_font_size_override("font_size", 34)
	titles.add_child(t)
	bar.add_child(titles)
	_unpick = IconButton.new("undo", LoomTheme.SKY, 74.0)
	_unpick.pressed.connect(_on_unpick)
	bar.add_child(_unpick)
	var restart := IconButton.new("restart", LoomTheme.ACCENT, 74.0)
	restart.pressed.connect(_on_restart)
	bar.add_child(restart)
	content.add_child(bar)

	draft.setup(loom, palette)
	draft.custom_minimum_size = Vector2(0, 190)
	content.add_child(draft)
	_caption = Label.new()
	_caption.text = level.get("tutorial", "")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override("font", LoomTheme.font(600))
	_caption.add_theme_color_override("font_color", LoomTheme.ACCENT_DARK)
	_caption.add_theme_font_size_override("font_size", 27)
	_caption.visible = not _caption.text.is_empty()
	content.add_child(_caption)

	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.setup(loom, palette)
	board.pedal_pressed.connect(_on_pedal)
	board.tie_toggled.connect(_on_tie)
	board.row_woven.connect(_on_row)
	board.bumped.connect(_on_bump)
	content.add_child(board)
	add_child(pointer)
	add_child(win)
	win.next_pressed.connect(_next)
	win.lab_pressed.connect(go_back)
	board.resized.connect(_guide, CONNECT_DEFERRED)
	_guide.call_deferred()


func _on_pedal(p: int) -> void:
	Audio.play("clack", 0.04, -2.0)
	Audio.play("swish", 0.1, -12.0)
	Haptics.tap()
	_guide()


func _on_tie(p: int, s: int) -> void:
	loom.toggle_tie(p, s)
	if board.pressed == p:
		board.set_process(true)
	Audio.play("tap", 0.05, -4.0)
	Haptics.tap()
	_guide()


func _on_row(row: int, ok: bool) -> void:
	Audio.play("thud", 0.05, 0.0)
	Haptics.snap()
	if ok:
		Audio.play_at("pluck", 1.0 + row * 0.08, -4.0)
	else:
		Audio.play_at("tap", 0.5, -2.0)
		Haptics.success()
	if loom.complete():
		_finish()
	else:
		_guide()


func _on_bump() -> void:
	Audio.play_at("clack", 0.6, -4.0)
	Haptics.tap()
	pointer.point_tap(board.global_pedal_rect(maxi(loom.right_pedal(), 0)))


func _on_unpick() -> void:
	if _done or not loom.unpick():
		return
	board.side = -board.side
	Audio.play("swish", 0.05, -4.0)
	_guide()


func _on_restart() -> void:
	if _done:
		return
	loom.restart()
	board.side = -1
	board.pressed = -1
	board.set_process(true)
	_guide()


## The tutorial pointer on the first level: pedal first, then the swipe.
func _guide() -> void:
	if _done or level_index != 0:
		pointer.clear()
		return
	var want := loom.right_pedal()
	if want < 0:
		pointer.clear()
	elif board.pressed != want:
		pointer.point_tap(board.global_pedal_rect(want))
	else:
		pointer.point_drag(board.global_shuttle_rect(), board.global_far_side_rect())


func _finish() -> void:
	_done = true
	pointer.clear()
	var stars := 3 if loom.mistakes_made == 0 else (2 if loom.mistakes_made <= 2 else 1)
	Save.record_proto("A%d" % (level_index + 1), stars)
	Audio.play("chime", 0.0, -2.0)
	Haptics.success()
	var line := "No mistakes!" if loom.mistakes_made == 0 else "%d row%s unpicked" % [
		loom.mistakes_made, "" if loom.mistakes_made == 1 else "s"]
	get_tree().create_timer(0.7).timeout.connect(func():
		win.open("Woven!", line, stars, level_index + 1 < WeaveLevels.LEVELS.size()))


func _next() -> void:
	level_index += 1
	Screen.goto("res://proto/weave/weave_game.tscn")


func go_back() -> void:
	Screen.goto(LAB)
