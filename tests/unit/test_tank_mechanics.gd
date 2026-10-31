extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")
const DT := GameManager.TICK_DT


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
	terrain.base_rects = [Rect2i(50, 90, 21, 21), Rect2i(200, 90, 21, 21)]
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.home_rect = terrain.base_rects[0]
	tank.energy = 10.0
	for i in GameManager.TICK_RATE:
		tank.tick(DT)
	check_near(tank.energy, 10.0 + Tank.ENERGY_RECHARGE_BASE + Tank.ENERGY_REGEN_PASSIVE, 0.1, "recharge rate")
	for i in 4 * GameManager.TICK_RATE:
		tank.tick(DT)
	check_eq(tank.energy, Tank.MAX_ENERGY, "recharge capped at max")
	tank.energy = 10.0
	tank.position = Vector2(150, 100)
	tank.tick(1.0)
	check_near(tank.energy, 10.0 + Tank.ENERGY_REGEN_PASSIVE, 0.001, "only slow passive regen outside bases")
	tank.energy = 10.0
	tank.position = Vector2(210, 100)
	tank.tick(1.0)
	check_near(tank.energy, 10.0 + Tank.ENERGY_RECHARGE_BASE + Tank.ENERGY_REGEN_PASSIVE, 0.001, "recharges in another player's base")
	tank.free()


func test_base_recharges_shields() -> void:
	var terrain := TerrainData.new()
	terrain.base_rects = [Rect2i(50, 90, 21, 21)]
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.shields = 0.0
	tank.energy = 0.0
	tank.hit()
	check(tank.is_dead, "a hit with no full shield destroys")
	tank.home_rect = terrain.base_rects[0]
	tank.respawn(tank.position)
	tank.shields = 0.0
	tank.energy = 0.0
	for i in 2 * GameManager.TICK_RATE:
		tank.tick(DT)
	check_near(tank.shields / Tank.MAX_SHIELDS, tank.energy / Tank.MAX_ENERGY, 0.02, "shields refill at the battery's pace")
	for i in 3 * GameManager.TICK_RATE:
		tank.tick(DT)
	check_eq(tank.shields, Tank.MAX_SHIELDS, "shields capped at max")
	tank.shields = 1.0
	tank.position = Vector2(150, 100)
	tank.tick(1.0)
	check_eq(tank.shields, 1.0, "no shield recharge outside bases")
	tank.free()


func test_digging_earns_money() -> void:
	var terrain := TerrainData.new(800, 200)
	var tank := _spawn(terrain, Vector2(60, 100))
	_drive(tank, Vector2.RIGHT, 1.0)
	var dug := tank.money
	check(dug > 0, "digging earns money")
	_drive(tank, Vector2.LEFT, 0.3)
	check_eq(tank.money, dug, "driving through a dug tunnel earns nothing")
	tank.energy = Tank.MAX_ENERGY
	tank.money = 0
	_drive(tank, Vector2.RIGHT, 14.0)
	check_eq(tank.energy, 0.0, "battery drained")
	check_near(tank.money, Tank.UPGRADE_COST, Tank.UPGRADE_COST * 0.1, "one full battery of digging pays for a level 1 upgrade")
	tank.free()


func test_digging_energy_recharges() -> void:
	var terrain := TerrainData.new()
	for y in range(90, 111):
		for x in range(70, 90):
			terrain.cells[y * terrain.width + x] = TerrainData.ENERGY
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.energy = 20.0
	_drive(tank, Vector2.RIGHT, 1.0)
	check(tank.energy > 20.0 + 10.0 * TerrainData.ENERGY_VALUE, "dug energy cells recharge the battery")
	tank.energy = tank.max_energy() - 1.0
	_drive(tank, Vector2.RIGHT, 0.5)
	check(tank.energy <= tank.max_energy(), "energy capped at the battery size")
	tank.free()


# Drives off the pad (to the base center) and back onto it.
func _visit(tank: Tank, pad: Vector2) -> void:
	tank.position = Vector2(tank.home_rect.get_center())
	tank.tick(DT)
	tank.position = pad
	tank.tick(DT)


func test_home_pads_buy_upgrades() -> void:
	var terrain := TerrainData.new()
	var home := Rect2i(20, 20, TerrainData.BASE_SIZE, TerrainData.BASE_SIZE)
	var other := Rect2i(150, 20, TerrainData.BASE_SIZE, TerrainData.BASE_SIZE)
	terrain.base_rects = [home, other]
	var tank := _spawn(terrain, Vector2(home.get_center()))
	tank.home_rect = home
	var pad := Vector2(TerrainData.pad_rects(home)[Tank.Upgrade.SHIELD].get_center())

	tank.money = Tank.UPGRADE_COST - 1
	_visit(tank, pad)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 0, "level 1 not affordable")
	tank.money = 3 * Tank.UPGRADE_COST
	tank.tick(DT)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 0, "staying on the pad buys nothing")
	_visit(tank, pad)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 1, "level 1 bought")
	check_eq(tank.money, 2 * Tank.UPGRADE_COST, "level 1 costs one UPGRADE_COST")
	tank.tick(DT)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 1, "one level per visit")
	_visit(tank, pad)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 2, "level 2 bought")
	check_eq(tank.money, 0, "level 2 costs two UPGRADE_COST")
	check_eq(tank.max_shields(), Tank.MAX_SHIELDS + 2, "each shield level adds a shield")
	check_eq(tank.levels, [2, 0, 0, 0] as Array[int], "only the shield pad upgraded")

	tank.money = 100 * Tank.UPGRADE_COST
	tank.position = Vector2(TerrainData.pad_rects(other)[Tank.Upgrade.SHIELD].get_center())
	tank.tick(DT)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], 2, "pads in other bases do nothing")
	for i in 10:
		_visit(tank, pad)
	check_eq(tank.levels[Tank.Upgrade.SHIELD], Tank.MAX_LEVEL, "levels cap at MAX_LEVEL")

	var money := tank.money
	tank.respawn(Vector2(home.get_center()))
	check_eq(tank.money, money, "respawn keeps money")
	check_eq(tank.levels, [Tank.MAX_LEVEL, 0, 0, 0] as Array[int], "respawn keeps upgrades")
	check_eq(tank.shields, tank.max_shields(), "respawn fills the upgraded shields")
	tank.free()


func test_enemy_pads_switch_specials() -> void:
	var terrain := TerrainData.new()
	var home := Rect2i(20, 20, TerrainData.BASE_SIZE, TerrainData.BASE_SIZE)
	var other := Rect2i(150, 20, TerrainData.BASE_SIZE, TerrainData.BASE_SIZE)
	terrain.base_rects = [home, other]
	var tank := _spawn(terrain, Vector2(other.get_center()))
	tank.home_rect = home
	var pads := TerrainData.pad_rects(other)

	tank.position = Vector2(pads[Tank.Special.LASER].get_center())
	tank.tick(DT)
	check_eq(tank.special, Tank.Special.LASER, "enemy pad selects its special")
	check_eq(tank.levels, [0, 0, 0, 0] as Array[int], "enemy pads buy no upgrades")
	tank.tick(DT)
	check_eq(tank.special, Tank.Special.LASER, "staying on the pad keeps it")
	tank.position = Vector2(pads[Tank.Special.JELLY].get_center())
	tank.tick(DT)
	check_eq(tank.special, Tank.Special.JELLY, "another pad replaces the special")
	_visit(tank, Vector2(pads[Tank.Special.JELLY].get_center()))
	check_eq(tank.special, -1, "the active pad switches it off")
	_visit(tank, Vector2(pads[Tank.Special.RADAR].get_center()))

	tank.money = 100 * Tank.UPGRADE_COST
	tank.position = Vector2(TerrainData.pad_rects(home)[Tank.Upgrade.SPEED].get_center())
	tank.tick(DT)
	check_eq(tank.special, Tank.Special.RADAR, "home pads keep the special")
	tank.respawn(Vector2(home.get_center()))
	check_eq(tank.special, Tank.Special.RADAR, "respawn keeps the special")
	tank.free()


func test_jelly_slows_others() -> void:
	var terrain := TerrainData.new()
	for x in range(40, 280):
		terrain.dig_circle(x, 100, 5)
	var jelly := Jelly.new()
	jelly.reset(Vector2i(terrain.width, terrain.height))
	var layer := _spawn(terrain, Vector2(100, 100))
	layer.jelly = jelly
	layer.special = Tank.Special.JELLY
	layer.color = Color.RED
	var follower := _spawn(terrain, Vector2(60, 100))
	follower.jelly = jelly
	follower.player_id = 1
	for i in GameManager.TICK_RATE:
		jelly.step()
		layer.step_movement(DT, Vector2.RIGHT)
	check_near(layer.position.x, 100.0 + Tank.SPEED_CLEAR, 1.0, "own jelly does not slow")
	var cell := jelly.image.get_pixel(130, 100)
	check(cell.r == 1.0 and cell.g == 0.0, "jelly in the owner's color")
	check_near(cell.a, Jelly.ALPHA, 0.01, "jelly half transparent")
	follower.position = Vector2(120, 100)
	_drive(follower, Vector2.RIGHT, 0.5)
	check_near(follower.position.x, 120.0 + Tank.SPEED_DIGGING * 0.5, 1.0, "other jelly slows to digging speed")
	check_eq(follower.energy, Tank.MAX_ENERGY, "jelly costs no energy")
	for i in Jelly.LIFETIME_TICKS:
		jelly.step()
	follower.position = Vector2(120, 100)
	_drive(follower, Vector2.RIGHT, 0.25)
	check_near(follower.position.x, 120.0 + Tank.SPEED_CLEAR * 0.25, 1.0, "jelly gone after 5 s")
	layer.free()
	follower.free()
	jelly.free()


func test_upgrade_effects() -> void:
	var terrain := TerrainData.new()
	for x in range(40, 200):
		terrain.dig_circle(x, 100, 5)
	var tank := _spawn(terrain, Vector2(60, 100))
	tank.levels = [2, 2, 2, 2]
	check_eq(tank.reveal_radius(), roundi(FogOfWar.reveal_radius(tank.tank_radius) * 1.5), "two radar levels see 50% farther")
	_drive(tank, Vector2.RIGHT, 1.0)
	check_near(tank.position.x, 60.0 + Tank.SPEED_CLEAR * 1.5, 1.0, "two speed levels drive 50% faster")
	terrain.base_rects = [Rect2i(0, 0, terrain.width, terrain.height)]
	tank.energy = 0.0
	tank.shields = 0.0
	tank.tick(20.0)
	check_eq(tank.energy, Tank.MAX_ENERGY * 2.0, "two energy levels double the battery")
	check_eq(tank.shields, Tank.MAX_SHIELDS + 2, "two shield levels add two shields")
	tank.energy = 0.0
	tank.tick(1.0)
	check_near(tank.energy, 2.0 * Tank.ENERGY_RECHARGE_BASE + Tank.ENERGY_REGEN_PASSIVE, 0.001, "a bigger battery refills in the same time")
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
