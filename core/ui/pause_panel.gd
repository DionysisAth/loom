class_name PausePanel
extends Overlay
## In-level menu: resume, restart, leave, and quick settings.

signal restart_pressed
signal levels_pressed
signal menu_pressed


func open() -> void:
	clear_body()
	var title := add_label("Paused", &"TitleLabel")
	title.add_theme_color_override("font_color", LoomTheme.GRAPE)
	add_button("Resume", &"PrimaryButton").pressed.connect(close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for item in [["Restart", &"SunButton", restart_pressed], ["Levels", &"SkyButton", levels_pressed],
			["Menu", &"GrapeButton", menu_pressed]]:
		var b := Button.new()
		b.text = item[0]
		b.theme_type_variation = item[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 92)
		b.add_theme_font_size_override("font_size", 28)
		var sig: Signal = item[2]
		b.pressed.connect(func():
			Audio.play("tap", 0.05, -6.0)
			if sig == restart_pressed:
				close()
			sig.emit())
		row.add_child(b)
	body.add_child(row)
	SettingsScreen.add_toggles(body)
	show_card()
