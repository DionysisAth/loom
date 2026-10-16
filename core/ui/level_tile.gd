class_name LevelTile
extends BaseButton
## One level in the level select: number, stars, and the woven cloth once it
## is finished; a lock while it is not yet reachable.

var index := 0
var _level := {}
var _done := false
var _unlocked := false
var _stars := 0
var _swatch: Swatch


func _init() -> void:
	focus_mode = Control.FOCUS_NONE


func setup(i: int) -> void:
	index = i
	_level = Levels.level(i)
	_done = Save.is_completed(_level.id)
	_unlocked = Levels.is_unlocked(i)
	_stars = Save.stars(_level.id)
	if _done:
		_swatch = Swatch.new()
		_swatch.frame = false
		_swatch.show_level(_level, Levels.palette(i), true)
		_swatch.colorblind = Save.get_setting("colorblind")
		add_child(_swatch)
	resized.connect(_layout)
	pressed.connect(func(): Audio.play("tap", 0.05, -6.0))


func _layout() -> void:
	if _swatch:
		_swatch.position = Vector2(14, 14)
		_swatch.size = Vector2(size.x - 28, size.y - 64)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := LoomTheme.PANEL if _unlocked else LoomTheme.BG_DEEP
	if is_pressed():
		bg = bg.darkened(0.06)
	draw_style_box(LoomTheme.box(bg, 18), r)
	var font := get_theme_default_font()
	if not _unlocked:
		Icons.draw(self, "lock", Rect2(r.get_center() - Vector2(28, 40), Vector2(56, 56)),
				LoomTheme.INK_SOFT.lerp(LoomTheme.BG, 0.3))
		return
	if not _done:
		draw_string(font, Vector2(0, size.y * 0.5), str(_level.number), HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 46, LoomTheme.INK)
		if _level.kind == "tutorial":
			draw_string(font, Vector2(0, size.y * 0.5 + 34), "learn", HORIZONTAL_ALIGNMENT_CENTER,
					size.x, 22, LoomTheme.INK_SOFT)
	else:
		draw_string(font, Vector2(12, 40), str(_level.number), HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
				LoomTheme.PANEL)
	var star_size := 30.0
	var start := Vector2(size.x * 0.5 - star_size * 1.5, size.y - star_size - 12)
	for i in 3:
		var sr := Rect2(start + Vector2(i * star_size, 0), Vector2(star_size, star_size))
		Icons.draw(self, "star" if i < _stars else "star_empty", sr,
				LoomTheme.GOLD if i < _stars else LoomTheme.INK_SOFT.lerp(LoomTheme.BG, 0.4))
