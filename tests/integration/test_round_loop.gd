extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _make_game(player_count: int) -> GameManager:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.router.assign_devices([] as Array[int])
	gm.setup(player_count)
	return gm


func _run(gm: GameManager, seconds: float) -> void:
	for i in roundi(seconds * GameManager.TICK_RATE):
		gm.step()


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
	previous = 0
	ok = true
	for s in GameManager.MAP_SIZE_NAMES.size():
		var size := GameManager.map_size_for(4, s)
		ok = ok and size.x * size.y > previous
		previous = size.x * size.y
	check(ok, "S < M < L < XL")
	check_eq(GameManager.map_size_for(2, 1), GameManager.map_size_for(2), "M is the default")
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
			ok = ok and _same_color(gm.renderer.image.get_pixel(rect.get_center().x, rect.get_center().y), c.darkened(TerrainRenderer.BASE_FLOOR_DARKEN))
		check(ok, "round %d: base walls and floor use the owner's color" % round_index)
		gm.start_round(gm.terrain.map_seed + 1)
	gm.manager.free()


func test_input_drives_fire() -> void:
	var gm := _make_game(2)
	# Bases block firing.
	gm.tanks[0].position.y = gm.tanks[0].home_rect.position.y - 5
	_press(gm, KEY_SPACE, true)
	gm.step()
	_press(gm, KEY_SPACE, false)
	check_eq(gm.bullets_root.get_child_count(), 1, "P1 fire spawns a bullet")
	check_eq(gm.tanks[0].energy, Tank.MAX_ENERGY - Tank.ENERGY_COST_FIRE, "P1 paid for the shot")
	check_eq(gm.tanks[1].energy, Tank.MAX_ENERGY, "P2 untouched")
	gm.manager.free()


func test_hud_shows_shields() -> void:
	var gm := _make_game(2)
	gm.tanks[0].hit()
	gm.step()
	var lit := gm.huds[0].shield_segments.filter(func(s: ColorRect) -> bool: return s.modulate.a == 1.0)
	check_eq(lit.size(), Tank.MAX_SHIELDS - 1, "one shield segment dims after a hit")
	var shown := gm.huds[0].shield_segments.filter(func(s: ColorRect) -> bool: return s.visible)
	check_eq(shown.size(), Tank.MAX_SHIELDS, "one segment shown per max shield")
	check(not gm.tanks[0].is_dead, "shield absorbed the hit")
	gm.manager.free()


func test_round_end() -> void:
	var gm := _make_game(2)
	gm.tanks[1].destroy()
	gm.step()
	check(gm.round_over, "round ends with one tank left")
	check_eq(gm.wins[0], 1, "survivor credited")
	check(gm.huds[0].banner.visible and gm.huds[1].banner.visible, "banner on every HUD")
	check_eq(gm.huds[0].banner.text, "PLAYER 1 WINS", "banner text")

	var frozen_pos := gm.tanks[0].global_position
	_press(gm, KEY_D, true)
	_run(gm, 5.0)
	check(gm.round_over, "still frozen until back in the lobby")
	check_eq(gm.tanks[0].global_position, frozen_pos, "movement frozen")
	check(not gm.manager.fogs[0].visible and not gm.manager.fogs[1].visible, "map shown to every player")
	check(gm.manager.round_restart_button.visible, "lobby button shown")
	check_eq(gm.manager.round_restart_button.text, "Lobby", "button returns to the lobby")
	_press(gm, KEY_D, false)
	gm.manager.free()


func test_empty_battery_survives() -> void:
	var gm := _make_game(3)
	gm.tanks[2].position.y = gm.tanks[2].home_rect.end.y + 8
	gm.tanks[2].energy = 0.0
	_run(gm, 1.0)
	check(not gm.tanks[2].is_dead, "drained tank is not eliminated")
	check_near(gm.tanks[2].energy, Tank.ENERGY_REGEN_PASSIVE, 0.01, "drained tank slowly recharges")
	gm.manager.free()
