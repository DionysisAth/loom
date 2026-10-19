extends Screen
## Title screen: bouncing rainbow title, a woven showpiece, and big colourful
## buttons for continue, levels, quilt and settings.

## Printed once the first frame is up; CI's emulator test waits for it.
const BOOT_MARKER := "LOOM_BOOT_OK"
const TITLE_COLORS: Array[Color] = [Color("#ef6f6c"), Color("#f2b84b"), Color("#4fbf9a"),
		Color("#5b8def")]

const EXIT_WINDOW := 2.0

static var _booted := false

var _back_ms := -100000

var _letters: Array[Label] = []
var _swatch := Swatch.new()
var _t := 0.0


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 22)
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 2)
	var word := "Loom"
	for i in word.length():
		var l := Label.new()
		l.text = word[i]
		l.theme_type_variation = &"HugeLabel"
		l.add_theme_color_override("font_color", TITLE_COLORS[i % TITLE_COLORS.size()])
		l.add_theme_color_override("font_outline_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", 16)
		l.add_theme_color_override("font_shadow_color", Color(0.35, 0.25, 0.3, 0.12))
		l.add_theme_constant_override("shadow_offset_y", 10)
		l.add_theme_constant_override("shadow_offset_x", 0)
		title.add_child(l)
		_letters.append(l)
	content.add_child(title)
	var tagline := Label.new()
	tagline.text = "Lift the threads to weave each pattern"
	tagline.theme_type_variation = &"SoftLabel"
	tagline.add_theme_font_size_override("font_size", 29)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tagline)

	var showcase := _showcase_level()
	if showcase >= 0:
		_swatch.show_level(Levels.level(showcase), Levels.palette(showcase), true)
		_swatch.colorblind = Save.get_setting("colorblind")
	_swatch.custom_minimum_size = Vector2(0, 360)
	content.add_child(_swatch)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(480, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var next := Levels.first_unsolved()
	var play := Button.new()
	play.theme_type_variation = &"PrimaryButton"
	play.custom_minimum_size = Vector2(0, 120)
	play.add_theme_font_size_override("font_size", 44)
	play.text = "Play" if Save.completed_count() == 0 else "Continue  %s" % Levels.level(next).id
	play.pressed.connect(func(): Audio.play("tap", 0.05, -6.0); Levels.play(next))
	buttons.add_child(play)
	var lab := Button.new()
	lab.text = "Prototype Lab: new ways to play"
	lab.theme_type_variation = &"SunButton"
	lab.custom_minimum_size = Vector2(0, 100)
	lab.add_theme_font_size_override("font_size", 30)
	lab.pressed.connect(func(): Audio.play("tap", 0.05, -6.0); Screen.goto("res://proto/lab.tscn"))
	buttons.add_child(lab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for item in [["Levels", "res://core/ui/level_select.tscn", &"SkyButton"],
			["Quilt", "res://core/ui/quilt.tscn", &"MintButton"]]:
		var b := Button.new()
		b.text = item[0]
		b.theme_type_variation = item[2]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 100)
		var path: String = item[1]
		b.pressed.connect(func(): Audio.play("tap", 0.05, -6.0); Screen.goto(path))
		row.add_child(b)
	buttons.add_child(row)
	var settings := Button.new()
	settings.text = "Settings"
	settings.custom_minimum_size = Vector2(0, 96)
	settings.pressed.connect(func(): Audio.play("tap", 0.05, -6.0); Screen.goto("res://core/ui/settings.tscn"))
	buttons.add_child(settings)

	var stats := CenterContainer.new()
	stats.add_child(Chip.new("%d / %d cloths woven  ·  %d stars" % [Save.completed_count(), Levels.count(),
			Save.total_stars()], LoomTheme.GRAPE, 24))
	content.add_child(stats)
	if not _booted:
		_booted = true
		_report_boot.call_deferred()


func _process(delta: float) -> void:
	if not Save.get_setting("motion"):
		return
	_t += delta
	# Letters bob in a wave; the showcase cloth sways gently.
	for i in _letters.size():
		var l := _letters[i]
		l.pivot_offset = l.size * 0.5
		l.position.y = sin(_t * 1.4 - i * 0.7) * 3.0
	_swatch.pivot_offset = _swatch.size * 0.5
	_swatch.rotation = sin(_t * 0.5) * 0.012


func _report_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("%s levels=%d renderer=%s" % [BOOT_MARKER, Levels.count(),
			RenderingServer.get_current_rendering_method()])


## The most recently woven showpiece, or the first one.
func _showcase_level() -> int:
	if Levels.count() == 0:
		return -1
	var best := -1
	for i in Levels.count():
		var lv := Levels.level(i)
		if lv.kind == "showpiece" and (best < 0 or Save.is_completed(lv.id)):
			best = i
	return best if best >= 0 else 0


## Back once shows a hint; back again within EXIT_WINDOW seconds quits.
func go_back() -> void:
	var now := Time.get_ticks_msec()
	if now - _back_ms < EXIT_WINDOW * 1000.0:
		print("LOOM_QUIT back twice on the main menu")
		get_tree().quit()
		return
	_back_ms = now
	var toast := Chip.new("Press back again to exit", LoomTheme.INK, 26)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	await get_tree().process_frame
	toast.position = Vector2((size.x - toast.size.x) * 0.5, size.y - toast.size.y - 60)
	var tw := create_tween()
	tw.tween_interval(EXIT_WINDOW - 0.3)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(toast.queue_free)
