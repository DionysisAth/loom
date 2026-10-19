class_name ProtoWin
extends Overlay
## End-of-level card for the prototype lab.

signal next_pressed
signal lab_pressed

var _confetti := Confetti.new()


func _init() -> void:
	super()
	add_child(_confetti)


func open(title: String, line: String, stars: int, has_next: bool) -> void:
	clear_body()
	var t := add_label(title, &"TitleLabel")
	t.add_theme_color_override("font_color", LoomTheme.ACCENT)
	t.add_theme_font_size_override("font_size", 64)
	var row := Screen.stars_row(stars, 3, 78.0)
	body.add_child(row)
	add_label(line, &"SoftLabel").add_theme_font_size_override("font_size", 25)
	if has_next:
		add_button("Next", &"PrimaryButton").pressed.connect(func(): next_pressed.emit())
	add_button("Back to the lab").pressed.connect(func(): lab_pressed.emit())
	show_card()
	if Save.get_setting("motion"):
		move_child(_confetti, get_child_count() - 1)
		_confetti.burst(Vector2(size.x * 0.5, size.y * 0.4), 60)
