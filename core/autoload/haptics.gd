extends Node
## Short vibration pulses for taps, thread snaps and wins.


func tap() -> void:
	_pulse(10)


func snap() -> void:
	_pulse(18)


func success() -> void:
	_pulse(45)


func _pulse(ms: int) -> void:
	if not Save.get_setting("haptics"):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
