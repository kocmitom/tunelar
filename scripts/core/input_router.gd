class_name InputRouter
extends Node
## Tracks raw keyboard/joypad state and exposes uniform per-player actions (move, fire, turn).

const MAX_PLAYERS := 6
const DEADZONE := 0.5
const KEYBOARD_BINDINGS := {
	PlayerConfig.DeviceType.KEYBOARD_A: {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"fire": [KEY_SPACE], "turn_left": [KEY_F], "turn_right": [KEY_H],
	},
	PlayerConfig.DeviceType.KEYBOARD_B: {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"fire": [KEY_ENTER, KEY_KP_0], "turn_left": [KEY_KP_4], "turn_right": [KEY_KP_6],
	},
}
const JOY_FIRE := JOY_BUTTON_A

var players: Array[PlayerConfig] = []
# Turret mode: a lone player aims with A/D and drives with the arrows.
var turret := false
var _keys := {}
var _joy_axes := {}
var _joy_turn := {}
var _joy_buttons := {}
# Presses since the last sample(), so taps shorter than one tick are not lost.
var _keys_latched := {}
var _joy_latched := {}


func _input(event: InputEvent) -> void:
	process_input(event)


func assign_devices(joypads: Array[int]) -> int:
	players.clear()
	if joypads.size() >= MAX_PLAYERS:
		for i in MAX_PLAYERS:
			players.append(PlayerConfig.create(i, PlayerConfig.DeviceType.JOYPAD, joypads[i]))
	else:
		players.append(PlayerConfig.create(0, PlayerConfig.DeviceType.KEYBOARD_A, 0))
		players.append(PlayerConfig.create(1, PlayerConfig.DeviceType.KEYBOARD_B, 0))
		for j in mini(joypads.size(), MAX_PLAYERS - 2):
			players.append(PlayerConfig.create(2 + j, PlayerConfig.DeviceType.JOYPAD, joypads[j]))
	return players.size()


func process_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var id: int = event.physical_keycode
		if event.pressed:
			_keys[id] = true
			_keys_latched[id] = true
		else:
			_keys.erase(id)
	elif event is InputEventJoypadMotion:
		var axes: Vector2 = _joy_axes.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X:
			axes.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y:
			axes.y = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_X:
			_joy_turn[event.device] = event.axis_value
		_joy_axes[event.device] = axes
	elif event is InputEventJoypadButton:
		var button := Vector2i(event.device, event.button_index)
		if event.pressed:
			_joy_buttons[button] = true
			_joy_latched[button] = true
		else:
			_joy_buttons.erase(button)


func get_movement_vector(player_id: int) -> Vector2:
	if player_id >= players.size():
		return Vector2.ZERO
	var cfg := players[player_id]
	if cfg.device_type == PlayerConfig.DeviceType.JOYPAD:
		var axes: Vector2 = _joy_axes.get(cfg.device_index, Vector2.ZERO)
		if axes.length() < DEADZONE:
			axes = Vector2.ZERO
		axes += Vector2(
			_joy(cfg, JOY_BUTTON_DPAD_RIGHT) - _joy(cfg, JOY_BUTTON_DPAD_LEFT),
			_joy(cfg, JOY_BUTTON_DPAD_DOWN) - _joy(cfg, JOY_BUTTON_DPAD_UP))
		return axes.limit_length(1.0)
	var v := Vector2(_key(cfg, "right") - _key(cfg, "left"), _key(cfg, "down") - _key(cfg, "up"))
	return v.limit_length(1.0)


func is_fire_pressed(player_id: int) -> bool:
	return _action(player_id, "fire", JOY_FIRE)


# Turret turn from -1 (counter-clockwise) to 1 (clockwise).
func get_turn(player_id: int) -> float:
	if player_id >= players.size():
		return 0.0
	var cfg := players[player_id]
	if cfg.device_type == PlayerConfig.DeviceType.JOYPAD:
		var turn: float = _joy_turn.get(cfg.device_index, 0.0)
		return turn if absf(turn) >= DEADZONE else 0.0
	return _key(cfg, "turn_right") - _key(cfg, "turn_left")


# Input for one simulation tick. Fire also reports taps since the previous sample.
func sample(player_id: int) -> Dictionary:
	var input := {
		"move": get_movement_vector(player_id),
		"fire": is_fire_pressed(player_id) or _action(player_id, "fire", JOY_FIRE, true),
		"turn": get_turn(player_id),
	}
	if player_id < players.size():
		var cfg := players[player_id]
		if cfg.device_type == PlayerConfig.DeviceType.JOYPAD:
			_joy_latched.erase(Vector2i(cfg.device_index, JOY_FIRE))
		else:
			for keycode in KEYBOARD_BINDINGS[cfg.device_type]["fire"]:
				_keys_latched.erase(keycode)
	return input


# One tick of input for this PC's single LAN player: every assigned device drives it.
func sample_all() -> Dictionary:
	var input := {"move": Vector2.ZERO, "fire": false, "turn": 0.0}
	for cfg in players:
		var s := sample(cfg.player_id)
		if turret and cfg.device_type == PlayerConfig.DeviceType.KEYBOARD_A:
			input["turn"] += signf(s["move"].x)
		else:
			input["move"] += s["move"]
		input["fire"] = input["fire"] or s["fire"]
		input["turn"] += s["turn"]
	input["move"] = input["move"].limit_length(1.0)
	input["turn"] = clampf(input["turn"], -1.0, 1.0)
	return input


# Inputs of this PC's LAN players: a lone player uses every device, otherwise player k uses device k.
func sample_local(count: int) -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	if count == 1:
		inputs.append(sample_all())
		return inputs
	for k in count:
		inputs.append(sample(k))
	return inputs


# Controls of local player k in assign_devices order (fewer than 6 gamepads).
static func device_label(k: int, turret := false) -> String:
	if k == 0:
		return "WASD + F/H + Space" if turret else "WASD + Space"
	if k == 1:
		return "Arrows + Num 4/6 + Enter" if turret else "Arrows + Enter"
	return "Gamepad %d" % (k - 1)


func _action(player_id: int, action: String, joy_button: int, latched: bool = false) -> bool:
	if player_id >= players.size():
		return false
	var cfg := players[player_id]
	if cfg.device_type == PlayerConfig.DeviceType.JOYPAD:
		return _joy(cfg, joy_button, latched) > 0.0
	return _key(cfg, action, latched) > 0.0


func _key(cfg: PlayerConfig, action: String, latched: bool = false) -> float:
	var state := _keys_latched if latched else _keys
	for keycode in KEYBOARD_BINDINGS[cfg.device_type][action]:
		if state.has(keycode):
			return 1.0
	return 0.0


func _joy(cfg: PlayerConfig, button: int, latched: bool = false) -> float:
	var state := _joy_latched if latched else _joy_buttons
	return 1.0 if state.has(Vector2i(cfg.device_index, button)) else 0.0
