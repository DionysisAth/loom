class_name TutorialPointer
extends Control
## The tutorial's teacher: a pulsing ring and a fingertip that taps a switch
## or drags a warp onto a shaft, so players learn without reading.

var _mode := ""
var _from := Rect2()
var _to := Rect2()
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func point_tap(global_rect: Rect2) -> void:
	_mode = "tap"
	_to = _local(global_rect)
	_start()


func point_drag(from_global: Rect2, to_global: Rect2) -> void:
	_mode = "drag"
	_from = _local(from_global)
	_to = _local(to_global)
	_start()


func clear() -> void:
	_mode = ""
	visible = false
	set_process(false)


func _start() -> void:
	_t = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _local(r: Rect2) -> Rect2:
	var inv := get_global_transform().affine_inverse()
	return Rect2(inv * r.position, r.size)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _mode.is_empty():
		return
	var gold := LoomTheme.GOLD
	var c := _to.get_center()
	var radius := maxf(_to.size.x, _to.size.y) * 0.62
	var pulse := fmod(_t, 1.2) / 1.2
	draw_arc(c, radius * (1.0 + pulse * 0.5), 0, TAU, 40, Color(gold, 1.0 - pulse), 5.0, true)
	draw_arc(c, radius, 0, TAU, 40, Color(gold, 0.9), 4.0, true)
	var finger: Vector2
	var press := 0.0
	if _mode == "tap":
		var k := fmod(_t, 1.2)
		press = clampf(1.0 - absf(k - 0.45) / 0.25, 0.0, 1.0)
		finger = c + Vector2(radius * 0.55, radius * 0.75) * (1.0 - press * 0.45)
	else:
		var k := fmod(_t, 2.0) / 2.0
		var move := smoothstep(0.2, 0.8, k)
		var a := _from.get_center()
		finger = a.lerp(c, move) + Vector2(radius * 0.25, radius * 0.35)
		press = 1.0 if k > 0.12 and k < 0.88 else 0.0
		if press > 0.0:
			draw_line(a, a.lerp(c, move), Color(gold, 0.6), 6.0, true)
	var fr := radius * 0.38
	draw_circle(finger + Vector2(3, 5), fr, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(finger, fr, Color(1, 0.96, 0.9, 0.95), true, -1.0, true)
	draw_arc(finger, fr, 0, TAU, 32, LoomTheme.INK, 3.0, true)
	if press > 0.0:
		draw_circle(finger, fr * 0.45 * press, Color(gold, 0.8), true, -1.0, true)
