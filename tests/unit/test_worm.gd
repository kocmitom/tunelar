extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")
const DT := GameManager.TICK_DT


func _worm(terrain: TerrainData, pos: Vector2, tanks: Array[Tank] = []) -> Worm:
	var worm := Worm.new()
	worm.terrain = terrain
	worm.tanks = tanks
	worm.dormant = 0
	tree.root.add_child(worm)
	worm.spawn(pos)
	return worm


func _corridor() -> TerrainData:
	var terrain := TerrainData.new()
	for x in range(40, 200):
		terrain.dig_circle(x, 100, 5)
	return terrain


func _run(worm: Worm, seconds: float) -> void:
	for i in roundi(seconds / DT):
		worm.step(DT)


func _chunk_sum(terrain: TerrainData) -> int:
	var total := 0
	for count in terrain.air_chunks:
		total += count
	return total


func test_air_chunks() -> void:
	var terrain := TerrainData.new()
	check_eq(_chunk_sum(terrain), 0, "no air in fresh dirt")
	terrain.dig_circle(40, 40, 3)
	terrain.dig_circle(100, 50, 6)
	check_eq(_chunk_sum(terrain), terrain.cells.count(TerrainData.AIR), "chunks count every dug cell")
	check_eq(terrain.air_chunks[2 * terrain.chunk_cols + 2], 29, "the radius 3 dent sits in chunk (2, 2)")
	terrain.fill_circle(40, 40, 5)
	check_eq(terrain.get_cell(40, 40), TerrainData.DIRT, "filled back to dirt")
	check_eq(terrain.air_chunks[2 * terrain.chunk_cols + 2], 0, "fill empties the chunk")
	check_eq(_chunk_sum(terrain), terrain.cells.count(TerrainData.AIR), "chunks still match after the fill")


func test_swims_without_digging() -> void:
	var terrain := TerrainData.new()
	var worm := _worm(terrain, Vector2(100, 100))
	_run(worm, 4.0)
	check(worm.body[0].distance_to(Vector2(100, 100)) > 20.0, "worm moved (head at %s)" % worm.body[0])
	check_eq(terrain.cells.count(TerrainData.AIR), 0, "no dirt dug")
	check(worm.visible, "awake worm shown")
	worm.free()


func test_refills_corridor() -> void:
	var terrain := _corridor()
	var before := terrain.cells.count(TerrainData.AIR)
	var worm := _worm(terrain, Vector2(60, 100))
	worm.step(DT)
	check_eq(terrain.get_cell(60, 100), TerrainData.DIRT, "tunnel under the tail refilled")
	check_eq(terrain.get_cell(60, 100 + Worm.FILL_RADIUS), TerrainData.DIRT, "refilled up to FILL_RADIUS")
	check_eq(terrain.get_cell(60, 100 + Worm.FILL_RADIUS + 1), TerrainData.AIR, "tunnel edge beyond FILL_RADIUS stays open")
	_run(worm, 3.0)
	check(terrain.cells.count(TerrainData.AIR) < before, "less air after the worm")
	worm.free()


func test_touch_destroys_tank() -> void:
	var terrain := _corridor()
	var tank: Tank = TankScene.instantiate()
	tank.terrain = terrain
	tank.position = Vector2(100, 100)
	tree.root.add_child(tank)
	var worm := _worm(terrain, Vector2(94, 100), [tank] as Array[Tank])
	worm.dormant = 1
	worm.step(DT)
	check(not tank.is_dead, "a dormant worm is harmless")
	check(not worm.visible, "a dormant worm is hidden")
	worm.step(DT)
	check(tank.is_dead, "touching the worm destroys the tank")
	check_eq(tank.shields, Tank.MAX_SHIELDS, "shields do not help")
	check_eq(tank.kills, 0, "no kill credited")
	worm.free()
	tank.free()


func test_targets_dug_pocket() -> void:
	var terrain := TerrainData.new()
	terrain.dig_circle(250, 150, 12)
	terrain.dig_circle(60, 50, 2)
	var worm := _worm(terrain, Vector2(50, 50))
	check(worm.best_target().distance_to(Vector2(250, 150)) < TerrainData.CHUNK, "heads for the big pocket (got %s)" % worm.best_target())
	terrain.base_rects = [Rect2i(234, 134, 33, 33)]
	check(worm.best_target().distance_to(Vector2(60, 50)) < TerrainData.CHUNK, "skips the pocket at a base (got %s)" % worm.best_target())
	terrain.base_rects = []
	terrain.fill_circle(250, 150, 12)
	terrain.fill_circle(60, 50, 2)
	check(worm.best_target().distance_to(worm.body[0] + worm.heading * TerrainData.CHUNK * 4) < 0.01, "no air heads straight on")
	worm.free()


func test_avoids_bedrock_and_bases() -> void:
	var terrain := TerrainData.new()
	for y in range(60, 141):
		for x in range(100, 104):
			terrain.cells[y * terrain.width + x] = TerrainData.BEDROCK
	terrain.base_rects = [Rect2i(150, 84, 33, 33)]
	terrain.dig_circle(140, 100, 6)
	var worm := _worm(terrain, Vector2(60, 100))
	var ok := true
	for i in roundi(10.0 / DT):
		worm.step(DT)
		var head := worm.body[0]
		ok = ok and terrain.is_circle_passable(roundi(head.x), roundi(head.y), Worm.RADIUS)
		ok = ok and not Rect2(terrain.base_rects[0]).grow(Worm.BASE_CLEARANCE).has_point(head)
	check(ok, "head never enters bedrock or a base no-go zone")
	check(worm.body[0].distance_to(Vector2(60, 100)) > 20.0, "worm found a way (head at %s)" % worm.body[0])
	worm.free()
