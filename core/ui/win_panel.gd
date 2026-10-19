class_name WinPanel
extends Overlay
## Shown when the cloth matches: confetti, the finished piece with its tag,
## and stars popping in one by one.

signal next_pressed
signal replay_pressed
signal levels_pressed

var _confetti := Confetti.new()


func _init() -> void:
	super()
	add_child(_confetti)


func open(level: Dictionary, palette: PackedColorArray, stars: int, has_next: bool,
		taps := 0, par := 0) -> void:
	clear_body()
	var title := add_label("Woven!", &"TitleLabel")
	title.add_theme_color_override("font_color", LoomTheme.ACCENT)
	title.add_theme_font_size_override("font_size", 64)
	var cloth := Swatch.new()
	cloth.show_level(level, palette, true)
	cloth.colorblind = Save.get_setting("colorblind")
	var h := 270.0
	cloth.custom_minimum_size = Vector2(minf(h * cloth.aspect(), 500.0), h)
	var holder := CenterContainer.new()
	holder.add_child(cloth)
	body.add_child(holder)
	var tag := CenterContainer.new()
	tag.add_child(Chip.new("“%s”" % level.name, LoomTheme.world_color(level.get("world_index", 0)), 28))
	body.add_child(tag)
	var row := Screen.stars_row(0, 3, 78.0)
	body.add_child(row)
	var reason := add_label(_reason(stars, taps, par), &"SoftLabel")
	reason.add_theme_font_size_override("font_size", 23)
	if has_next:
		add_button("Next", &"PrimaryButton").pressed.connect(func(): next_pressed.emit())
	else:
		add_label("You finished every cloth. More soon!")
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 18)
	var replay := Button.new()
	replay.text = "Replay"
	replay.custom_minimum_size = Vector2(220, 90)
	replay.pressed.connect(func(): replay_pressed.emit())
	small.add_child(replay)
	var levels := Button.new()
	levels.text = "Levels"
	levels.theme_type_variation = &"SkyButton"
	levels.custom_minimum_size = Vector2(220, 90)
	levels.pressed.connect(func(): levels_pressed.emit())
	small.add_child(levels)
	body.add_child(small)
	show_card()
	# Confetti only for the showpiece cloths, so it stays special.
	if level.get("kind", "") == "showpiece" and Save.get_setting("motion"):
		move_child(_confetti, get_child_count() - 1)
		_confetti.burst(Vector2(size.x * 0.5, size.y * 0.42))
	# Stars pop in one by one.
	for i in stars:
		var star: StarIcon = row.get_child(i)
		get_tree().create_timer(0.35 + i * 0.22).timeout.connect(func():
			star.filled = true
			star.pivot_offset = star.size * 0.5
			star.scale = Vector2(1.6, 1.6)
			create_tween().tween_property(star, "scale", Vector2.ONE, 0.3) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play("tap", 0.0, -4.0 + i))


func _reason(stars: int, taps: int, par: int) -> String:
	match stars:
		3:
			return "Woven in %d taps, the best there is" % taps
		2:
			if taps > par:
				return "Woven in %d taps. It can be done in %d" % [taps, par]
			return "Woven with the dots. Try it without for 3 stars"
		_:
			return "Woven with a hint. Solve it on your own for more stars"
