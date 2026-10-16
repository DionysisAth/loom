extends Node
## Gameplay events: level_start, level_complete, hint_used, undo_count,
## quit_mid_level. Logged locally as JSON lines (no network in the MVP) so a
## tester's file can be collected; the quit point shows which levels are hard.

const PATH := "user://analytics.jsonl"
const MAX_BYTES := 512 * 1024

var _session := ""


func _ready() -> void:
	_session = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f and f.get_length() > MAX_BYTES:
			f = null
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	track("session_start", {"version": ProjectSettings.get_setting("application/config/version")})


func track(event: String, params := {}) -> void:
	var entry := {"t": int(Time.get_unix_time_from_system()), "s": _session, "e": event}
	entry.merge(params)
	var line := JSON.stringify(entry)
	print_verbose("[analytics] ", line)
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE if FileAccess.file_exists(PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
