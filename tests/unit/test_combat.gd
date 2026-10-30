extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")
const BulletScene := preload("res://scenes/combat/bullet.tscn")
const DT := GameManager.TICK_DT


func _corridor() -> TerrainData:
	var terrain := TerrainData.new()
	for x in range(40, 200):
		terrain.dig_circle(x, 100, 5)
	return terrain


func _wall(terrain: TerrainData, x0: int) -> void:
	for y in range(90, 111):
		for x in range(x0, x0 + 5):
			terrain.cells[y * terrain.width + x] = TerrainData.BEDROCK


func _bullet(terrain: TerrainData, pos: Vector2, velocity: Vector2, tanks: Array[Tank] = [], shooter: Tank = null) -> Bullet:
	var bullet: Bullet = BulletScene.instantiate()
	bullet.terrain = terrain
	bullet.position = pos
	bullet.velocity = velocity
	bullet.tanks = tanks
	bullet.shooter = shooter
	tree.root.add_child(bullet)
	return bullet


func _spawn(terrain: TerrainData, pos: Vector2) -> Tank:
	var tank: Tank = TankScene.instantiate()
	tank.terrain = terrain
	tank.position = pos
	tree.root.add_child(tank)
	return tank


func _run(bullet: Bullet, seconds: float) -> void:
	for i in roundi(seconds / DT):
		bullet.step(DT)


func test_ricochet_off_bedrock() -> void:
	var terrain := _corridor()
	_wall(terrain, 150)
	var bullet := _bullet(terrain, Vector2(100, 100), Vector2(Bullet.BULLET_SPEED, 0))
	_run(bullet, 0.5)
	check(not bullet.is_dead, "bullet survives first bounce")
	check_eq(bullet.bounces, 1, "one bounce")
	check(bullet.velocity.is_equal_approx(Vector2(-Bullet.BULLET_SPEED, 0)), "0 degree shot reflects to 180 degrees (got %s)" % bullet.velocity)
	check(bullet.global_position.x < 150.0, "bullet moving back")
	bullet.free()


func test_bullet_dies_after_two_bounces() -> void:
	var terrain := _corridor()
	_wall(terrain, 150)
	_wall(terrain, 55)
	var bullet := _bullet(terrain, Vector2(100, 100), Vector2(Bullet.BULLET_SPEED, 0))
	_run(bullet, 2.0)
	check(bullet.is_dead, "bullet dies on third wall hit")
	check_eq(bullet.bounces, Bullet.MAX_BOUNCES, "two bounces used")


func test_diagonal_bounce() -> void:
	var terrain := _corridor()
	var bullet := _bullet(terrain, Vector2(100, 100), Vector2(1, 1).normalized() * Bullet.BULLET_SPEED)
	for y in range(103, 110):
		for x in range(90, 130):
			terrain.cells[y * terrain.width + x] = TerrainData.BEDROCK
	_run(bullet, DT)
	check(bullet.velocity.y < 0.0 and bullet.velocity.x > 0.0, "floor flips only the vertical component (got %s)" % bullet.velocity)
	bullet.free()


func test_dirt_dent() -> void:
	var terrain := TerrainData.new()
	var bullet := _bullet(terrain, Vector2(100, 100), Vector2(Bullet.BULLET_SPEED, 0))
	bullet.step(DT)
	check(bullet.is_dead, "bullet dies in dirt")
	check_eq(terrain.get_cell(101, 100), TerrainData.AIR, "dirt dented")
	check_eq(terrain.get_cell(101 + Bullet.DENT_RADIUS, 100), TerrainData.AIR, "dent reaches DENT_RADIUS")
	check_eq(terrain.get_cell(101 + Bullet.DENT_RADIUS + 1, 100), TerrainData.DIRT, "dent limited to DENT_RADIUS")


func test_fire_costs_energy() -> void:
	var terrain := _corridor()
	var tank := _spawn(terrain, Vector2(100, 100))
	var shots := [0]
	tank.fired.connect(func(_t: Tank) -> void: shots[0] += 1)
	check(tank.try_fire(), "first shot fires")
	check_eq(tank.energy, Tank.MAX_ENERGY - Tank.ENERGY_COST_FIRE, "fire costs 8")
	check(not tank.try_fire(), "cooldown blocks rapid fire")
	tank.tick(Tank.FIRE_COOLDOWN)
	var before := tank.energy
	check(tank.try_fire(), "fires after cooldown")
	check_eq(tank.energy, before - Tank.ENERGY_COST_FIRE, "second shot costs 8")
	tank.energy = 5.0
	tank.tick(1.0)
	check(not tank.try_fire(), "not enough energy")
	check_eq(shots[0], 2, "fired signal per shot")
	tank.free()


func test_hit_destroys_tank_and_craters() -> void:
	var terrain := _corridor()
	var shooter := _spawn(terrain, Vector2(100, 100))
	var target := _spawn(terrain, Vector2(130, 100))
	var tanks: Array[Tank] = [shooter, target]
	var bullet := _bullet(terrain, shooter.global_position, Vector2(Bullet.BULLET_SPEED, 0), tanks, shooter)
	_run(bullet, 0.5)
	check(bullet.is_dead, "bullet consumed by hit")
	check(target.is_dead, "target destroyed")
	check(not target.visible, "target hidden")
	check(not shooter.is_dead, "shooter not hit by own bullet")
	check_eq(terrain.get_cell(130, 107), TerrainData.AIR, "crater carved at radius 7")
	check_eq(terrain.get_cell(130, 109), TerrainData.DIRT, "crater limited to radius 8")
	shooter.free()
	target.free()
