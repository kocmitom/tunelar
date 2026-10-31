extends Node
## Sound effects in the 1991 PC speaker style or a modern synthesized one, all rendered in code at startup.
## Output only: it never touches the simulation, so lockstep stays in sync.

enum Style { OFF, ORIGINAL, MODERN }
enum Kind { FIRE, LASER, DIG, IMPACT, RICOCHET, HIT, DESTROY, BUMP, PICKUP }
enum Filter { LOW, HIGH, BAND }

const RATE := 22050
# One slot of the original's speaker queue, 3 per 18.2 Hz BIOS tick.
const SLOT := 65536.0 / 1193182.0 / 3.0
const VARIANTS := 3
const VOICES := 16
const SQUARE_LEVEL := 0.08
const SYNTH_LEVEL := 0.5
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

var style: int = Style.MODERN
# The local tanks; with none every sound plays at full volume.
var listeners: Array[Tank] = []
# Streams per style, then per kind, one per variant.
var banks := {}
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
	for s in [Style.ORIGINAL, Style.MODERN]:
		var bank := []
		for kind in Kind.values():
			var streams: Array[AudioStreamWAV] = []
			var count := VARIANTS if s == Style.MODERN or kind == Kind.HIT or kind == Kind.DESTROY else 1
			for i in count:
				streams.append(_render_square(kind) if s == Style.ORIGINAL else _render_synth(kind))
			bank.append(streams)
		banks[s] = bank


# pos is the world position of the source; null plays at full volume.
func play(kind: Kind, pos: Variant = null) -> AudioStreamPlayer:
	if style == Style.OFF:
		return null
	var volume := 1.0 if pos == null else volume_at(pos)
	if volume <= 0.0:
		return null
	var now := Time.get_ticks_msec() / 1000.0
	# The original clicks on every dug frame.
	if GAPS.has(kind) and not (kind == Kind.DIG and style == Style.ORIGINAL):
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
	var streams: Array = banks[style][kind]
	player.stream = streams[_rng.randi() % streams.size()]
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD) if style == Style.MODERN else 1.0
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


# The original's QueueSound: frequencies of the speaker queue slots after the current one, 0 is silence.
# LASER, RICOCHET and PICKUP are new, in the same style.
func _queue(kind: Kind) -> PackedInt32Array:
	var q := PackedInt32Array()
	q.resize(256)
	q.fill(0)
	match kind:
		Kind.FIRE:
			q[1] = 5000
		Kind.DIG:
			q[1] = 40
		Kind.IMPACT:
			for i in range(1, 5):
				q[i * 2] = i * 20 + 50
		Kind.BUMP:
			for i in range(1, 4):
				q[i * 2] = 40
				q[i * 2 + 1] = 45
		Kind.HIT, Kind.DESTROY:
			var destroy := kind == Kind.DESTROY
			for i in (40 if destroy else 4):
				var f := 0x100
				var step := _rng.randi_range(0, 0x3FF if destroy else 0x34F)
				for j in range(1, 23 if destroy else 8):
					q[f >> 8] = (step >> 7) * j + 40 if destroy else j * 15 + 40
					f += step
			q[1] = 1000
		Kind.LASER:
			q[1] = 3000
			q[2] = 2000
			q[3] = 1200
		Kind.RICOCHET:
			q[1] = 1500
			q[2] = 2500
		Kind.PICKUP:
			q[1] = 600
			q[2] = 800
			q[3] = 1200
	return q


# One square wave whose frequency changes every slot, like the PC speaker.
func _render_square(kind: Kind) -> AudioStreamWAV:
	var q := _queue(kind)
	var last := 255
	while q[last] == 0:
		last -= 1
	var per_slot := int(SLOT * RATE)
	_buf = PackedFloat32Array()
	_buf.resize(last * per_slot)
	_buf.fill(0.0)
	var phase := 0.0
	for slot in range(1, last + 1):
		var hz := q[slot]
		if hz == 0:
			continue
		for i in per_slot:
			_buf[(slot - 1) * per_slot + i] = 1.0 if phase < 0.5 else -1.0
			phase = fmod(phase + float(hz) / RATE, 1.0)
	return _wav(SQUARE_LEVEL)


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
	var f := f0
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
	var f := f0
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
