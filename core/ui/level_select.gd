extends Screen
## World tabs and a grid of level tiles with stars.

const TAB_STYLES := [&"PrimaryButton", &"GrapeButton", &"MintButton"]

static var _world := -1

var _grid: GridContainer
var _tabs: Array[Button] = []


func build() -> void:
	add_header("Levels")
	if _world < 0:
		_world = Levels.world_of(Levels.first_unsolved()).world - 1 if Levels.count() > 0 else 0
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for w in Levels.worlds.size():
		var t := Button.new()
		t.toggle_mode = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(0, 84)
		t.add_theme_font_size_override("font_size", 27)
		t.add_theme_constant_override("h_separation", 0)
		t.text = Levels.worlds[w].name
		t.pressed.connect(func(): _select(w))
		tabs.add_child(t)
		_tabs.append(t)
	content.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(pad)
	pad.add_child(_grid)
	_select(_world)


func _select(w: int) -> void:
	_world = clampi(w, 0, maxi(0, Levels.worlds.size() - 1))
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _world
		_tabs[i].theme_type_variation = TAB_STYLES[i % TAB_STYLES.size()] if i == _world else &""
	for child in _grid.get_children():
		child.queue_free()
	if Levels.worlds.is_empty():
		return
	var world: Dictionary = Levels.worlds[_world]
	for j in world.levels.size():
		var i: int = world.first + j
		var tile := LevelTile.new()
		tile.setup(i, LoomTheme.world_color(_world))
		tile.custom_minimum_size = Vector2(150, 176)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.pressed.connect(_open.bind(i))
		_grid.add_child(tile)


func _open(i: int) -> void:
	if Levels.is_unlocked(i):
		Levels.play(i)


func go_back() -> void:
	Screen.goto("res://core/ui/main_menu.tscn")
