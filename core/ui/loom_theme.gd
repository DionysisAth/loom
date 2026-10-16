class_name LoomTheme
extends RefCounted
## Colours and the shared UI theme: warm linen, dark wood and madder red.

const BG := Color("#f2e8d5")
const BG_DEEP := Color("#e6d8bd")
const INK := Color("#3a2a20")
const INK_SOFT := Color("#7a6656")
const WOOD := Color("#6b4a33")
const WOOD_DARK := Color("#4a3022")
const ACCENT := Color("#b8433a")
const ACCENT_DARK := Color("#8f3029")
const GOLD := Color("#e0a537")
const PANEL := Color("#fbf6ec")
const SHAFTS: Array[Color] = [Color("#d08c3a"), Color("#3f8f8a"), Color("#8a5a9e"), Color("#5e7f3a")]
const SHAFT_LETTERS := ["A", "B", "C", "D"]

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 30

	t.set_stylebox("normal", "Button", box(BG_DEEP, 20))
	t.set_stylebox("hover", "Button", box(BG_DEEP.lightened(0.15), 20))
	t.set_stylebox("pressed", "Button", box(BG_DEEP.darkened(0.08), 20))
	t.set_stylebox("disabled", "Button", box(BG_DEEP.lerp(BG, 0.6), 20))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_SOFT.lerp(BG, 0.4))
	t.set_font_size("font_size", "Button", 32)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(ACCENT, 20))
	t.set_stylebox("hover", "PrimaryButton", box(ACCENT.lightened(0.1), 20))
	t.set_stylebox("pressed", "PrimaryButton", box(ACCENT_DARK, 20))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		t.set_color(state, "PrimaryButton", PANEL)
	t.set_font_size("font_size", "PrimaryButton", 36)

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 44)
	t.set_type_variation("HugeLabel", "Label")
	t.set_font_size("font_size", "HugeLabel", 120)
	t.set_color("font_color", "HugeLabel", WOOD_DARK)
	t.set_type_variation("SoftLabel", "Label")
	t.set_color("font_color", "SoftLabel", INK_SOFT)
	t.set_font_size("font_size", "SoftLabel", 24)

	t.set_stylebox("panel", "PanelContainer", box(PANEL, 28, 24, true))

	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_font_size("font_size", "CheckButton", 32)

	t.set_constant("separation", "VBoxContainer", 18)
	t.set_constant("separation", "HBoxContainer", 14)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 16)

	t.set_stylebox("panel", "PopupPanel", box(PANEL, 20, 24, true))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, 20, 24, true))
	t.set_color("font_color", "AcceptDialog", INK)
	_theme = t
	return t


static func box(color: Color, radius := 16, padding := 18, shadow := false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = padding + 6
	b.content_margin_right = padding + 6
	b.content_margin_top = padding
	b.content_margin_bottom = padding
	b.anti_aliasing = true
	if shadow:
		b.shadow_color = Color(0.2, 0.12, 0.05, 0.25)
		b.shadow_size = 14
		b.shadow_offset = Vector2(0, 6)
	return b


static func shaft_color(s: int) -> Color:
	return SHAFTS[s % SHAFTS.size()]
