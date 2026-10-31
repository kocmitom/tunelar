extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _make_grid(player_count: int) -> ViewportManager:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.setup(player_count)
	return manager


func test_six_containers_share_world() -> void:
	var manager := _make_grid(6)
	check_eq(manager.grid.get_child_count(), 6, "six viewport containers")
	check_eq(manager.grid.columns, 3, "3x2 layout")
	var sv1: SubViewport = manager.grid.get_node("SubViewportContainer_1/SubViewport_1")
	var sv2: SubViewport = manager.grid.get_node("SubViewportContainer_2/SubViewport_2")
	check(sv2.world_2d == sv1.world_2d, "SubViewport_2 shares SubViewport_1 world")
	var ok := true
	for i in 6:
		ok = ok and manager.viewports[i].world_2d == sv1.world_2d
		ok = ok and manager.viewports[i].get_camera_2d() == manager.cameras[i]
		ok = ok and manager.viewports[i].get_child(-1) is PlayerHud
	check(ok, "all viewports share the world and own their camera and HUD")
	check(manager.world_root.get_parent() == sv1, "WorldRoot lives in SubViewport_1")
	check_eq(manager.tanks.size(), 6, "six tanks tracked")
	manager.free()


func test_hud_upgrade_icons() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	var hud := gm.huds[0]
	gm.tanks[0].levels = [1, 2, 3, 4]
	hud.update_hud(gm.tanks[0])
	var text := hud.money_label.get_parsed_text()
	check(text.begins_with("$ "), "money first (got %s)" % text)
	check(not (text.contains("SH") or text.contains("EN") or text.contains("SP") or text.contains("RA")), "no two-letter upgrade names")
	check(text.contains("4"), "levels still shown")
	var ok := true
	for i in TerrainRenderer.PAD_ICONS.size():
		var img: Image = PlayerHud._upgrade_icons[i].get_image()
		for y in img.get_height():
			for x in img.get_width():
				var lit: bool = TerrainRenderer.PAD_ICONS[i][y][x] == "#"
				var c := img.get_pixel(x, y)
				ok = ok and (c == Color.WHITE if lit else (c == Color.BLACK or c.a == 0.0))
	check(ok, "icons are the base pad icons in white, outlined in black")
	manager.free()


func test_rebuild_with_fewer_players() -> void:
	var manager := _make_grid(6)
	var gm: GameManager = manager.get_node("GameManager")
	gm.setup(2)
	check_eq(manager.grid.get_child_count(), 2, "rebuilt with two containers")
	check_eq(manager.viewports.size(), 2, "two viewports")
	check_eq(gm.tanks.size(), 2, "two tanks")
	manager.free()


func test_single_local_slot() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	var local_slots: Array[int] = [2]
	gm.setup(3, 7, local_slots)
	check_eq(manager.grid.get_child_count(), 1, "one viewport for the local player")
	check_eq(manager.grid.columns, 1, "full screen")
	check_eq(gm.tanks.size(), 3, "every player still has a tank")
	check_eq(gm.huds.size(), 1, "one HUD")
	check_eq(gm.huds[0].player_id, 2, "HUD belongs to the local slot")
	check_eq(manager.cameras[0].global_position, gm.tanks[2].global_position, "camera follows the local slot's tank")
	manager.free()


func test_cameras_track_own_tank() -> void:
	var manager := _make_grid(6)
	check(manager.cameras[0].get_parent() is SubViewport, "camera is not a tank child")
	manager.update_cameras()
	var cam2_before := manager.cameras[1].global_position
	check_eq(manager.cameras[0].global_position, manager.tanks[0].global_position, "camera 1 on tank 1")
	check_eq(cam2_before, manager.tanks[1].global_position, "camera 2 on tank 2")

	manager.tanks[0].position += Vector2(30, 20)
	manager.update_cameras()
	check_eq(manager.cameras[0].global_position, manager.tanks[0].global_position, "camera 1 follows tank 1")
	check_eq(manager.cameras[1].global_position, cam2_before, "camera 2 unchanged")
	manager.free()


func test_enemy_pads_per_viewport() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	var own := Vector2i(TerrainData.pad_rects(gm.terrain.base_rects[0])[Tank.Special.LASER].get_center())
	var enemy := Vector2i(TerrainData.pad_rects(gm.terrain.base_rects[1])[Tank.Special.LASER].get_center())
	var overlay := manager.pads[0].texture.get_image()
	check_eq(overlay.get_pixelv(own).a, 0.0, "own base keeps the upgrade icons")
	check(overlay.get_pixelv(enemy).a > 0.0, "enemy base shows the switch icons")
	check(manager.pads[1].texture.get_image().get_pixelv(own).a > 0.0, "the other player sees switches in P1's base")
	check(manager.pads[0].visibility_layer == manager.fogs[0].visibility_layer, "overlay drawn only in its viewport")
	manager.free()


func test_sonar() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	manager.update_cameras()
	check(not manager.sonars[0].visible, "no sonar without the radar")
	gm.tanks[0].special = Tank.Special.RADAR
	manager.update_cameras()
	var sonar := manager.sonars[0]
	check(sonar.visible, "sonar shown with the radar")
	check(not manager.sonars[1].visible, "only for that player")
	check_eq(sonar.position, gm.tanks[0].global_position, "sonar on the tank")
	check_eq(sonar.angles.size(), 1, "one other player")
	check_near(sonar.angles[0], (gm.tanks[1].global_position - gm.tanks[0].global_position).angle(), 0.001, "points at the other tank")
	check_near(sonar.distances[0], gm.tanks[0].global_position.distance_to(gm.tanks[1].global_position), 0.001, "knows the distance")
	check_eq(sonar.colors[0], gm.tanks[1].color, "flares in the other tank's color")
	gm.tanks[1].destroy()
	manager.update_cameras()
	check(sonar.angles.is_empty() and sonar.distances.is_empty() and sonar.colors.is_empty(), "dead tanks not tracked")
	manager.free()


func test_dead_player_spectates() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	var cam := manager.cameras[0]
	gm.tanks[0].destroy()
	var dir := Vector2.RIGHT if cam.global_position.x < gm.map_size.x / 2.0 else Vector2.LEFT
	var inputs: Array[Dictionary] = [{"move": dir, "fire": false}, {"move": Vector2.ZERO, "fire": false}]
	var before := cam.global_position
	manager.update_cameras(inputs, 0.5)
	check(not manager.fogs[0].visible, "dead player's fog is hidden")
	check(manager.fogs[1].visible, "live player's fog stays")
	check(cam.global_position.x * dir.x > before.x * dir.x, "dead player's camera pans")
	check(Rect2(Vector2.ZERO, gm.map_size).has_point(cam.global_position), "camera stays inside the map")
	check_eq(manager.cameras[1].global_position, gm.tanks[1].global_position, "camera 2 still follows tank 2")

	gm.start_round(1)
	check(manager.fogs[0].visible, "fog returns next round")
	check_eq(cam.global_position, gm.tanks[0].global_position, "camera back on the respawned tank")
	manager.free()


func test_round_end_shows_map_to_survivor() -> void:
	var manager := _make_grid(2)
	var gm: GameManager = manager.get_node("GameManager")
	var cam := manager.cameras[1]
	gm.tanks[1].kills = GameManager.KILLS_TO_WIN
	gm.tanks[0].destroy()
	gm.step()
	check(gm.round_over, "round over")
	var dir := Vector2.RIGHT if cam.global_position.x < gm.map_size.x / 2.0 else Vector2.LEFT
	var inputs: Array[Dictionary] = [{"move": Vector2.ZERO, "fire": false}, {"move": dir, "fire": false}]
	var before := cam.global_position
	manager.update_cameras(inputs, 0.5)
	check(not manager.fogs[1].visible, "survivor's fog is hidden")
	check(cam.global_position.x * dir.x > before.x * dir.x, "survivor's camera pans")
	manager.free()
