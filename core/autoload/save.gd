extends Node
## One JSON file in user:// with progress (stars per level) and settings.
## Written after every win and every settings change.

signal settings_changed
signal progress_changed

const DEFAULT_PATH := "user://save.json"
const VERSION := 1
const DEFAULT_SETTINGS := {
	"sound": true,
	"haptics": true,
	"colorblind": false,
	"mismatch": true,
}

## Tests point this at a scratch file.
var path := DEFAULT_PATH
var data := {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	data = _fresh()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, starting fresh.")
		return
	if typeof(parsed.get("levels")) == TYPE_DICTIONARY:
		for id in parsed.levels:
			data.levels[str(id)] = int(parsed.levels[id])
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if parsed.settings.has(key):
				data.settings[key] = parsed.settings[key]


func write() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))


func _fresh() -> Dictionary:
	return {"version": VERSION, "levels": {}, "settings": DEFAULT_SETTINGS.duplicate()}


func stars(level_id: String) -> int:
	return int(data.levels.get(level_id, 0))


func is_completed(level_id: String) -> bool:
	return data.levels.has(level_id)


## Stores a win. Returns true if it beat the previous best.
func record_win(level_id: String, star_count: int) -> bool:
	var best := stars(level_id)
	var improved := not is_completed(level_id) or star_count > best
	data.levels[level_id] = max(best, star_count)
	write()
	progress_changed.emit()
	return improved


func completed_count() -> int:
	return data.levels.size()


func total_stars() -> int:
	var n := 0
	for id in data.levels:
		n += int(data.levels[id])
	return n


func get_setting(key: String):
	return data.settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	write()
	settings_changed.emit()


func reset_progress() -> void:
	data.levels = {}
	write()
	progress_changed.emit()
