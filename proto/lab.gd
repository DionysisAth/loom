extends Screen
## The prototype lab: two new ways to play, a few levels each, to compare
## by feel before rebuilding the game around one.

const PROTOS := [
	{
		"key": "A", "title": "A · Weave it", "color": "SkyButton",
		"blurb": "Press a pedal, swipe the shuttle, and the cloth grows row by row.",
		"scene": "res://proto/weave/weave_game.tscn",
	},
	{
		"key": "B", "title": "B · Thread it", "color": "MintButton",
		"blurb": "Drag each thread from its knot to its twin. Fill the frame to weave the picture.",
		"scene": "res://proto/thread/thread_game.tscn",
	},
]


func build() -> void:
	add_header("Prototype Lab")
	var intro := Label.new()
	intro.text = "Two new ways to play. Try both and tell us which feels better."
	intro.theme_type_variation = &"SoftLabel"
	intro.add_theme_font_size_override("font_size", 26)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	for proto in PROTOS:
		var card := PanelContainer.new()
		content.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		card.add_child(col)
		var title := Label.new()
		title.text = proto.title
		title.theme_type_variation = &"TitleLabel"
		col.add_child(title)
		var blurb := Label.new()
		blurb.text = proto.blurb
		blurb.theme_type_variation = &"SoftLabel"
		blurb.add_theme_font_size_override("font_size", 25)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(blurb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		var levels: Array = WeaveLevels.LEVELS if proto.key == "A" else ThreadLevels.LEVELS
		for i in levels.size():
			var b := Button.new()
			var id := "%s%d" % [proto.key, i + 1]
			var stars := Save.proto_stars(id)
			b.text = str(i + 1) if stars == 0 else "%d · done" % (i + 1)
			b.theme_type_variation = StringName(proto.color)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 100)
			b.add_theme_font_size_override("font_size", 36)
			b.pressed.connect(_open.bind(proto.key, i))
			row.add_child(b)


func _open(key: String, i: int) -> void:
	Audio.play("tap", 0.05, -6.0)
	if key == "A":
		load("res://proto/weave/weave_game.gd").level_index = i
		Screen.goto("res://proto/weave/weave_game.tscn")
	else:
		load("res://proto/thread/thread_game.gd").level_index = i
		Screen.goto("res://proto/thread/thread_game.tscn")


func go_back() -> void:
	Screen.goto("res://core/ui/main_menu.tscn")
