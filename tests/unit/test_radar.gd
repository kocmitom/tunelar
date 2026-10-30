extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")


func _spawn(terrain: TerrainData, pos: Vector2) -> Tank:
	var tank: Tank = TankScene.instantiate()
	tank.terrain = terrain
	tank.position = pos
	tree.root.add_child(tank)
	return tank


func test_points_at_closest_live_enemy() -> void:
	var terrain := TerrainData.new()
	var source := _spawn(terrain, Vector2(100, 100))
	var far := _spawn(terrain, Vector2(150, 100))
	var near := _spawn(terrain, Vector2(100, 70))
	var dead := _spawn(terrain, Vector2(102, 100))
	dead.is_dead = true
	var tanks: Array[Tank] = [source, far, near, dead]

	check(GameManager.get_radar_direction(source, tanks).is_equal_approx(Vector2.UP), "closest live enemy is up")
	near.is_dead = true
	check(GameManager.get_radar_direction(source, tanks).is_equal_approx(Vector2.RIGHT), "falls back to next enemy")
	far.is_dead = true
	check_eq(GameManager.get_radar_direction(source, tanks), Vector2.ZERO, "no enemies gives zero")
	for t in tanks:
		t.free()


func test_radar_cost_and_duration() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(100, 100))
	check(tank.try_radar(), "radar triggers")
	check_eq(tank.energy, Tank.MAX_ENERGY - Tank.ENERGY_COST_RADAR, "radar costs 5")
	check_eq(tank.radar_time, Tank.RADAR_DURATION, "needle shown for 1.5 s")
	check(not tank.try_radar(), "cannot retrigger while active")
	tank.tick(Tank.RADAR_DURATION)
	check_eq(tank.radar_time, 0.0, "needle expires")
	var before := tank.energy
	check(tank.try_radar(), "retrigger after expiry")
	check_eq(tank.energy, before - Tank.ENERGY_COST_RADAR, "second scan costs 5")
	tank.free()
