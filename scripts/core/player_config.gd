class_name PlayerConfig
extends Resource
## Binds one player slot to a physical device.

enum DeviceType { KEYBOARD_A, KEYBOARD_B, JOYPAD }

@export var player_id: int = 0
@export var device_type: DeviceType = DeviceType.KEYBOARD_A
@export var device_index: int = 0


static func create(id: int, type: DeviceType, index: int) -> PlayerConfig:
	var cfg := PlayerConfig.new()
	cfg.player_id = id
	cfg.device_type = type
	cfg.device_index = index
	return cfg
