class_name LevelTile
extends BaseButton
## One level in the level select: a chunky card with the number, stars, and
## the woven cloth once it is finished; a lock while it is not reachable. The
## next level to play gently pulses.

var index := 0
var accent := LoomTheme.ACCENT
var _level := {}
var _done := false
var _unlocked := false
var _current := false
var _stars := 0
var _swatch: Swatch
var _t := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	set_process(false)


func setup(i: int, color: Color) -> void:
	index = i
	accent = color
	_level = Levels.level(i)
	_done = Save.is_completed(_level.id)
	_unlocked = Levels.is_unlocked(i)
	_current = _unlocked and not _done
	_stars = Save.stars(_level.id)
	if _done:
		_swatch = Swatch.new()
		_swatch.frame = false
		_swatch.show_level(_level, Levels.palette(i), true)
		_swatch.colorblind = Save.get_setting("colorblind")
		add_child(_swatch)
		var badge := Chip.new(str(_level.number), accent, 22)
		badge.position = Vector2(8, 8)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
	resized.connect(_layout)
	pressed.connect(func(): Audio.play("tap", 0.05, -6.0))
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	set_process(_current)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _layout() -> void:
	if _swatch:
		_swatch.position = Vector2(16, 16)
		_swatch.size = Vector2(size.x - 32, size.y - 70)


func _draw() -> void:
	var lip := 8.0
	var down := is_pressed() and _unlocked
	var face := Rect2(Vector2(0, lip * 0.7 if down else 0.0), size - Vector2(0, lip))
	var lip_rect := Rect2(Vector2(0, lip), size - Vector2(0, lip))
	var font := LoomTheme.font(650)
	if not _unlocked:
		draw_style_box(LoomTheme.box(Color("#f6d9e2"), 24, 0), lip_rect)
		draw_style_box(LoomTheme.box(Color("#fbe9ef"), 24, 0), face)
		Icons.draw(self, "lock", Rect2(face.get_center() - Vector2(26, 30), Vector2(52, 52)),
				Color("#d7a9ba"))
		return
	if _current:
		var glow := 0.5 + 0.5 * sin(_t * 3.0)
		draw_style_box(LoomTheme.box(Color(accent, 0.25 + 0.25 * glow), 30, 0), Rect2(-6, -6, size.x + 12, size.y + 10))
	draw_style_box(LoomTheme.box(accent.lerp(Color.WHITE, 0.45) if not _done else LoomTheme.CARD_LIP, 24, 0), lip_rect)
	draw_style_box(LoomTheme.box(LoomTheme.CARD, 24, 0), face)
	if not _done:
		var center := face.get_center() - Vector2(0, 14)
		draw_circle(center, 42, accent, true, -1.0, true)
		draw_string(font, center + Vector2(-60, 16), str(_level.number), HORIZONTAL_ALIGNMENT_CENTER,
				120, 44, Color.WHITE)
		if _level.kind == "tutorial":
			var tag := Rect2(face.position + Vector2(10, 10), Vector2(64, 28))
			draw_style_box(LoomTheme.box(LoomTheme.SUN, 14, 0), tag)
			draw_string(LoomTheme.font(600), tag.position + Vector2(0, 21), "learn",
					HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 19, Color.WHITE)
	var star_size := 32.0
	var start := Vector2(size.x * 0.5 - star_size * 1.5, face.end.y - star_size - 10)
	for i in 3:
		var sr := Rect2(start + Vector2(i * star_size, 0), Vector2(star_size, star_size))
		Icons.draw(self, "star" if i < _stars else "star_empty", sr,
				LoomTheme.GOLD if i < _stars else Color("#e2cfe0"))
