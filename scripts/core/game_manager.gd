class_name GameManager
extends Node
## Owns the simulation: spawns tanks/HUDs, routes input, runs bullets and the round loop.

const TankScene := preload("res://scenes/tank/tank.tscn")
const BulletScene := preload("res://scenes/combat/bullet.tscn")
const HudScene := preload("res://scenes/ui/player_hud.tscn")

const ROUND_FREEZE := 3.0
const PLAYER_COLORS: Array[Color] = [
	Color(0.3, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.85, 0.2),
	Color(1.0, 0.35, 0.9), Color(0.3, 1.0, 1.0), Color(1.0, 0.5, 0.2),
]

const MAP_AREA_PER_PLAYER := 128000
const MAP_ASPECT := 1.6

var map_size: Vector2i
var terrain: TerrainData
var renderer: TerrainRenderer
var bullets_root: Node2D
var tanks: Array[Tank] = []
var huds: Array[PlayerHud] = []
var wins: Array[int] = []
var round_over: bool = false
var freeze_time: float = 0.0

@onready var manager: ViewportManager = get_parent()
@onready var router: InputRouter = get_parent().get_node("InputRouter")


func _ready() -> void:
	await manager.ready
	setup(router.assign_devices(Input.get_connected_joypads()))


func _physics_process(delta: float) -> void:
	step(delta)


func setup(player_count: int) -> void:
	map_size = map_size_for(player_count)
	manager.build(player_count, map_size)
	tanks.clear()
	huds.clear()
	wins.resize(player_count)
	wins.fill(0)

	terrain = TerrainData.new(map_size.x, map_size.y)
	renderer = TerrainRenderer.new()
	renderer.base_colors = PLAYER_COLORS.slice(0, player_count)
	manager.world_root.add_child(renderer)

	for i in player_count:
		var tank: Tank = TankScene.instantiate()
		tank.player_id = i
		tank.color = PLAYER_COLORS[i]
		tank.terrain = terrain
		tank.fired.connect(_on_tank_fired)
		manager.world_root.add_child(tank)
		tanks.append(tank)

		var hud: PlayerHud = HudScene.instantiate()
		manager.viewports[i].add_child(hud)
		hud.setup(i, PLAYER_COLORS[i])
		huds.append(hud)

	bullets_root = Node2D.new()
	bullets_root.name = "Bullets"
	manager.world_root.add_child(bullets_root)
	manager.tanks = tanks
	start_round(randi())
	renderer.bind(terrain)


# Map area grows linearly with the player count (640x400 for 2 players, ~1107x692 for 6).
static func map_size_for(player_count: int) -> Vector2i:
	var h := int(sqrt(MAP_AREA_PER_PLAYER * maxi(player_count, 2) / MAP_ASPECT))
	return Vector2i(int(h * MAP_ASPECT), h)


func start_round(new_seed: int) -> void:
	terrain.generate(new_seed, tanks.size())
	for bullet in bullets_root.get_children():
		bullet.free()
	for i in tanks.size():
		tanks[i].home_rect = terrain.base_rects[i]
		tanks[i].respawn(Vector2(terrain.base_rects[i].get_center()))
	for hud in huds:
		hud.hide_banner()
	round_over = false
	freeze_time = 0.0
	manager.update_cameras()


func step(delta: float) -> void:
	if round_over:
		freeze_time -= delta
		if freeze_time <= 0.0:
			start_round(randi())
		_update_huds()
		return

	for bullet in bullets_root.get_children():
		bullet.step(delta)

	for tank in tanks:
		if tank.is_dead:
			continue
		var id := tank.player_id
		tank.tick(delta)
		tank.step_movement(delta, router.get_movement_vector(id))
		if router.is_fire_pressed(id):
			tank.try_fire()
		if router.is_radar_pressed(id) and tank.try_radar():
			tank.radar_dir = get_radar_direction(tank, tanks)

	_check_round_end()
	_update_huds()


static func get_radar_direction(source_tank: Tank, targets: Array[Tank]) -> Vector2:
	var closest_dist: float = INF
	var best_dir: Vector2 = Vector2.ZERO
	for target in targets:
		if target == source_tank or target.is_dead:
			continue
		var diff = target.global_position - source_tank.global_position
		if diff.length_squared() < closest_dist:
			closest_dist = diff.length_squared()
			best_dir = diff.normalized()
	return best_dir


func _check_round_end() -> void:
	var alive := tanks.filter(func(t: Tank) -> bool: return not t.is_dead)
	if alive.size() > 1:
		return
	round_over = true
	freeze_time = ROUND_FREEZE
	var text := "DRAW"
	if alive.size() == 1:
		var winner: Tank = alive[0]
		wins[winner.player_id] += 1
		text = "PLAYER %d WINS" % (winner.player_id + 1)
	for hud in huds:
		hud.show_banner(text)


func _update_huds() -> void:
	for i in huds.size():
		huds[i].update_hud(tanks[i], wins[i])


func _on_tank_fired(tank: Tank) -> void:
	var bullet: Bullet = BulletScene.instantiate()
	bullet.terrain = terrain
	bullet.tanks = tanks
	bullet.shooter = tank
	bullet.position = tank.muzzle_position()
	bullet.velocity = tank.facing * Bullet.BULLET_SPEED
	bullets_root.add_child(bullet)
