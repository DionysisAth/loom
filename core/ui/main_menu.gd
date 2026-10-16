extends Screen
## Title screen: continue, level select, quilt and settings.

## Printed once the first frame is up; CI's emulator test waits for it.
const BOOT_MARKER := "LOOM_BOOT_OK"

static var _booted := false


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "Loom"
	title.theme_type_variation = &"HugeLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var tagline := Label.new()
	tagline.text = "Lift the threads to weave each pattern"
	tagline.theme_type_variation = &"SoftLabel"
	tagline.add_theme_font_size_override("font_size", 28)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tagline)

	var swatch := Swatch.new()
	var showcase := _showcase_level()
	if showcase >= 0:
		swatch.show_level(Levels.level(showcase), Levels.palette(showcase), true)
		swatch.colorblind = Save.get_setting("colorblind")
	swatch.custom_minimum_size = Vector2(0, 380)
	content.add_child(swatch)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(460, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(buttons)
	var next := Levels.first_unsolved()
	var play := Button.new()
	play.theme_type_variation = &"PrimaryButton"
	play.custom_minimum_size = Vector2(0, 110)
	play.text = "Play" if Save.completed_count() == 0 else "Continue  %s" % Levels.level(next).id
	play.pressed.connect(func(): Levels.play(next))
	buttons.add_child(play)
	for item in [["Levels", "res://core/ui/level_select.tscn"], ["Quilt", "res://core/ui/quilt.tscn"],
			["Settings", "res://core/ui/settings.tscn"]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 96)
		var path: String = item[1]
		b.pressed.connect(func(): Audio.play("tap", 0.05, -6.0); Screen.goto(path))
		buttons.add_child(b)
	var stars := Label.new()
	stars.text = "%d / %d cloths woven  ·  %d stars" % [Save.completed_count(), Levels.count(),
			Save.total_stars()]
	stars.theme_type_variation = &"SoftLabel"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stars)
	if not _booted:
		_booted = true
		_report_boot.call_deferred()


func _report_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("%s levels=%d renderer=%s" % [BOOT_MARKER, Levels.count(),
			RenderingServer.get_current_rendering_method()])


## The most recently woven showpiece, or a level that looks good by default.
func _showcase_level() -> int:
	if Levels.count() == 0:
		return -1
	var best := -1
	for i in Levels.count():
		var lv := Levels.level(i)
		if lv.kind == "showpiece" and (best < 0 or Save.is_completed(lv.id)):
			best = i
	return best if best >= 0 else 0


func go_back() -> void:
	get_tree().quit()
