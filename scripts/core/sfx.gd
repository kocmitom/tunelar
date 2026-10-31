extends Node
## Synthesized sound effects, all rendered in code at startup.
## Output only: it never touches the simulation, so lockstep stays in sync.

enum Style { OFF, ON }
enum Kind { FIRE, LASER, DIG, IMPACT, RICOCHET, HIT, DESTROY, BUMP, PICKUP }
enum Filter { LOW, HIGH, BAND }

const RATE := 22050
const VARIANTS := 3
const VOICES := 16
const SYNTH_LEVEL := 0.5
# Scales every synthesized frequency.
const PITCH := 0.75
const PITCH_SPREAD := 0.06
# Full volume within NEAR px of the nearest listener, silent beyond FAR.
const NEAR := 60.0
const FAR := 320.0
# Most voices of a kind at once; a new one cuts the oldest.
const VOICE_CAPS := {
	Kind.FIRE: 4, Kind.LASER: 4, Kind.DIG: 2, Kind.IMPACT: 4, Kind.RICOCHET: 3,
	Kind.HIT: 3, Kind.DESTROY: 3, Kind.BUMP: 1, Kind.PICKUP: 2,
}
# Random gap in seconds before the next sound of a kind that repeats every tick.
const GAPS := {Kind.DIG: Vector2(0.12, 0.2), Kind.BUMP: Vector2(0.3, 0.3)}
# Synthesized sound lengths in seconds.
const LENGTHS := {
	Kind.FIRE: 0.32, Kind.LASER: 0.14, Kind.DIG: 0.1, Kind.IMPACT: 0.22, Kind.RICOCHET: 0.13,
	Kind.HIT: 0.66, Kind.DESTROY: 2.33, Kind.BUMP: 0.11, Kind.PICKUP: 0.18,
}

var style: int = Style.ON
# The local tanks; with none every sound plays at full volume.
var listeners: Array[Tank] = []
# Streams per kind, one per variant.
var banks := []
var _players: Array[AudioStreamPlayer] = []
var _kinds := {}
var _next := {}
var _rng := RandomNumberGenerator.new()
var _buf: PackedFloat32Array


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for kind in Kind.values():
		var streams: Array[AudioStreamWAV] = []
		for i in VARIANTS:
			streams.append(_render_synth(kind))
		banks.append(streams)


# pos is the world position of the source; null plays at full volume.
func play(kind: Kind, pos: Variant = null) -> AudioStreamPlayer:
	if style == Style.OFF:
		return null
	var volume := 1.0 if pos == null else volume_at(pos)
	if volume <= 0.0:
		return null
	var now := Time.get_ticks_msec() / 1000.0
	if GAPS.has(kind):
		if now < _next.get(kind, 0.0):
			return null
		var gap: Vector2 = GAPS[kind]
		_next[kind] = now + _rng.randf_range(gap.x, gap.y)
	# _players is kept least recently used first.
	var voices := _players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing and _kinds[p] == kind)
	if voices.size() >= VOICE_CAPS[kind]:
		voices[0].stop()
	var free := _players.filter(func(p: AudioStreamPlayer) -> bool: return not p.playing)
	if free.is_empty():
		return null
	var player: AudioStreamPlayer = free[0]
	_players.erase(player)
	_players.append(player)
	_kinds[player] = kind
	var streams: Array = banks[kind]
	player.stream = streams[_rng.randi() % streams.size()]
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.play()
	return player


func volume_at(pos: Vector2) -> float:
	var nearest := INF
	for tank in listeners:
		if is_instance_valid(tank):
			nearest = minf(nearest, tank.global_position.distance_to(pos))
	if nearest == INF:
		return 1.0
	var f := clampf((FAR - nearest) / (FAR - NEAR), 0.0, 1.0)
	return f * f


# Layers after the realistic style of kaniansky/tunneler (speaker.js); times in seconds.
func _render_synth(kind: Kind) -> AudioStreamWAV:
	_buf = PackedFloat32Array()
	_buf.resize(int(LENGTHS[kind] * RATE))
	_buf.fill(0.0)
	match kind:
		Kind.FIRE:
			_noise(0.0, 0.5, 0.001, 0.04, Filter.HIGH, 2500.0)
			_noise(0.0, 0.9, 0.003, 0.28, Filter.LOW, 1400.0, 250.0)
			_tone(0.0, 1.0, 0.004, 0.3, 120.0, 38.0)
		Kind.LASER:
			_tone(0.0, 0.5, 0.002, 0.12, 1800.0, 300.0, true)
			_noise(0.0, 0.15, 0.001, 0.08, Filter.HIGH, 3000.0)
		Kind.DIG:
			_noise(0.0, 0.8, 0.004, 0.07, Filter.BAND, _rng.randf_range(500.0, 1400.0), _rng.randf_range(300.0, 700.0))
			_noise(0.0, 0.5, 0.01, 0.08, Filter.LOW, 260.0)
		Kind.IMPACT:
			_noise(0.0, 0.55, 0.002, 0.2, Filter.LOW, 1100.0, 300.0)
			_tone(0.0, 0.45, 0.003, 0.16, 85.0, 45.0)
		Kind.RICOCHET:
			var f := _rng.randf_range(2000.0, 2400.0)
			_tone(0.0, 0.35, 0.001, 0.12, f, f * 0.75)
			_tone(0.0, 0.15, 0.001, 0.08, f * 2.76, f * 2.76 * 0.75)
			_noise(0.0, 0.2, 0.001, 0.02, Filter.HIGH, 4000.0)
		Kind.HIT:
			var f := _rng.randf_range(380.0, 460.0)
			for partial in [[1.0, 0.32, 0.65], [2.76, 0.24, 0.45], [5.4, 0.16, 0.3], [8.93, 0.1, 0.2]]:
				_tone(0.0, partial[1], 0.002, partial[2], f * partial[0], f * partial[0])
			_noise(0.0, 0.45, 0.001, 0.035, Filter.HIGH, 3000.0)
			_tone(0.0, 0.5, 0.003, 0.15, 100.0, 50.0)
		Kind.DESTROY:
			_noise(0.0, 1.1, 0.005, 1.7, Filter.LOW, 3200.0, 140.0)
			_tone(0.0, 1.1, 0.008, 1.4, 62.0, 26.0)
			_noise(0.12, 0.3, 0.01, 0.5, Filter.BAND, 1600.0, 500.0)
			_noise(0.0, 0.8, 0.12, 2.2, Filter.LOW, 120.0)
		Kind.BUMP:
			_tone(0.0, 0.55, 0.003, 0.1, 75.0, 48.0)
			_noise(0.0, 0.22, 0.002, 0.06, Filter.LOW, 420.0)
		Kind.PICKUP:
			_tone(0.0, 0.3, 0.003, 0.07, 880.0, 880.0)
			_tone(0.07, 0.3, 0.003, 0.1, 1320.0, 1320.0)
	return _wav(SYNTH_LEVEL)


# Adds a tone gliding f0 -> f1 that rises to peak in a and decays to silence in d more.
func _tone(t: float, peak: float, a: float, d: float, f0: float, f1: float, square := false) -> void:
	var start := int(t * RATE)
	var rise := maxi(1, int(a * RATE))
	var length := rise + int(d * RATE)
	var fall := pow(0.0001, 1.0 / maxf(1.0, d * RATE))
	var glide := pow(f1 / f0, 1.0 / length)
	var f := f0 * PITCH
	var phase := 0.0
	var gain := peak
	for i in mini(length, _buf.size() - start):
		var amp := peak * i / rise
		if i >= rise:
			amp = gain
			gain *= fall
		var wave := sin(phase * TAU)
		if square:
			wave = signf(wave)
		_buf[start + i] += amp * wave
		phase = fmod(phase + f / RATE, 1.0)
		f *= glide


# Adds noise through a one-pole filter whose cutoff glides f0 -> f1, with the envelope of _tone.
func _noise(t: float, peak: float, a: float, d: float, filter: Filter, f0: float, f1: float = 0.0) -> void:
	if f1 == 0.0:
		f1 = f0
	var start := int(t * RATE)
	var rise := maxi(1, int(a * RATE))
	var length := rise + int(d * RATE)
	var fall := pow(0.0001, 1.0 / maxf(1.0, d * RATE))
	var glide := pow(f1 / f0, 1.0 / length)
	var f := f0 * PITCH
	var gain := peak
	var low := 0.0
	var low2 := 0.0
	for i in mini(length, _buf.size() - start):
		var amp := peak * i / rise
		if i >= rise:
			amp = gain
			gain *= fall
		var x := _rng.randf_range(-1.0, 1.0)
		var k := minf(1.0, TAU * f / RATE)
		var y := 0.0
		match filter:
			Filter.LOW:
				low += k * (x - low)
				y = low
			Filter.HIGH:
				low += k * (x - low)
				y = x - low
			Filter.BAND:
				low += minf(1.0, k * 1.4) * (x - low)
				low2 += k / 1.4 * (x - low2)
				y = 2.0 * (low - low2)
		_buf[start + i] += amp * y
		f *= glide


func _wav(level: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(_buf.size() * 2)
	for i in _buf.size():
		data.encode_s16(i * 2, int(clampf(_buf[i] * level, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
