class_name LoomTheme
extends RefCounted
## Colours, fonts and the shared UI theme: a warm peach-to-pink backdrop,
## white cards, chunky pill buttons with a "3D" lip, and a light honey loom.

const BG := Color("#f8f3ec")
const BG_TOP := Color("#fbf8f3")
const BG_BOTTOM := Color("#f4ece4")
const BG_DEEP := Color("#efe5dc")
const CARD := Color("#ffffff")
const CARD_LIP := Color("#ece1d8")
const PANEL := CARD
const INK := Color("#3d3346")
const INK_SOFT := Color("#8a8094")
const ACCENT := Color("#ef6f6c")
const ACCENT_DARK := Color("#cf5552")
const SKY := Color("#5b8def")
const SKY_DARK := Color("#4470c9")
const MINT := Color("#4fbf9a")
const MINT_DARK := Color("#3a9a7b")
const SUN := Color("#f2b84b")
const SUN_DARK := Color("#cf962e")
const GRAPE := Color("#9a7bd8")
const GRAPE_DARK := Color("#7a5cb8")
const GOLD := Color("#f2b84b")
const WOOD := Color("#e8c79c")
const WOOD_LIGHT := Color("#f5dfbf")
const WOOD_DARK := Color("#cfa36e")
const SHAFTS: Array[Color] = [Color("#e9964a"), Color("#3fa8a0"), Color("#9a7bd8"), Color("#5b8def")]
const SHAFT_LETTERS := ["A", "B", "C", "D"]
## Each world's signature colour (tabs, chips).
const WORLDS: Array[Color] = [Color("#ef6f6c"), Color("#9a7bd8"), Color("#4fbf9a")]

## Coloured button variations: [face, lip, text].
const BUTTONS := {
	"PrimaryButton": [ACCENT, ACCENT_DARK, Color.WHITE],
	"SkyButton": [SKY, SKY_DARK, Color.WHITE],
	"MintButton": [MINT, MINT_DARK, Color.WHITE],
	"SunButton": [SUN, SUN_DARK, Color.WHITE],
	"GrapeButton": [GRAPE, GRAPE_DARK, Color.WHITE],
}

static var _theme: Theme
static var _fonts := {}


## Fredoka at a given weight (400 regular .. 700 bold).
static func font(weight := 500) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load("res://fonts/Fredoka.ttf")
	var f := FontVariation.new()
	f.base_font = base
	var ts := TextServerManager.get_primary_interface()
	f.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[weight] = f
	return f


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 30

	_button_type(t, "Button", CARD, CARD_LIP, INK)
	t.set_font("font", "Button", font(600))
	t.set_font_size("font_size", "Button", 32)
	for type_name in BUTTONS:
		var c: Array = BUTTONS[type_name]
		t.set_type_variation(type_name, "Button")
		_button_type(t, type_name, c[0], c[1], c[2])
	t.set_font_size("font_size", "PrimaryButton", 38)

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font(650))
	t.set_font_size("font_size", "TitleLabel", 46)
	t.set_type_variation("HugeLabel", "Label")
	t.set_font("font", "HugeLabel", font(700))
	t.set_font_size("font_size", "HugeLabel", 150)
	t.set_type_variation("SoftLabel", "Label")
	t.set_color("font_color", "SoftLabel", INK_SOFT)
	t.set_font_size("font_size", "SoftLabel", 25)

	t.set_stylebox("panel", "PanelContainer", card(36, 30))

	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
			"font_focus_color"]:
		t.set_color(c, "CheckButton", INK)
	t.set_font("font", "CheckButton", font(600))
	t.set_font_size("font_size", "CheckButton", 32)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(s, "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", toggle_icon(true))
	t.set_icon("unchecked", "CheckButton", toggle_icon(false))
	t.set_icon("checked_disabled", "CheckButton", toggle_icon(true))
	t.set_icon("unchecked_disabled", "CheckButton", toggle_icon(false))

	t.set_constant("separation", "VBoxContainer", 18)
	t.set_constant("separation", "HBoxContainer", 14)
	t.set_constant("h_separation", "GridContainer", 18)
	t.set_constant("v_separation", "GridContainer", 18)

	t.set_stylebox("panel", "PopupPanel", card(28, 24))
	t.set_stylebox("panel", "AcceptDialog", card(28, 24))
	t.set_color("font_color", "AcceptDialog", INK)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(INK_SOFT, 0.35)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


static func _button_type(t: Theme, type_name: String, face: Color, lip: Color, text: Color) -> void:
	t.set_stylebox("normal", type_name, pill(face, lip))
	t.set_stylebox("hover", type_name, pill(face.lightened(0.06), lip))
	t.set_stylebox("pressed", type_name, pill(face.darkened(0.04), lip, true))
	t.set_stylebox("hover_pressed", type_name, pill(face.darkened(0.04), lip, true))
	t.set_stylebox("disabled", type_name, pill(face.lerp(BG, 0.5), lip.lerp(BG, 0.5)))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		t.set_color(state, type_name, text)
	t.set_color("font_disabled_color", type_name, Color(text, 0.5))


## A rounded button face sitting on a darker lip; pressed pushes it down.
static func pill(face: Color, lip: Color, pressed := false, radius := 30) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = face
	b.set_corner_radius_all(radius)
	b.border_color = lip
	b.border_width_bottom = 3 if pressed else 9
	b.content_margin_left = 30
	b.content_margin_right = 30
	b.content_margin_top = 20 + (6 if pressed else 0)
	b.content_margin_bottom = 14
	b.anti_aliasing = true
	b.shadow_color = Color(0.35, 0.25, 0.3, 0.08)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 4)
	return b


## A white card with a soft pink shadow.
static func card(radius := 30, padding := 24, color := CARD) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = padding
	b.content_margin_right = padding
	b.content_margin_top = padding
	b.content_margin_bottom = padding
	b.anti_aliasing = true
	b.shadow_color = Color(0.35, 0.25, 0.3, 0.1)
	b.shadow_size = 18
	b.shadow_offset = Vector2(0, 8)
	return b


## Kept for older callers: a flat rounded box.
static func box(color: Color, radius := 16, padding := 18, shadow := false) -> StyleBoxFlat:
	var b := card(radius, padding, color)
	if not shadow:
		b.shadow_size = 0
	return b


static func shaft_color(s: int) -> Color:
	return SHAFTS[s % SHAFTS.size()]


static func world_color(w: int) -> Color:
	return WORLDS[w % WORLDS.size()]


## A pill switch icon for CheckButtons, drawn into an image.
static func toggle_icon(on: bool) -> Texture2D:
	var w := 92
	var h := 52
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := MINT if on else Color("#e6dfe6")
	var r := h * 0.5
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var col := Color(0, 0, 0, 0)
			if d < r:
				col = track
				col.a = clampf(r - d, 0.0, 1.0)
			var kd := p.distance_to(Vector2(knob_x, r))
			if kd < r - 5:
				var k := Color.WHITE
				k.a = clampf(r - 5 - kd, 0.0, 1.0)
				col = col.blend(k)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
