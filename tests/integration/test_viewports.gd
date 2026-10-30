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


func test_rebuild_with_fewer_players() -> void:
	var manager := _make_grid(6)
	var gm: GameManager = manager.get_node("GameManager")
	gm.setup(2)
	check_eq(manager.grid.get_child_count(), 2, "rebuilt with two containers")
	check_eq(manager.viewports.size(), 2, "two viewports")
	check_eq(gm.tanks.size(), 2, "two tanks")
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
