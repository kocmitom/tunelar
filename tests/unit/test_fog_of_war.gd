extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _revealed(fog: FogOfWar, pos: Vector2) -> bool:
	return fog.image.get_pixel(roundi(pos.x), roundi(pos.y)).a == 0.0


# Explored but out of view: the terrain as last seen, dimmed.
func _explored(fog: FogOfWar, pos: Vector2) -> bool:
	var p := Vector2i(roundi(pos.x), roundi(pos.y))
	var d := fog.image.get_pixelv(p) - fog.terrain_image.get_pixelv(p).lerp(FogOfWar.COLOR_FOG, FogOfWar.EXPLORED_DIM)
	return maxf(maxf(absf(d.r), absf(d.g)), maxf(absf(d.b), absf(d.a))) < 0.01


func test_reveal_circle_stays_explored() -> void:
	var fog := FogOfWar.new()
	var terrain := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	terrain.fill(TerrainRenderer.DIRT_COLORS[0])
	var pads := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	pads.set_pixel(52, 50, Color.RED)
	fog.reset(terrain, pads)
	var r := FogOfWar.reveal_radius(3)
	check_eq(r, 14, "4 tank sizes across")
	check(not _revealed(fog, Vector2(50, 50)), "starts dark")
	fog.reveal(Vector2(50, 50), r)
	check(_revealed(fog, Vector2(50, 50)), "center revealed")
	check(_revealed(fog, Vector2(50 + r, 50)), "edge revealed")
	check(not _revealed(fog, Vector2(50 + r + 1, 50)), "outside the circle stays dark")
	check(not _revealed(fog, Vector2(60, 60)), "circle, not square")
	fog.reveal(Vector2(50 + 2 * r, 50), r)
	check(_revealed(fog, Vector2(50, 50)), "explored area within sight stays clear")
	check(not _revealed(fog, Vector2(50, 50 + r + 2)) and not _explored(fog, Vector2(50, 50 + r + 2)), "unexplored area within sight stays dark")
	fog.reveal(Vector2(95, 95), r)
	check(_explored(fog, Vector2(50, 50)), "area out of sight shows dimmed terrain")
	var d := fog.image.get_pixel(52, 50) - Color.RED.lerp(FogOfWar.COLOR_FOG, FogOfWar.EXPLORED_DIM)
	check(maxf(maxf(absf(d.r), absf(d.g)), absf(d.b)) < 0.01, "pad overlay replaces the terrain as last seen")
	check(not _explored(fog, Vector2(20, 20)), "unexplored area stays dark")
	check(_revealed(fog, Vector2(95, 95)), "new view is clear")
	fog.reveal(Vector2(50 + 2 * r, 50), r)
	check(_revealed(fog, Vector2(50, 50)), "explored area back in sight is clear again")
	fog.reveal(Vector2(0, 0), r)
	check(_revealed(fog, Vector2(0, 0)), "reveal clipped at the map edge")
	check(_explored(fog, Vector2(95, 95)), "previous view becomes explored")
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
	check(_revealed(fog0, gm.tanks[0].global_position + Vector2(spawn_r * 1.5, 0)), "spawn reveal is wider, within sight")
	check(not _revealed(fog0, gm.tanks[1].global_position), "P1 does not see P2's base")
	check(_revealed(fog1, gm.tanks[1].global_position), "P2 sees around its tank")
	check(manager.viewports[0].canvas_cull_mask & fog0.visibility_layer != 0, "viewport 1 draws fog 1")
	check(manager.viewports[0].canvas_cull_mask & fog1.visibility_layer == 0, "viewport 1 skips fog 2")
	fog0.reveal(Vector2(5, 5), 3)
	gm.start_round(gm.terrain.map_seed + 1)
	check(not _revealed(fog0, Vector2(5, 5)) and not _explored(fog0, Vector2(5, 5)), "new round resets the fog")
	check(_revealed(fog0, gm.tanks[0].global_position), "new round reveals the new spawn")
	manager.free()
