extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")
const DT := 1.0 / 60.0


func _make_game(player_count: int) -> GameManager:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.router.assign_devices([] as Array[int])
	gm.setup(player_count)
	return gm


func _run(gm: GameManager, seconds: float) -> void:
	for i in roundi(seconds / DT):
		gm.step(DT)


func _press(gm: GameManager, keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	gm.router.process_input(ev)


func test_map_grows_with_players() -> void:
	check_eq(GameManager.map_size_for(2), Vector2i(640, 400), "2-player map")
	var previous := 0
	var ok := true
	for n in range(2, 7):
		var size := GameManager.map_size_for(n)
		ok = ok and size.x * size.y > previous
		previous = size.x * size.y
	check(ok, "every extra player enlarges the map")
	var gm := _make_game(6)
	check_eq(Vector2i(gm.terrain.width, gm.terrain.height), GameManager.map_size_for(6), "game uses the scaled size")
	check_eq(gm.manager.cameras[0].limit_right, gm.terrain.width, "camera limits match the map")
	gm.manager.free()


func test_spawn_in_home_bases() -> void:
	var gm := _make_game(6)
	var ok := true
	for i in 6:
		var tank := gm.tanks[i]
		ok = ok and tank.home_rect == gm.terrain.base_rects[i]
		ok = ok and tank.home_rect.has_point(Vector2i(tank.global_position))
		ok = ok and gm.terrain.get_cell(roundi(tank.global_position.x), roundi(tank.global_position.y)) == TerrainData.BASE_START
	check(ok, "every tank starts inside its own base")
	gm.manager.free()


func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_bases_drawn_in_player_color() -> void:
	var gm := _make_game(6)
	for round_index in 2:
		var ok := true
		for i in 6:
			var rect := gm.terrain.base_rects[i]
			var c := GameManager.PLAYER_COLORS[i]
			ok = ok and _same_color(gm.renderer.image.get_pixel(rect.position.x, rect.position.y), c)
			ok = ok and _same_color(gm.renderer.image.get_pixel(rect.position.x + 2, rect.position.y + 2), c.darkened(TerrainRenderer.BASE_FLOOR_DARKEN))
		check(ok, "round %d: base walls and floor use the owner's color" % round_index)
		gm.start_round(gm.terrain.map_seed + 1)
	gm.manager.free()


func test_input_drives_fire_and_radar() -> void:
	var gm := _make_game(2)
	_press(gm, KEY_SPACE, true)
	gm.step(DT)
	_press(gm, KEY_SPACE, false)
	check_eq(gm.bullets_root.get_child_count(), 1, "P1 fire spawns a bullet")
	check_eq(gm.tanks[0].energy, Tank.MAX_ENERGY - Tank.ENERGY_COST_FIRE, "P1 paid for the shot")
	check_eq(gm.tanks[1].energy, Tank.MAX_ENERGY, "P2 untouched")

	_press(gm, KEY_Q, true)
	gm.step(DT)
	var expected := (gm.tanks[1].global_position - gm.tanks[0].global_position).normalized()
	check(gm.tanks[0].radar_dir.is_equal_approx(expected), "radar needle points at P2")
	check(gm.tanks[0].radar_time > 0.0, "radar active")
	gm.manager.free()


func test_round_reset() -> void:
	var gm := _make_game(2)
	var first_seed := gm.terrain.map_seed
	gm.tanks[0].energy = 40.0
	gm.tanks[1].destroy()
	gm.step(DT)
	check(gm.round_over, "round ends with one tank left")
	check_eq(gm.wins[0], 1, "survivor credited")
	check(gm.huds[0].banner.visible and gm.huds[1].banner.visible, "banner on every HUD")
	check_eq(gm.huds[0].banner.text, "PLAYER 1 WINS", "banner text")

	var frozen_pos := gm.tanks[0].global_position
	_press(gm, KEY_D, true)
	_run(gm, 2.5)
	check(gm.round_over, "still frozen before 3 s")
	check_eq(gm.tanks[0].global_position, frozen_pos, "movement frozen")
	_press(gm, KEY_D, false)

	_run(gm, 0.6)
	check(not gm.round_over, "new round after 3 s")
	check(gm.terrain.map_seed != first_seed, "new terrain seed")
	var ok := true
	for i in 2:
		ok = ok and not gm.tanks[i].is_dead and gm.tanks[i].energy == Tank.MAX_ENERGY and gm.tanks[i].visible
		ok = ok and gm.tanks[i].global_position == Vector2(gm.terrain.base_rects[i].get_center())
	check(ok, "tanks respawned in home bases with full energy")
	check(not gm.huds[0].banner.visible, "banner hidden")
	check_eq(gm.wins[0], 1, "wins persist across rounds")
	gm.manager.free()


func test_empty_battery_survives() -> void:
	var gm := _make_game(3)
	gm.tanks[2].position.y = gm.tanks[2].home_rect.end.y + 8
	gm.tanks[2].energy = 0.0
	_run(gm, 1.0)
	check(not gm.tanks[2].is_dead, "drained tank is not eliminated")
	check_near(gm.tanks[2].energy, Tank.ENERGY_REGEN_PASSIVE, 0.01, "drained tank slowly recharges")
	gm.manager.free()
