class_name WinPanel
extends Overlay
## Shown when the cloth matches: the finished piece with its tag and stars.

signal next_pressed
signal replay_pressed
signal levels_pressed


func open(level: Dictionary, palette: PackedColorArray, stars: int, has_next: bool) -> void:
	clear_body()
	add_label("Woven!", &"TitleLabel")
	var cloth := Swatch.new()
	cloth.show_level(level, palette, true)
	cloth.colorblind = Save.get_setting("colorblind")
	var h := 260.0
	cloth.custom_minimum_size = Vector2(minf(h * cloth.aspect(), 480.0), h)
	var holder := CenterContainer.new()
	holder.add_child(cloth)
	body.add_child(holder)
	add_label("“%s”" % level.name, &"SoftLabel").add_theme_font_size_override("font_size", 30)
	var row := Screen.stars_row(0, 3, 64.0)
	body.add_child(row)
	var reason := add_label(_reason(stars), &"SoftLabel")
	reason.add_theme_font_size_override("font_size", 22)
	if has_next:
		add_button("Next", true).pressed.connect(func(): next_pressed.emit())
	else:
		add_label("You finished every cloth. More soon!")
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(func(): replay_pressed.emit())
	small.add_child(replay)
	var levels := Button.new()
	levels.text = "Levels"
	levels.pressed.connect(func(): levels_pressed.emit())
	small.add_child(levels)
	body.add_child(small)
	show_card()
	# Stars pop in one by one.
	for i in stars:
		var star: StarIcon = row.get_child(i)
		get_tree().create_timer(0.35 + i * 0.22).timeout.connect(func():
			star.filled = true
			star.pivot_offset = star.size * 0.5
			star.scale = Vector2(1.5, 1.5)
			create_tween().tween_property(star, "scale", Vector2.ONE, 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play("tap", 0.0, -4.0 + i))


func _reason(stars: int) -> String:
	match stars:
		3:
			return "No undos, no hints"
		2:
			return "Woven with undos — try it straight through for 3 stars"
		_:
			return "Woven with a hint — solve it on your own for more stars"
