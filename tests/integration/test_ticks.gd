extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _make_game(player_count: int) -> GameManager:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.router.assign_devices([] as Array[int])
	gm.setup(player_count)
	return gm


func _press(gm: GameManager, keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	gm.router.process_input(ev)


func test_tick_settings() -> void:
	check_eq(Engine.physics_ticks_per_second, GameManager.TICK_RATE, "physics step is the game tick")
	check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation smooths rendering")
	check_near(GameManager.TICK_DT * GameManager.TICK_RATE, 1.0, 0.000001, "TICK_DT matches TICK_RATE")


func test_step_advances_one_fixed_tick() -> void:
	var gm := _make_game(2)
	var start := gm.tick
	for i in 3:
		gm.step()
	check_eq(gm.tick, start + 3, "each step is one tick")

	var tank := gm.tanks[0]
	var x0 := tank.position.x
	_press(gm, KEY_D, true)
	gm._physics_process(0.5)
	check_eq(gm.tick, start + 4, "a long frame still advances a single tick")
	check_near(tank.position.x - x0, Tank.SPEED_CLEAR * GameManager.TICK_DT, 0.01, "movement uses TICK_DT, not the frame delta")
	gm.manager.free()


func test_tap_between_ticks_fires_once() -> void:
	var gm := _make_game(2)
	# Bases block firing.
	gm.tanks[0].position.y = gm.tanks[0].home_rect.position.y - 5
	var shots := [0]
	gm.tanks[0].fired.connect(func(_t: Tank) -> void: shots[0] += 1)
	_press(gm, KEY_SPACE, true)
	_press(gm, KEY_SPACE, false)
	gm.step()
	check_eq(shots[0], 1, "tap released before the tick still fires")
	for i in GameManager.TICK_RATE:
		gm.step()
	check_eq(shots[0], 1, "tap is consumed by one tick")
	gm.manager.free()


func test_simulate_with_synthetic_inputs() -> void:
	var gm := _make_game(2)
	gm.tanks[0].position.y = gm.tanks[0].home_rect.position.y - 5
	var x0 := gm.tanks[0].position.x
	var p1 := gm.tanks[1].position
	var idle := {"move": Vector2.ZERO, "fire": false}
	var inputs: Array[Dictionary] = [{"move": Vector2.RIGHT, "fire": true}, idle]
	gm.simulate(inputs)
	check(gm.tanks[0].position.x > x0, "tank 0 moved from injected input")
	check_eq(gm.bullets_root.get_child_count(), 1, "tank 0 fired from injected input")
	check_eq(gm.tanks[1].position, p1, "idle tank unchanged")
	gm.manager.free()
