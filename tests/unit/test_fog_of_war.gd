extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _revealed(fog: FogOfWar, pos: Vector2) -> bool:
	return fog.image.get_pixel(roundi(pos.x), roundi(pos.y)).a == 0.0


func test_reveal_circle_stays_revealed() -> void:
	var fog := FogOfWar.new()
	fog.reset(Vector2i(100, 100))
	var r := FogOfWar.reveal_radius(3)
	check_eq(r, 14, "4 tank sizes across")
	check(not _revealed(fog, Vector2(50, 50)), "starts dark")
	fog.reveal(Vector2(50, 50), r)
	check(_revealed(fog, Vector2(50, 50)), "center revealed")
	check(_revealed(fog, Vector2(50 + r, 50)), "edge revealed")
	check(not _revealed(fog, Vector2(50 + r + 1, 50)), "outside the circle stays dark")
	check(not _revealed(fog, Vector2(60, 60)), "circle, not square")
	fog.reveal(Vector2(80, 80), r)
	check(_revealed(fog, Vector2(50, 50)), "explored area stays revealed")
	fog.reveal(Vector2(0, 0), r)
	check(_revealed(fog, Vector2(0, 0)), "reveal clipped at the map edge")
	fog.free()


func test_each_viewport_sees_own_fog() -> void:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.setup(2)
	var fog0 := manager.fogs[0]
	var fog1 := manager.fogs[1]
	check(_revealed(fog0, gm.tanks[0].global_position), "P1 sees around its tank")
	var spawn_r := gm.tanks[0].reveal_radius()
	check(_revealed(fog0, gm.tanks[0].global_position + Vector2(spawn_r * 1.5, 0)), "spawn reveal is wider")
	check(not _revealed(fog0, gm.tanks[1].global_position), "P1 does not see P2's base")
	check(_revealed(fog1, gm.tanks[1].global_position), "P2 sees around its tank")
	check(manager.viewports[0].canvas_cull_mask & fog0.visibility_layer != 0, "viewport 1 draws fog 1")
	check(manager.viewports[0].canvas_cull_mask & fog1.visibility_layer == 0, "viewport 1 skips fog 2")
	fog0.reveal(Vector2(5, 5), 3)
	gm.start_round(gm.terrain.map_seed + 1)
	check(not _revealed(fog0, Vector2(5, 5)), "new round resets the fog")
	check(_revealed(fog0, gm.tanks[0].global_position), "new round reveals the new spawn")
	manager.free()
