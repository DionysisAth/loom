extends Screen
## Prototype B screen: the frame of knots, a clear button and progress.

const LAB := "res://proto/lab.tscn"

static var level_index := 0

var level: Dictionary
var puzzle: ThreadPuzzle
var board := ThreadBoard.new()
var pointer := TutorialPointer.new()
var win := ProtoWin.new()
var _progress: Chip
var _done := false


func build() -> void:
	level = ThreadLevels.LEVELS[level_index]
	puzzle = ThreadPuzzle.from_level(level)
	var bar := HBoxContainer.new()
	var back := IconButton.new("back", LoomTheme.ACCENT, 74.0)
	back.pressed.connect(go_back)
	bar.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(Chip.new("B%d · Thread it" % (level_index + 1), LoomTheme.MINT))
	var t := Label.new()
	t.text = level.name
	t.add_theme_font_override("font", LoomTheme.font(650))
	t.add_theme_font_size_override("font_size", 34)
	titles.add_child(t)
	bar.add_child(titles)
	var clear := IconButton.new("restart", LoomTheme.ACCENT, 74.0)
	clear.pressed.connect(_on_clear)
	bar.add_child(clear)
	content.add_child(bar)

	var caption := Label.new()
	caption.text = level.get("tutorial", "")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", LoomTheme.font(600))
	caption.add_theme_color_override("font_color", LoomTheme.ACCENT_DARK)
	caption.add_theme_font_size_override("font_size", 27)
	caption.visible = not caption.text.is_empty()
	content.add_child(caption)

	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.setup(puzzle, ThreadLevels.palette())
	board.thread_connected.connect(_on_connected)
	board.finished.connect(_finish)
	content.add_child(board)
	var foot := CenterContainer.new()
	_progress = Chip.new("", LoomTheme.INK_SOFT, 24)
	foot.add_child(_progress)
	content.add_child(foot)
	puzzle.changed.connect(_update)
	add_child(pointer)
	add_child(win)
	win.next_pressed.connect(_next)
	win.lab_pressed.connect(go_back)
	_update()
	board.resized.connect(_guide, CONNECT_DEFERRED)
	_guide.call_deferred()


func _update() -> void:
	var joined := 0
	for pg in puzzle.pegs:
		if puzzle.connected(pg.color):
			joined += 1
	_progress.set_text("%d / %d threads  ·  %d / %d filled" % [joined, puzzle.pegs.size(),
			puzzle.filled(), puzzle.width * puzzle.height])
	_guide()


func _on_connected(_color: int) -> void:
	Audio.play_at("chime", 1.3, -10.0)
	Haptics.snap()


func _on_clear() -> void:
	if not _done:
		puzzle.clear()
		Audio.play("swish", 0.05, -4.0)


## On the first level, show the first thread being dragged.
func _guide() -> void:
	if _done or level_index != 0 or not puzzle.paths.is_empty():
		pointer.clear()
		return
	var pg: Dictionary = puzzle.pegs[0]
	pointer.point_drag(board.global_cell_rect(pg.a), board.global_cell_rect(Vector2i(3, 0)))


func _finish() -> void:
	if _done:
		return
	_done = true
	pointer.clear()
	Save.record_proto("B%d" % (level_index + 1), 3)
	Audio.play("chime", 0.0, -2.0)
	Haptics.success()
	get_tree().create_timer(0.5).timeout.connect(func():
		win.open("Woven!", "Every thread in place", 3, level_index + 1 < ThreadLevels.LEVELS.size()))


func _next() -> void:
	level_index += 1
	Screen.goto("res://proto/thread/thread_game.tscn")


func go_back() -> void:
	Screen.goto(LAB)
