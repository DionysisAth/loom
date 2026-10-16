class_name PausePanel
extends Overlay
## In-level menu: resume, restart, leave, and quick settings.

signal restart_pressed
signal levels_pressed
signal menu_pressed


func open() -> void:
	clear_body()
	add_label("Paused", &"TitleLabel")
	add_button("Resume", true).pressed.connect(close)
	add_button("Restart").pressed.connect(func(): close(); restart_pressed.emit())
	add_button("Levels").pressed.connect(func(): levels_pressed.emit())
	add_button("Main menu").pressed.connect(func(): menu_pressed.emit())
	SettingsScreen.add_toggles(body)
	show_card()
