extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")
const BulletScene := preload("res://scenes/combat/bullet.tscn")
const DT := GameManager.TICK_DT


# A 3-player game with plain dirt around the map center and a spice pocket on it.
func _make_game() -> GameManager:
	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	var gm: GameManager = manager.get_node("GameManager")
	gm.router.assign_devices([] as Array[int])
	gm.setup(3)
	var c := _center(gm)
	for y in range(c.y - 120, c.y + 121):
		for x in range(c.x - 120, c.x + 121):
			gm.terrain.cells[y * gm.terrain.width + x] = TerrainData.DIRT
	gm.terrain.fill_circle(c.x, c.y, SpiceBlow.POCKET_RADIUS, TerrainData.SPICE)
	return gm


func _center(gm: GameManager) -> Vector2i:
	return Vector2i(gm.terrain.width / 2, gm.terrain.height / 2)


func _place(tank: Tank, pos: Vector2i) -> void:
	tank.position = Vector2(pos)


# Open corridor from x0 to x1 along the center row.
func _corridor(gm: GameManager, x0: int, x1: int) -> void:
	var c := _center(gm)
	for x in range(c.x + x0, c.x + x1 + 1):
		gm.terrain.cells[c.y * gm.terrain.width + x] = TerrainData.AIR


func test_shot_sets_off_blow() -> void:
	var gm := _make_game()
	var c := _center(gm)
	var w := gm.terrain.width
	gm.terrain.cells[c.y * w + c.x + 20] = TerrainData.GOLD
	_place(gm.tanks[0], c + Vector2i(-80, 0))
	_place(gm.tanks[1], c + Vector2i(30, 10))
	_place(gm.tanks[2], c + Vector2i(0, 90))
	_corridor(gm, -12, -3)
	var bullet: Bullet = BulletScene.instantiate()
	bullet.terrain = gm.terrain
	bullet.tanks = gm.tanks
	bullet.shooter = gm.tanks[0]
	bullet.position = Vector2(c + Vector2i(-10, 0))
	bullet.velocity = Vector2(Bullet.BULLET_SPEED, 0)
	gm.bullets_root.add_child(bullet)
	for i in 3:
		bullet.step(DT)
	check(bullet.is_dead, "bullet stopped at the pocket")
	check_eq(gm.terrain.get_cell(c.x + 35, c.y), TerrainData.AIR, "sand cleared within RADIUS")
	check_eq(gm.terrain.get_cell(c.x - 2, c.y - SpiceBlow.RADIUS), TerrainData.AIR, "cleared up to RADIUS around the hit cell")
	check_eq(gm.terrain.get_cell(c.x + SpiceBlow.RADIUS + 4, c.y), TerrainData.DIRT, "sand beyond RADIUS stays")
	check_eq(gm.terrain.get_cell(c.x + 20, c.y), TerrainData.GOLD, "gold stays")
	check_eq(gm.terrain.cells.count(TerrainData.SPICE), 0, "the pocket is used up")
	check(gm.tanks[1].is_dead, "a tank in the blow is destroyed")
	check_eq(gm.tanks[1].shields, gm.tanks[1].max_shields(), "shields do not help")
	check(not gm.tanks[2].is_dead, "a far tank survives")
	check(not gm.tanks[0].is_dead, "the shooter survives out of range")
	check_eq(gm.tanks[0].kills, 1, "the shooter gets the kill")
	gm.manager.free()


func test_dent_next_to_pocket_sets_it_off() -> void:
	var gm := _make_game()
	var c := _center(gm)
	_place(gm.tanks[0], c + Vector2i(-80, 0))
	_place(gm.tanks[1], c + Vector2i(30, 10))
	_corridor(gm, -12, -4)
	var bullet: Bullet = BulletScene.instantiate()
	bullet.terrain = gm.terrain
	bullet.tanks = gm.tanks
	bullet.shooter = gm.tanks[0]
	bullet.position = Vector2(c + Vector2i(-10, 0))
	bullet.velocity = Vector2(Bullet.BULLET_SPEED, 0)
	gm.bullets_root.add_child(bullet)
	for i in 3:
		bullet.step(DT)
	check(bullet.is_dead, "bullet stopped in the dirt beside the pocket")
	check_eq(gm.terrain.get_cell(c.x + 30, c.y), TerrainData.AIR, "the dent reaching a grain set off the blow")
	check(gm.tanks[1].is_dead, "a tank in the blow is destroyed")
	check_eq(gm.tanks[0].kills, 1, "the shooter gets the kill")
	gm.manager.free()


func test_blow_keeps_rock() -> void:
	var gm := _make_game()
	var c := _center(gm)
	gm.terrain.cells[c.y * gm.terrain.width + c.x - 20] = TerrainData.BEDROCK
	gm.terrain.spice_hit.emit(c, null)
	check_eq(gm.terrain.get_cell(c.x - 20, c.y), TerrainData.BEDROCK, "rock stays")
	check_eq(gm.terrain.get_cell(c.x - 30, c.y), TerrainData.AIR, "sand behind the rock cleared")
	gm.manager.free()


func test_own_base_is_safe() -> void:
	var gm := _make_game()
	var c := _center(gm)
	_place(gm.tanks[1], c + Vector2i(30, 10))
	gm.tanks[1].home_rect = Rect2i(c + Vector2i(20, 0), Vector2i(21, 21))
	gm.terrain.spice_hit.emit(c, gm.tanks[0])
	check(not gm.tanks[1].is_dead, "a tank in its own base survives")
	check_eq(gm.tanks[0].kills, 0, "no kill credited")
	gm.manager.free()


func test_chain_reaction() -> void:
	var gm := _make_game()
	var c := _center(gm)
	gm.terrain.fill_circle(c.x + 35, c.y, SpiceBlow.POCKET_RADIUS, TerrainData.SPICE)
	_place(gm.tanks[1], c + Vector2i(65, 0))
	gm.terrain.spice_hit.emit(c, gm.tanks[0])
	check_eq(gm.terrain.get_cell(c.x + 70, c.y), TerrainData.AIR, "the second pocket blew too")
	check_eq(gm.terrain.get_cell(c.x - SpiceBlow.RADIUS - 4, c.y), TerrainData.DIRT, "sand beyond both blows stays")
	check(gm.tanks[1].is_dead, "the chained blow destroys tanks too")
	check_eq(gm.tanks[0].kills, 1, "chained kills go to the trigger")
	gm.manager.free()


func test_digging_sets_off_blow() -> void:
	var gm := _make_game()
	var c := _center(gm)
	var digger := gm.tanks[0]
	_place(digger, c + Vector2i(-9, 0))
	_place(gm.tanks[1], c + Vector2i(0, 30))
	for i in 60:
		digger.step_movement(DT, Vector2.RIGHT)
		if digger.is_dead:
			break
	check(digger.is_dead, "the digger dies in its blow")
	check_eq(gm.terrain.get_cell(c.x + 25, c.y), TerrainData.AIR, "digging set off the blow")
	check(gm.tanks[1].is_dead, "a nearby tank is destroyed")
	check_eq(digger.kills, 0, "a digger dying in its own blow gets no kill")
	gm.manager.free()


func test_laser_sets_off_blow() -> void:
	var gm := _make_game()
	var c := _center(gm)
	_place(gm.tanks[0], c + Vector2i(-80, 0))
	_place(gm.tanks[1], c + Vector2i(30, 10))
	_corridor(gm, -12, -3)
	var laser := Laser.new()
	laser.terrain = gm.terrain
	laser.tanks = gm.tanks
	laser.shooter = gm.tanks[0]
	laser.position = Vector2(c + Vector2i(-10, 0))
	gm.bullets_root.add_child(laser)
	laser.fire(Vector2.RIGHT)
	check_eq(gm.terrain.get_cell(c.x + 30, c.y), TerrainData.AIR, "the beam set off the blow")
	check(gm.tanks[1].is_dead, "a tank in the blow is destroyed")
	check_eq(gm.tanks[0].kills, 1, "the shooter gets the kill")
	gm.manager.free()


func test_worm_lays_pockets() -> void:
	var terrain := TerrainData.new()
	var worm := Worm.new()
	worm.terrain = terrain
	worm.dormant = 0
	tree.root.add_child(worm)
	worm.spawn(Vector2(100, 100))
	check(worm.spice_ticks >= Worm.SPICE_MIN_TICKS and worm.spice_ticks <= Worm.SPICE_MAX_TICKS, "first pocket within the interval")
	worm.spice_ticks = 2
	worm.step(DT)
	check_eq(terrain.cells.count(TerrainData.SPICE), 0, "no pocket before the interval")
	worm.step(DT)
	var tail := Vector2i(worm.body[worm.body.size() - 1].round())
	check_eq(terrain.get_cell(tail.x, tail.y), TerrainData.SPICE, "pocket at the tail")
	check_eq(terrain.cells.count(TerrainData.SPICE), 13, "a radius 2 pocket")
	check(worm.spice_ticks >= Worm.SPICE_MIN_TICKS, "next pocket drawn")
	worm.free()
