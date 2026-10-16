extends "res://tests/test_case.gd"


func test_record_and_reload() -> void:
	var save: Node = Engine.get_main_loop().root.get_node("Save")
	var old_path: String = save.path
	save.path = "user://test_save.json"
	save.data = save._fresh()
	check(not save.is_completed("1-1"), "fresh save")
	check(save.record_win("1-1", 2), "first win counts")
	check(not save.record_win("1-1", 1), "worse win does not")
	eq(save.stars("1-1"), 2, "best stars kept")
	check(save.record_win("1-1", 3), "better win counts")
	save.set_setting("colorblind", true)
	save.load_data()
	eq(save.stars("1-1"), 3, "stars persist")
	eq(save.get_setting("colorblind"), true, "settings persist")
	save.reset_progress()
	check(not save.is_completed("1-1"), "reset clears progress")
	eq(save.get_setting("colorblind"), true, "reset keeps settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.path = old_path
	save.load_data()
