class_name SettingsScreen
extends Screen
## Sound, haptics, colourblind threads and progress reset.

const TOGGLES := [
	["sound", "Sound"],
	["haptics", "Vibration"],
	["mismatch", "Show mismatch dots"],
	["colorblind", "Colourblind threads"],
]


func build() -> void:
	add_header("Settings")
	var card := PanelContainer.new()
	content.add_child(card)
	var list := VBoxContainer.new()
	card.add_child(list)
	var spacer_end := Control.new()
	spacer_end.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_toggles(list)
	var note := Label.new()
	note.text = "Colourblind threads add a texture to every thread colour."
	note.theme_type_variation = &"SoftLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	list.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reset progress"
	reset.custom_minimum_size = Vector2(0, 96)
	reset.theme_type_variation = &"PrimaryButton"
	reset.pressed.connect(_confirm_reset)
	list.add_child(reset)
	content.add_child(spacer_end)
	var version := Label.new()
	version.text = "Loom %s · progress and stats stay on this device" % \
			ProjectSettings.get_setting("application/config/version")
	version.theme_type_variation = &"SoftLabel"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(version)


static func add_toggles(parent: Control) -> void:
	for t in TOGGLES:
		var key: String = t[0]
		var check := CheckButton.new()
		check.text = t[1]
		check.button_pressed = bool(Save.get_setting(key))
		check.custom_minimum_size = Vector2(0, 84)
		check.toggled.connect(func(on: bool):
			Save.set_setting(key, on)
			Audio.play("tap", 0.05, -6.0)
			Haptics.tap())
		parent.add_child(check)


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset progress"
	dialog.dialog_text = "Unravel every cloth and start again?"
	dialog.ok_button_text = "Reset"
	dialog.cancel_button_text = "Keep"
	dialog.confirmed.connect(func(): Save.reset_progress())
	add_child(dialog)
	dialog.popup_centered()


func go_back() -> void:
	Screen.goto("res://core/ui/main_menu.tscn")
