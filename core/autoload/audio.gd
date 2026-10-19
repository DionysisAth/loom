extends Node
## Small synthesized sound kit: wooden clacks for switches, a plucked thread
## for drags, a swish for row ripples and a chime for wins. Every play is
## slightly pitch-varied so repeats never sound mechanical.

const RATE := 22050
const VOICES := 8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_sounds.clack = _wav(_clack())
	_sounds.pluck = _wav(_pluck(196.0, 0.35))
	_sounds.swish = _wav(_swish())
	_sounds.chime = _wav(_chime())
	_sounds.tap = _wav(_tap())
	_sounds.thud = _wav(_thud())
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch_variation := 0.06, volume_db := 0.0) -> void:
	if not Save.get_setting("sound") or not _sounds.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()


## Plays at an exact pitch (for rising note sequences).
func play_at(sound: String, pitch: float, volume_db := 0.0) -> void:
	if not Save.get_setting("sound") or not _sounds.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _samples(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(seconds * RATE))
	return s


## Woodblock: two damped partials plus a tiny noise click.
func _clack() -> PackedFloat32Array:
	var s := _samples(0.12)
	for i in s.size():
		var t := float(i) / RATE
		var body := sin(TAU * 610.0 * t) * exp(-t * 55.0) * 0.55
		body += sin(TAU * 1490.0 * t) * exp(-t * 90.0) * 0.25
		var click := randf_range(-1.0, 1.0) * exp(-t * 900.0) * 0.4
		s[i] = (body + click) * 0.8
	return s


## Karplus-Strong plucked string, like a warp thread snapping taut.
func _pluck(freq: float, seconds: float) -> PackedFloat32Array:
	var s := _samples(seconds)
	var period := int(RATE / freq)
	var buf := PackedFloat32Array()
	buf.resize(period)
	for i in period:
		buf[i] = randf_range(-1.0, 1.0)
	for i in s.size():
		var j := i % period
		var nxt := buf[(j + 1) % period]
		var v := buf[j]
		buf[j] = (v + nxt) * 0.5 * 0.994
		var t := float(i) / RATE
		s[i] = v * 0.5 * minf(1.0, t * 400.0)
	return s


## Soft filtered noise with a rise and fall, the shuttle passing through.
func _swish() -> PackedFloat32Array:
	var s := _samples(0.22)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		lp += (randf_range(-1.0, 1.0) - lp) * (0.08 + 0.2 * t)
		s[i] = lp * sin(PI * t) * 0.9
	return s


## Three soft bell notes rising.
func _chime() -> PackedFloat32Array:
	var s := _samples(1.2)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for n in notes.size():
		var start := int(n * 0.11 * RATE)
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			var env := exp(-t * 3.2) * minf(1.0, t * 300.0)
			var f: float = notes[n]
			s[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.22
	return s


## The beater packing a row: a deep wooden knock.
func _thud() -> PackedFloat32Array:
	var s := _samples(0.25)
	for i in s.size():
		var t := float(i) / RATE
		var body := sin(TAU * 95.0 * t) * exp(-t * 22.0) * 0.7
		body += sin(TAU * 210.0 * t) * exp(-t * 40.0) * 0.25
		var click := randf_range(-1.0, 1.0) * exp(-t * 500.0) * 0.3
		s[i] = body + click
	return s


func _tap() -> PackedFloat32Array:
	var s := _samples(0.05)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = sin(TAU * 880.0 * t) * exp(-t * 120.0) * 0.35
	return s
