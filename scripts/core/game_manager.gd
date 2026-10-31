class_name GameManager
extends Node
## Owns the simulation: spawns tanks/HUDs, routes input, runs bullets and the round loop.
## The simulation advances in fixed ticks (one per physics step); rendering is smoothed by physics interpolation.

const TankScene := preload("res://scenes/tank/tank.tscn")
const BulletScene := preload("res://scenes/combat/bullet.tscn")
const HudScene := preload("res://scenes/ui/player_hud.tscn")

const TICK_RATE := 30
const TICK_DT := 1.0 / TICK_RATE
const PLAYER_COLORS: Array[Color] = [
	Color(0.3, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.85, 0.2),
	Color(1.0, 0.35, 0.9), Color(0.3, 1.0, 1.0), Color(1.0, 0.5, 0.2),
]

static var KILLS_TO_WIN := 3
# Bullets a destroyed tank bursts into, evenly around it.
static var SHRAPNEL_COUNT := 12

static var MAP_AREA_PER_PLAYER := 128000
static var MAP_ASPECT := 1.6
# Lobby map sizes; M is the default.
const MAP_SIZE_NAMES := ["S", "M", "L", "XL"]
const MAP_AREA_SCALES: Array[float] = [0.5, 1.0, 2.0, 3.0]

var map_size: Vector2i
var terrain: TerrainData
var renderer: TerrainRenderer
var jelly: Jelly
var bullets_root: Node2D
var tanks: Array[Tank] = []
var huds: Array[PlayerHud] = []
# Only on a spectating PC.
var spectator_hud: SpectatorHud
var worms: Array[Worm] = []
var round_over: bool = false
var tick: int = 0
# Seeded per match so every PC in a LAN match generates the same maps.
var rng := RandomNumberGenerator.new()

@onready var manager: ViewportManager = get_parent()
@onready var router: InputRouter = get_parent().get_node("InputRouter")


func _ready() -> void:
	await manager.ready
	var player_count := router.assign_devices(Input.get_connected_joypads())
	if Net.in_match:
		setup(Net.slot_peers.size(), Net.match_seed, Net.local_slots, Net.map_size, Net.local_slots.is_empty())
	else:
		setup(player_count)


# In a LAN match a tick only runs once every PC's input for it has arrived (lockstep).
func _physics_process(_delta: float) -> void:
	if not Net.in_match:
		step()
		return
	if Net.sent_tick < tick + 1 + Net.INPUT_DELAY:
		var local_inputs := router.sample_local(Net.local_slots.size())
		Net.send_input(tick + 1 + Net.INPUT_DELAY, local_inputs)
	var inputs := Net.take_inputs(tick + 1)
	if not inputs.is_empty():
		simulate(inputs)


# local_slots are the players shown on this PC (all of them when empty). A spectating PC has none and sees the whole map.
func setup(player_count: int, match_seed: int = randi(), local_slots: Array[int] = [], size_index: int = 1, spectate: bool = false) -> void:
	if local_slots.is_empty() and not spectate:
		local_slots = []
		for i in player_count:
			local_slots.append(i)
	map_size = map_size_for(player_count, size_index)
	manager.build(local_slots, map_size)
	tanks.clear()
	huds.clear()
	worms.clear()
	rng.seed = match_seed

	terrain = TerrainData.new(map_size.x, map_size.y)
	renderer = TerrainRenderer.new()
	renderer.base_colors = PLAYER_COLORS.slice(0, player_count)
	manager.world_root.add_child(renderer)
	jelly = Jelly.new()
	manager.world_root.add_child(jelly)

	for i in player_count:
		var tank: Tank = TankScene.instantiate()
		tank.player_id = i
		tank.color = PLAYER_COLORS[i]
		tank.terrain = terrain
		tank.jelly = jelly
		tank.fired.connect(_on_tank_fired)
		tank.destroyed.connect(_on_tank_destroyed)
		manager.world_root.add_child(tank)
		tanks.append(tank)

	for i in local_slots.size():
		var hud: PlayerHud = HudScene.instantiate()
		manager.viewports[i].add_child(hud)
		hud.setup(local_slots[i], PLAYER_COLORS[local_slots[i]])
		huds.append(hud)
	spectator_hud = null
	if spectate:
		spectator_hud = SpectatorHud.new()
		manager.viewports[0].add_child(spectator_hud)
	Sfx.listeners.clear()
	for slot in local_slots:
		Sfx.listeners.append(tanks[slot])

	bullets_root = Node2D.new()
	bullets_root.name = "Bullets"
	manager.world_root.add_child(bullets_root)
	manager.tanks = tanks
	renderer.bind(terrain)
	start_round(rng.randi())


# Square map as wide as a MAP_ASPECT map whose area grows linearly with the player count (640x640 for 2 players, 1107x1107 for 6 on M).
static func map_size_for(player_count: int, size_index: int = 1) -> Vector2i:
	var h := int(sqrt(MAP_AREA_PER_PLAYER * MAP_AREA_SCALES[size_index] * maxi(player_count, 2) / MAP_ASPECT))
	var side := int(h * MAP_ASPECT)
	return Vector2i(side, side)


func start_round(new_seed: int) -> void:
	terrain.generate(new_seed, tanks.size())
	jelly.reset(map_size)
	for bullet in bullets_root.get_children():
		bullet.free()
	for worm in worms:
		worm.free()
	worms.clear()
	# One worm per round, placed from the map seed so every PC agrees.
	var worm := Worm.new()
	worm.terrain = terrain
	worm.tanks = tanks
	worm.rng.seed = terrain.map_seed
	manager.world_root.add_child(worm)
	worm.spawn(Worm.spawn_point(terrain, worm.rng))
	worms.append(worm)
	for i in tanks.size():
		tanks[i].home_rect = terrain.base_rects[i]
		tanks[i].money = 0
		tanks[i].levels = [0, 0, 0, 0]
		tanks[i].special = -1
		tanks[i].kills = 0
		tanks[i].respawn(Vector2(terrain.base_rects[i].get_center()))
	for hud in huds:
		hud.hide_banner()
	if spectator_hud:
		spectator_hud.hide_banner()
	round_over = false
	manager.show_map(false)
	manager.reset_fog(renderer)
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
	Net.apply_tunings(tick)
	if round_over:
		manager.update_cameras(inputs, TICK_DT)
		_update_huds()
		return

	for bullet in bullets_root.get_children():
		bullet.step(TICK_DT)
	jelly.step()
	for worm in worms:
		worm.step(TICK_DT)

	for tank in tanks:
		if tank.is_dead:
			tank.respawn(Vector2(tank.home_rect.get_center()))
			continue
		var input := inputs[tank.player_id]
		tank.tick(TICK_DT)
		tank.step_movement(TICK_DT, input["move"])
		if input["fire"]:
			tank.try_fire()

	_check_round_end()
	_update_huds()
	manager.update_cameras(inputs, TICK_DT)


func _check_round_end() -> void:
	var winners := tanks.filter(func(t: Tank) -> bool: return t.kills >= KILLS_TO_WIN)
	if winners.is_empty():
		return
	round_over = true
	manager.show_map(true)
	var winner_name := player_name(winners[0].player_id)
	for hud in huds:
		hud.show_banner("%s WINS" % winner_name)
	if spectator_hud:
		spectator_hud.show_banner("%s WINS" % winner_name)


func _update_huds() -> void:
	for hud in huds:
		hud.update_hud(tanks[hud.player_id])
	if spectator_hud:
		spectator_hud.update_scores(tanks, tanks.map(func(t: Tank) -> String: return player_name(t.player_id)))


func player_name(id: int) -> String:
	return Net.slot_names[id] if Net.in_match else "PLAYER %d" % (id + 1)


func _on_tank_fired(tank: Tank) -> void:
	Sfx.play(Sfx.Kind.LASER if tank.special == Tank.Special.LASER else Sfx.Kind.FIRE, tank.global_position)
	if tank.special == Tank.Special.LASER:
		var laser := Laser.new()
		laser.terrain = terrain
		laser.tanks = tanks
		laser.worms = worms
		laser.shooter = tank
		laser.position = tank.muzzle_position()
		bullets_root.add_child(laser)
		laser.reset_physics_interpolation()
		laser.fire(tank.facing)
		return
	var volley: Array[Tank] = []
	for dir in tank.fire_directions():
		var bullet: Bullet = BulletScene.instantiate()
		bullet.terrain = terrain
		bullet.tanks = tanks
		bullet.worms = worms
		bullet.shooter = tank
		bullet.volley = volley
		bullet.position = tank.muzzle_position(dir)
		bullet.velocity = dir * Bullet.BULLET_SPEED
		# 3-way bullets never ricochet.
		if tank.special == Tank.Special.SPREAD:
			bullet.max_bounces = 0
		bullets_root.add_child(bullet)
		bullet.reset_physics_interpolation()


# Shrapnel hits count for whoever destroyed the tank, so chain explosions credit them too.
func _on_tank_destroyed(tank: Tank, attacker: Tank) -> void:
	for i in SHRAPNEL_COUNT:
		var bullet: Bullet = BulletScene.instantiate()
		bullet.terrain = terrain
		bullet.tanks = tanks
		bullet.shooter = tank
		bullet.attacker = attacker
		bullet.max_bounces = 0
		bullet.position = tank.position
		bullet.velocity = Vector2.from_angle(TAU * i / SHRAPNEL_COUNT) * Bullet.BULLET_SPEED
		bullets_root.add_child(bullet)
		bullet.reset_physics_interpolation()
