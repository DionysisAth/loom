class_name Confetti
extends Control
## A one-shot burst of bright paper confetti (drawn, no textures).

const COLORS: Array[Color] = [Color("#ff5d73"), Color("#ffbe0b"), Color("#3a86ff"),
		Color("#06c793"), Color("#9b5cf0"), Color("#ff8f1f")]
const GRAVITY := 1400.0
const LIFE := 2.6

var _bits: Array[Dictionary] = []
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func burst(at: Vector2, count := 90) -> void:
	_bits.clear()
	_t = 0.0
	for i in count:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var speed := randf_range(500.0, 1250.0)
		_bits.append({
			"p": at, "v": Vector2.from_angle(a) * speed,
			"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"size": Vector2(randf_range(10, 18), randf_range(6, 11)),
			"color": COLORS[i % COLORS.size()],
			"wobble": randf() * TAU,
		})
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	for b in _bits:
		b.v.y += GRAVITY * delta
		b.v *= 1.0 - 1.6 * delta
		b.p += b.v * delta + Vector2(sin(_t * 6.0 + b.wobble) * 40.0 * delta, 0)
		b.rot += b.spin * delta
	queue_redraw()
	if _t > LIFE:
		_bits.clear()
		set_process(false)
		queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFE - _t) / 0.6, 0.0, 1.0)
	for b in _bits:
		var flip := absf(cos(_t * 5.0 + b.wobble))
		draw_set_transform(b.p, b.rot, Vector2(1.0, 0.3 + 0.7 * flip))
		var s: Vector2 = b.size
		draw_rect(Rect2(-s * 0.5, s), Color(b.color, fade))
	draw_set_transform(Vector2.ZERO)
