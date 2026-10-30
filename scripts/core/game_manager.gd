class_name GameManager
extends Node
## Owns the simulation: spawns tanks/HUDs, routes input, runs bullets and the round loop.
## The simulation advances in fixed ticks (one per physics step); rendering is smoothed by physics interpolation.

const TankScene := preload("res://scenes/tank/tank.tscn")
const BulletScene := preload("res://scenes/combat/bullet.tscn")
const HudScene := preload("res://scenes/ui/player_hud.tscn")

const TICK_RATE := 30
const TICK_DT := 1.0 / TICK_RATE
const ROUND_FREEZE_TICKS := 3 * TICK_RATE
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
var tick: int = 0
var round_resume_tick: int = 0

@onready var manager: ViewportManager = get_parent()
@onready var router: InputRouter = get_parent().get_node("InputRouter")


func _ready() -> void:
	await manager.ready
	setup(router.assign_devices(Input.get_connected_joypads()))


func _physics_process(_delta: float) -> void:
	step()


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
	manager.update_cameras()
	for cam in manager.cameras:
		cam.reset_physics_interpolation()


# Advances exactly one tick using the local devices' input.
func step() -> void:
	var inputs: Array[Dictionary] = []
	for tank in tanks:
		inputs.append(router.sample(tank.player_id))
	simulate(inputs)


# One fixed TICK_DT step. inputs[player_id] = {"move": Vector2, "fire": bool}.
func simulate(inputs: Array[Dictionary]) -> void:
	tick += 1
	if round_over:
		if tick >= round_resume_tick:
			start_round(randi())
		_update_huds()
		return

	for bullet in bullets_root.get_children():
		bullet.step(TICK_DT)

	for tank in tanks:
		if tank.is_dead:
			continue
		var input := inputs[tank.player_id]
		tank.tick(TICK_DT)
		tank.step_movement(TICK_DT, input["move"])
		if input["fire"]:
			tank.try_fire()

	_check_round_end()
	_update_huds()
	manager.update_cameras()


func _check_round_end() -> void:
	var alive := tanks.filter(func(t: Tank) -> bool: return not t.is_dead)
	if alive.size() > 1:
		return
	round_over = true
	round_resume_tick = tick + ROUND_FREEZE_TICKS
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
	bullet.reset_physics_interpolation()
