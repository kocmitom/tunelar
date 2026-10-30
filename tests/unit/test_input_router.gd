extends "res://tests/test_case.gd"


func _key(router: InputRouter, keycode: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.location = location
	router.process_input(ev)


func _axis(router: InputRouter, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	router.process_input(ev)


func _button(router: InputRouter, device: int, button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	router.process_input(ev)


func test_mixed_assignment() -> void:
	var router := InputRouter.new()
	check_eq(router.assign_devices([] as Array[int]), 2, "keyboards only gives 2 players")
	check_eq(router.assign_devices([0, 1, 2, 3, 4] as Array[int]), 6, "capped at 6 players")
	check_eq(router.players[0].device_type, PlayerConfig.DeviceType.KEYBOARD_A, "P1 keyboard A")
	check_eq(router.players[1].device_type, PlayerConfig.DeviceType.KEYBOARD_B, "P2 keyboard B")
	check_eq(router.players[2].device_type, PlayerConfig.DeviceType.JOYPAD, "P3 joypad")
	check_eq(router.players[2].device_index, 0, "P3 joypad 0")
	check_eq(router.players[5].device_index, 3, "P6 joypad 3")
	router.free()


func test_six_joypads_exclusive() -> void:
	var router := InputRouter.new()
	check_eq(router.assign_devices([0, 1, 2, 3, 4, 5] as Array[int]), 6, "six players")
	var ok := true
	for i in 6:
		ok = ok and router.players[i].device_type == PlayerConfig.DeviceType.JOYPAD and router.players[i].device_index == i
	check(ok, "all players on joypads 0-5")
	_key(router, KEY_W, true)
	check_eq(router.get_movement_vector(0), Vector2.ZERO, "keyboard ignored in joypad-only mode")
	router.free()


func test_p1_p3_isolated_vectors() -> void:
	var router := InputRouter.new()
	router.assign_devices([0, 1] as Array[int])
	_key(router, KEY_W, true)
	check_eq(router.get_movement_vector(0), Vector2.UP, "P1 moves up")
	check_eq(router.get_movement_vector(2), Vector2.ZERO, "P3 untouched by keyboard")

	_axis(router, 0, JOY_AXIS_LEFT_X, 0.9)
	check_eq(router.get_movement_vector(2), Vector2(0.9, 0.0), "P3 follows joypad 0")
	check_eq(router.get_movement_vector(0), Vector2.UP, "P1 untouched by joypad")
	check_eq(router.get_movement_vector(3), Vector2.ZERO, "P4 untouched by joypad 0")
	check_eq(router.get_movement_vector(1), Vector2.ZERO, "P2 untouched")

	_axis(router, 0, JOY_AXIS_LEFT_X, 0.3)
	check_eq(router.get_movement_vector(2), Vector2.ZERO, "deadzone")
	_button(router, 1, JOY_BUTTON_DPAD_LEFT, true)
	check_eq(router.get_movement_vector(3), Vector2.LEFT, "P4 d-pad")

	_key(router, KEY_W, false)
	_key(router, KEY_D, true)
	_key(router, KEY_S, true)
	check(router.get_movement_vector(0).is_equal_approx(Vector2(1, 1).normalized()), "P1 diagonal normalized")
	router.free()


func test_sample_latches_taps() -> void:
	var router := InputRouter.new()
	router.assign_devices([0] as Array[int])
	_key(router, KEY_SPACE, true)
	_key(router, KEY_SPACE, false)
	_key(router, KEY_KP_0, true)
	_key(router, KEY_KP_0, false)
	_button(router, 0, JOY_BUTTON_B, true)
	_button(router, 0, JOY_BUTTON_B, false)
	check(not router.is_fire_pressed(0), "tap is no longer held")

	check(router.sample(0)["fire"], "P1 tap reported by sample")
	check(not router.sample(0)["fire"], "P1 tap consumed")
	check(router.sample(1)["fire"], "P2 tap survives P1 sampling")
	check(router.sample(2)["radar"], "P3 joypad radar tap reported")
	check(not router.sample(2)["radar"], "P3 tap consumed")

	_key(router, KEY_SPACE, true)
	check(router.sample(0)["fire"] and router.sample(0)["fire"], "held key fires every sample")
	_key(router, KEY_D, true)
	check_eq(router.sample(0)["move"], Vector2.RIGHT, "sample carries movement")
	router.free()


func test_fire_and_radar() -> void:
	var router := InputRouter.new()
	router.assign_devices([0] as Array[int])
	_key(router, KEY_SPACE, true)
	check(router.is_fire_pressed(0), "P1 fire")
	check(not router.is_fire_pressed(1), "P2 no fire")
	check(not router.is_fire_pressed(2), "P3 no fire")

	_key(router, KEY_SHIFT, true, KEY_LOCATION_LEFT)
	check(not router.is_radar_pressed(1), "left shift is not P2 radar")
	_key(router, KEY_SHIFT, true, KEY_LOCATION_RIGHT)
	check(router.is_radar_pressed(1), "right shift is P2 radar")
	check(not router.is_radar_pressed(0), "P1 no radar")

	_key(router, KEY_KP_0, true)
	check(router.is_fire_pressed(1), "numpad 0 is P2 fire")

	_button(router, 0, JOY_BUTTON_A, true)
	check(router.is_fire_pressed(2), "joy button 0 is P3 fire")
	_button(router, 0, JOY_BUTTON_A, false)
	check(not router.is_fire_pressed(2), "P3 fire released")
	_button(router, 0, JOY_BUTTON_B, true)
	check(router.is_radar_pressed(2), "joy button 1 is P3 radar")
	router.free()
