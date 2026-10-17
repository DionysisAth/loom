extends Screen
## Every finished cloth stitched into one quilt per world.

const COLUMNS := 5


func build() -> void:
	add_header("Quilt")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 26)
	scroll.add_child(list)
	for world in Levels.worlds:
		var done := 0
		for lv in world.levels:
			if Save.is_completed(lv.id):
				done += 1
		var label := Label.new()
		label.text = "%s  ·  %d / %d" % [world.name, done, world.levels.size()]
		label.add_theme_font_override("font", LoomTheme.font(650))
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", LoomTheme.world_color(world.world - 1))
		list.add_child(label)
		var quilt := QuiltPatchwork.new()
		quilt.setup(world, COLUMNS)
		list.add_child(quilt)


func go_back() -> void:
	Screen.goto("res://core/ui/main_menu.tscn")
