class_name Tank
extends CharacterBody2D
## Grid-aware tank: digs through dirt, is blocked by bedrock, runs on a battery.

signal fired(tank: Tank)
signal destroyed(tank: Tank, attacker: Tank)

# Tuning values are static vars so DevSettings can change them live.
static var MAX_ENERGY := 100.0
static var SPEED_CLEAR := 60.0
static var SPEED_DIGGING := 15.625
static var ENERGY_DRAIN_IDLE := 0.0
static var ENERGY_DRAIN_MOVE_CLEAR := 0.0
# Energy per dug cell, so faster digging drains faster.
static var ENERGY_PER_DUG_CELL := 1.0 / 15.0
static var ENERGY_DRAIN_JELLY := 9.375
static var ENERGY_RECHARGE_BASE := 25.0
static var ENERGY_REGEN_PASSIVE := 0.5
static var LOW_ENERGY := 10.0
static var SPEED_FACTOR_EMPTY := 0.25
static var DIG_MARGIN := 1
static var ENERGY_COST_FIRE := 2.0
static var FIRE_COOLDOWN := 0.25 / 3.0
# Hits the shield bar absorbs; each shield level adds SHIELDS_PER_LEVEL.
static var MAX_SHIELDS := 5.0
static var SHIELDS_PER_LEVEL := 2.0
# Shields per second in a base.
static var SHIELD_RECHARGE_BASE := 1.0

enum Upgrade { SHIELD, ENERGY, SPEED, RADAR }
static var MAX_LEVEL := 5
# About half the dirt cells one full base battery digs; level N costs N times this.
static var UPGRADE_COST := 1500
static var ENERGY_PER_LEVEL := 0.5
static var SPEED_PER_LEVEL := 0.25
static var RADAR_PER_LEVEL := 0.25
# Free switches on the pads of other players' bases, in Upgrade pad order; one is active at a time.
enum Special { SPREAD, LASER, JELLY, RADAR }
static var ENERGY_COST_LASER := 1.25
static var ENERGY_COST_SPREAD := 1.0

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
var kills: int = 0
# Value of the dirt and gold dug this round.
var money: int = 0
var levels: Array[int] = [0, 0, 0, 0]
# Active Special, or -1.
var special: int = -1
var jelly: Jelly
# Pad under the tank; a pad acts once per visit.
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
	var pad := -1
	var home := false
	for rect in terrain.base_rects:
		if rect.has_point(cell):
			pad = TerrainData.pad_at(rect, cell)
			home = rect == home_rect
	if pad != _pad:
		_pad = pad
		if pad >= 0 and home:
			try_upgrade(pad)
		elif pad >= 0:
			special = pad


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
	return MAX_SHIELDS + SHIELDS_PER_LEVEL * levels[Upgrade.SHIELD]


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
	var digging := TerrainData.is_diggable(probe_cell)
	var current_speed := SPEED_CLEAR
	var drain := ENERGY_DRAIN_MOVE_CLEAR
	# Other players' jelly slows like digging and drains ENERGY_DRAIN_JELLY per second.
	var slowed := jelly != null and jelly.slows(self)
	if digging or slowed:
		# Below LOW_ENERGY digging slows down, crawling at SPEED_FACTOR_EMPTY when the battery is flat.
		current_speed = SPEED_DIGGING * lerpf(SPEED_FACTOR_EMPTY, 1.0, clampf(energy / LOW_ENERGY, 0.0, 1.0))
	if slowed:
		drain = ENERGY_DRAIN_JELLY
	current_speed *= speed_factor()

	var target := global_position + dir * current_speed * delta
	if not terrain.is_circle_passable(roundi(target.x), roundi(target.y), tank_radius):
		return # Blocked

	energy = maxf(0.0, energy - drain * delta)
	velocity = dir * current_speed
	move_and_collide(velocity * delta)
	money += terrain.dig_circle(roundi(global_position.x), roundi(global_position.y), dig_radius)
	energy = clampf(energy + terrain.dug_energy * TerrainData.ENERGY_VALUE - terrain.dug_drain * TerrainData.DRAIN_VALUE - terrain.dug_cells * ENERGY_PER_DUG_CELL, 0.0, max_energy())
	if special == Special.JELLY:
		jelly.lay(global_position, player_id, color)


func try_fire() -> bool:
	var cost := ENERGY_COST_FIRE
	if special == Special.LASER:
		cost = ENERGY_COST_LASER
	elif special == Special.SPREAD:
		cost = ENERGY_COST_SPREAD
	if is_dead or energy < cost or fire_cooldown > 0.0 or _in_base():
		return false
	energy -= cost
	fire_cooldown = FIRE_COOLDOWN
	fired.emit(self)
	return true


# The 3-way cannon also fires to both sides.
func fire_directions() -> Array[Vector2]:
	if special != Special.SPREAD:
		return [facing]
	return [facing, facing.rotated(-PI / 2.0), facing.rotated(PI / 2.0)]


# Stops in front of bedrock along the barrel, so a tank touching a wall cannot shoot through it.
func muzzle_position(dir: Vector2 = facing) -> Vector2:
	var p := global_position
	for i in tank_radius + 2:
		var next := p + dir
		if terrain.get_cell(roundi(next.x), roundi(next.y)) == TerrainData.BEDROCK:
			break
		p = next
	return p


# A hit takes one shield, and any shield left absorbs it; a hit on an empty bar destroys the tank. The own base is a safe zone.
func hit(attacker: Tank = null) -> void:
	if home_rect.has_point(Vector2i(global_position.round())):
		return
	if shields > 0.0:
		shields = maxf(0.0, shields - 1.0)
		return
	destroy(attacker)
	if attacker and attacker != self:
		attacker.kills += 1


func destroy(attacker: Tank = null) -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	shape.set_deferred("disabled", true)
	var explosion := Explosion.new()
	explosion.position = position
	get_parent().add_child(explosion)
	explosion.detonate(terrain)
	destroyed.emit(self, attacker)


func respawn(pos: Vector2) -> void:
	is_dead = false
	visible = true
	shape.set_deferred("disabled", false)
	position = pos
	rotation = 0.0
	facing = Vector2.UP
	velocity = Vector2.ZERO
	energy = max_energy()
	shields = max_shields()
	fire_cooldown = 0.0
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
