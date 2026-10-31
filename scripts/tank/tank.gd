class_name Tank
extends CharacterBody2D
## Grid-aware tank: digs through dirt, is blocked by bedrock, runs on a battery.

signal fired(tank: Tank)
signal destroyed(tank: Tank)

const MAX_ENERGY := 100.0
const SPEED_CLEAR := 60.0
const SPEED_DIGGING := 25.0
const ENERGY_DRAIN_IDLE := 0.0
const ENERGY_DRAIN_MOVE_CLEAR := 0.0
const ENERGY_DRAIN_DIGGING := 7.5
const ENERGY_RECHARGE_BASE := 25.0
const ENERGY_REGEN_PASSIVE := 0.5
const LOW_ENERGY := 10.0
const SPEED_FACTOR_EMPTY := 0.25
const DIG_MARGIN := 1
const ENERGY_COST_FIRE := 8.0
const FIRE_COOLDOWN := 0.25
const MAX_SHIELDS := 1.0
# Refills an empty set in the same time the base refills an empty battery.
const SHIELD_RECHARGE_BASE := MAX_SHIELDS * ENERGY_RECHARGE_BASE / MAX_ENERGY

enum Upgrade { SHIELD, ENERGY, SPEED, RADAR }
const MAX_LEVEL := 5
# About the dirt cells one full base battery digs; level N costs N times this.
const UPGRADE_COST := 3000
const ENERGY_PER_LEVEL := 0.5
const SPEED_PER_LEVEL := 0.25
const RADAR_PER_LEVEL := 0.25

static var _texture: ImageTexture

@export var tank_radius: int = 3

var player_id: int = 0
var color: Color = Color.WHITE
var terrain: TerrainData
var energy: float = MAX_ENERGY
var shields: float = MAX_SHIELDS
var facing: Vector2 = Vector2.UP
var home_rect: Rect2i
var is_dead: bool = false
var fire_cooldown: float = 0.0
# Value of the dirt and gold dug this round.
var money: int = 0
var levels: Array[int] = [0, 0, 0, 0]
# Home pad under the tank; a pad buys one level per visit.
var _pad: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if _texture == null:
		_texture = _build_texture()
	sprite.texture = _texture
	sprite.self_modulate = color


func tick(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if is_dead:
		return
	var cell := Vector2i(global_position.round())
	var recharge := ENERGY_REGEN_PASSIVE
	if _in_base():
		# Scaled by battery size so any battery refills in the same time.
		recharge += ENERGY_RECHARGE_BASE * max_energy() / MAX_ENERGY
		shields = minf(max_shields(), shields + SHIELD_RECHARGE_BASE * delta)
	energy = minf(max_energy(), energy + recharge * delta)
	var pad := TerrainData.pad_at(home_rect, cell)
	if pad != _pad:
		_pad = pad
		if pad >= 0:
			try_upgrade(pad)


func _in_base() -> bool:
	var cell := Vector2i(global_position.round())
	return terrain.base_rects.any(func(rect: Rect2i) -> bool: return rect.has_point(cell))


func try_upgrade(upgrade: int) -> bool:
	var cost := (levels[upgrade] + 1) * UPGRADE_COST
	if levels[upgrade] >= MAX_LEVEL or money < cost:
		return false
	money -= cost
	levels[upgrade] += 1
	return true


func max_energy() -> float:
	return MAX_ENERGY * (1.0 + ENERGY_PER_LEVEL * levels[Upgrade.ENERGY])


func max_shields() -> float:
	return MAX_SHIELDS + levels[Upgrade.SHIELD]


func speed_factor() -> float:
	return 1.0 + SPEED_PER_LEVEL * levels[Upgrade.SPEED]


func reveal_radius() -> int:
	return roundi(FogOfWar.reveal_radius(tank_radius) * (1.0 + RADAR_PER_LEVEL * levels[Upgrade.RADAR]))


func step_movement(delta: float, input_dir: Vector2) -> void:
	var dir := snap_direction(input_dir)
	if is_dead or dir == Vector2.ZERO:
		energy = maxf(0.0, energy - ENERGY_DRAIN_IDLE * delta)
		return

	facing = dir
	rotation = dir.angle() + PI / 2.0

	# The tunnel is DIG_MARGIN wider than the body; probe just outside it so solid earth always reads as DIRT.
	var dig_radius := tank_radius + DIG_MARGIN
	var probe := global_position + dir * (dig_radius + 2)
	var probe_cell := terrain.get_cell(roundi(probe.x), roundi(probe.y))
	var digging := probe_cell == TerrainData.DIRT or probe_cell == TerrainData.GOLD or probe_cell == TerrainData.ENERGY
	var current_speed := SPEED_CLEAR
	var drain := ENERGY_DRAIN_MOVE_CLEAR
	if digging:
		# Below LOW_ENERGY digging slows down, crawling at SPEED_FACTOR_EMPTY when the battery is flat.
		current_speed = SPEED_DIGGING * lerpf(SPEED_FACTOR_EMPTY, 1.0, clampf(energy / LOW_ENERGY, 0.0, 1.0))
		drain = ENERGY_DRAIN_DIGGING
	current_speed *= speed_factor()

	var target := global_position + dir * current_speed * delta
	if not terrain.is_circle_passable(roundi(target.x), roundi(target.y), tank_radius):
		return # Blocked

	energy = maxf(0.0, energy - drain * delta)
	velocity = dir * current_speed
	move_and_collide(velocity * delta)
	money += terrain.dig_circle(roundi(global_position.x), roundi(global_position.y), dig_radius)
	energy = minf(max_energy(), energy + terrain.dug_energy * TerrainData.ENERGY_VALUE)


func try_fire() -> bool:
	if is_dead or energy < ENERGY_COST_FIRE or fire_cooldown > 0.0 or _in_base():
		return false
	energy -= ENERGY_COST_FIRE
	fire_cooldown = FIRE_COOLDOWN
	fired.emit(self)
	return true


func muzzle_position() -> Vector2:
	return global_position + facing * (tank_radius + 2)


# Each full shield absorbs one hit; a hit with no full shield left destroys the tank.
func hit() -> void:
	if shields >= 1.0:
		shields -= 1.0
		return
	destroy()


func destroy() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	shape.set_deferred("disabled", true)
	var explosion := Explosion.new()
	explosion.position = position
	get_parent().add_child(explosion)
	explosion.detonate(terrain)
	destroyed.emit(self)


func respawn(pos: Vector2) -> void:
	is_dead = false
	visible = true
	shape.set_deferred("disabled", false)
	position = pos
	rotation = 0.0
	facing = Vector2.UP
	velocity = Vector2.ZERO
	energy = MAX_ENERGY
	shields = MAX_SHIELDS
	fire_cooldown = 0.0
	money = 0
	levels = [0, 0, 0, 0]
	_pad = -1
	reset_physics_interpolation()


static func snap_direction(v: Vector2) -> Vector2:
	if v.length() < 0.2:
		return Vector2.ZERO
	var snap := Vector2.from_angle(snappedf(v.angle(), PI / 4.0))
	return Vector2(roundf(snap.x), roundf(snap.y)).normalized()


static func _build_texture() -> ImageTexture:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		img.set_pixel(0, y, Color(0.35, 0.35, 0.35))
		img.set_pixel(6, y, Color(0.35, 0.35, 0.35))
	for y in range(2, 7):
		for x in range(1, 6):
			img.set_pixel(x, y, Color.WHITE)
	for y in range(0, 4):
		img.set_pixel(3, y, Color(0.85, 0.85, 0.85))
	return ImageTexture.create_from_image(img)
