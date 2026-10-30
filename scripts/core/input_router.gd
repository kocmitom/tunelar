class_name InputRouter
extends Node
## Tracks raw keyboard/joypad state and exposes uniform per-player actions (move, fire, radar).

const MAX_PLAYERS := 6
const DEADZONE := 0.5
const KEY_RIGHT_SHIFT := -KEY_SHIFT
const KEYBOARD_BINDINGS := {
	PlayerConfig.DeviceType.KEYBOARD_A: {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"fire": [KEY_SPACE], "radar": [KEY_Q],
	},
	PlayerConfig.DeviceType.KEYBOARD_B: {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"fire": [KEY_ENTER, KEY_KP_0], "radar": [KEY_RIGHT_SHIFT],
	},
}
const JOY_FIRE := JOY_BUTTON_A
const JOY_RADAR := JOY_BUTTON_B

var players: Array[PlayerConfig] = []
var _keys := {}
var _joy_axes := {}
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
		var id := _key_id(event)
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


func is_radar_pressed(player_id: int) -> bool:
	return _action(player_id, "radar", JOY_RADAR)


# Input for one simulation tick. Fire/radar also report taps since the previous sample.
func sample(player_id: int) -> Dictionary:
	var input := {
		"move": get_movement_vector(player_id),
		"fire": is_fire_pressed(player_id) or _action(player_id, "fire", JOY_FIRE, true),
		"radar": is_radar_pressed(player_id) or _action(player_id, "radar", JOY_RADAR, true),
	}
	if player_id < players.size():
		var cfg := players[player_id]
		if cfg.device_type == PlayerConfig.DeviceType.JOYPAD:
			_joy_latched.erase(Vector2i(cfg.device_index, JOY_FIRE))
			_joy_latched.erase(Vector2i(cfg.device_index, JOY_RADAR))
		else:
			for keycode in KEYBOARD_BINDINGS[cfg.device_type]["fire"] + KEYBOARD_BINDINGS[cfg.device_type]["radar"]:
				_keys_latched.erase(keycode)
	return input


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


func _key_id(event: InputEventKey) -> int:
	if event.physical_keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
		return KEY_RIGHT_SHIFT
	return event.physical_keycode
