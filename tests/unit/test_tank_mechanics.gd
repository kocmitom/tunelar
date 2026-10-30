extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")
const DT := 1.0 / 60.0


func _spawn(terrain: TerrainData, pos: Vector2) -> Tank:
	var tank: Tank = TankScene.instantiate()
	tank.terrain = terrain
	tank.position = pos
	tree.root.add_child(tank)
	return tank


func _drive(tank: Tank, dir: Vector2, seconds: float) -> void:
	for i in roundi(seconds / DT):
		tank.step_movement(DT, dir)


func test_clear_tunnel_drain() -> void:
	var terrain := TerrainData.new()
	for x in range(40, 200):
		terrain.dig_circle(x, 100, 5)
	var tank := _spawn(terrain, Vector2(60, 100))
	_drive(tank, Vector2.RIGHT, 1.0)
	check_eq(tank.energy, Tank.MAX_ENERGY, "moving through dug tunnel costs no energy")
	check_near(tank.position.x, 60.0 + Tank.SPEED_CLEAR, 1.0, "clear speed")
	tank.free()


func test_digging_drain() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(60, 100))
	_drive(tank, Vector2.RIGHT, 1.0)
	check_near(Tank.MAX_ENERGY - tank.energy, Tank.ENERGY_DRAIN_DIGGING, 0.1, "digging drain per second")
	check_near(tank.position.x, 60.0 + Tank.SPEED_DIGGING, 1.0, "digging speed")
	check_eq(terrain.get_cell(70, 100), TerrainData.AIR, "tunnel left behind")
	var half_width := tank.tank_radius + Tank.DIG_MARGIN
	check(terrain.get_cell(70, 100 - half_width) == TerrainData.AIR and terrain.get_cell(70, 100 + half_width) == TerrainData.AIR, "tunnel one pixel wider than the tank on each side")
	check(terrain.get_cell(70, 100 - half_width - 1) == TerrainData.DIRT and terrain.get_cell(70, 100 + half_width + 1) == TerrainData.DIRT, "tunnel not wider than that")
	tank.free()


func test_diagonal_digging_drain() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(60, 60))
	_drive(tank, Vector2(1, 1), 1.0)
	check_near(Tank.MAX_ENERGY - tank.energy, Tank.ENERGY_DRAIN_DIGGING, 0.1, "diagonal digging drain")
	tank.free()


func test_idle_and_empty_battery() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(60, 100))
	_drive(tank, Vector2.ZERO, 1.0)
	check_eq(tank.energy, Tank.MAX_ENERGY, "no idle drain")
	tank.energy = 0.0
	_drive(tank, Vector2.RIGHT, 1.0)
	check_near(tank.position.x, 60.0 + Tank.SPEED_DIGGING * Tank.SPEED_FACTOR_EMPTY, 1.0, "empty battery crawls")
	check_eq(tank.energy, 0.0, "energy never goes negative")
	tank.free()


func test_low_energy_slows_digging_only() -> void:
	var terrain := TerrainData.new()
	var full := _spawn(terrain, Vector2(60, 100))
	var low := _spawn(terrain, Vector2(60, 140))
	low.energy = Tank.LOW_ENERGY / 2.0
	full.step_movement(DT, Vector2.RIGHT)
	low.step_movement(DT, Vector2.RIGHT)
	check(low.position.x - 60.0 < full.position.x - 60.0, "low battery digs slower than full")
	check(low.position.x > 60.0, "low battery still digs")
	full.free()
	low.free()

	var tunnels := TerrainData.new()
	for x in range(40, 200):
		tunnels.dig_circle(x, 100, 5)
		tunnels.dig_circle(x, 140, 5)
	var full_t := _spawn(tunnels, Vector2(60, 100))
	var empty_t := _spawn(tunnels, Vector2(60, 140))
	empty_t.energy = 0.0
	full_t.step_movement(DT, Vector2.RIGHT)
	empty_t.step_movement(DT, Vector2.RIGHT)
	check_near(empty_t.position.x, full_t.position.x, 0.001, "empty battery drives full speed in dug tunnels")
	full_t.free()
	empty_t.free()


func test_bedrock_blocks() -> void:
	var terrain := TerrainData.new()
	for y in range(80, 120):
		for x in range(70, 75):
			terrain.cells[y * terrain.width + x] = TerrainData.BEDROCK
	var tank := _spawn(terrain, Vector2(60, 100))
	_drive(tank, Vector2.RIGHT, 2.0)
	check(tank.position.x < 70.0 - tank.tank_radius, "stopped before bedrock")
	check(tank.position.x > 64.0, "moved up to the wall")
	tank.free()


func test_base_recharge() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.home_rect = Rect2i(50, 90, 21, 21)
	tank.energy = 10.0
	for i in 60:
		tank.tick(DT)
	check_near(tank.energy, 10.0 + Tank.ENERGY_RECHARGE_BASE + Tank.ENERGY_REGEN_PASSIVE, 0.1, "recharge rate")
	for i in 240:
		tank.tick(DT)
	check_eq(tank.energy, Tank.MAX_ENERGY, "recharge capped at max")
	tank.energy = 10.0
	tank.position = Vector2(150, 100)
	tank.tick(1.0)
	check_near(tank.energy, 10.0 + Tank.ENERGY_REGEN_PASSIVE, 0.001, "only slow passive regen outside home base")
	tank.free()


func test_passive_regen_revives_empty_battery() -> void:
	var terrain := TerrainData.new()
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.energy = 0.0
	tank.tick(1.0)
	check(tank.energy > 0.0, "empty battery slowly refills")
	var before := tank.position
	tank.step_movement(DT, Vector2.RIGHT)
	check(tank.position != before, "tank can crawl again")
	tank.free()


func test_snap_direction() -> void:
	check_eq(Tank.snap_direction(Vector2(0.9, 0.2)), Vector2.RIGHT, "snap to right")
	check(Tank.snap_direction(Vector2(0.6, 0.5)).is_equal_approx(Vector2(1, 1).normalized()), "snap to diagonal")
	check_eq(Tank.snap_direction(Vector2(0.05, 0.0)), Vector2.ZERO, "tiny input ignored")
