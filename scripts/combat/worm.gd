class_name Worm
extends Node2D
## Dune worm: swims through the ground without digging, refills the tunnels it crosses behind its tail and destroys any tank it touches.
## It heads for the CHUNK with the most AIR, weighed against the distance, and keeps away from the bases.

static var SPEED := 24.0
static var SEGMENTS := 8
static var SEGMENT_SPACING := 3.0
static var RADIUS := 3
# Wide enough to seal a whole tank tunnel.
static var FILL_RADIUS := 5
static var TURN_RATE := PI / 2.0
# Heading sway around the target direction, in radians, with a period of WIGGLE_TICKS.
static var WIGGLE := 0.5
static var WIGGLE_TICKS := 2 * GameManager.TICK_RATE
static var RETARGET_TICKS := 2 * GameManager.TICK_RATE
# Target score lost per chunk of distance; the score is the chunk's AIR count.
static var DISTANCE_PENALTY := 4.0
# No-go margin around every base, in pixels.
static var BASE_CLEARANCE := 12
static var SPAWN_DELAY_TICKS := 20 * GameManager.TICK_RATE
# Spawn points are at least this far from every base center.
static var SPAWN_BASE_DISTANCE := 96.0
const COLOR := Color8(222, 190, 120)
const COLOR_HEAD := Color8(150, 105, 60)
# Alpha of segments under the ground.
const BURIED_ALPHA := 0.35

var terrain: TerrainData
var tanks: Array[Tank] = []
# Segment centers, head first.
var body: Array[Vector2] = []
var heading: Vector2 = Vector2.RIGHT
var target: Vector2 = Vector2.ZERO
# Ticks left before the worm wakes up.
var dormant: int = SPAWN_DELAY_TICKS
var _ticks: int = 0


func _init() -> void:
	visible = false


func spawn(pos: Vector2) -> void:
	body.clear()
	for i in SEGMENTS:
		body.append(pos)
	position = pos
	target = pos
	reset_physics_interpolation()


# A random open spot away from the bases, or the map center when none turns up.
static func spawn_point(data: TerrainData, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 1000:
		var p := Vector2(rng.randi_range(0, data.width - 1), rng.randi_range(0, data.height - 1))
		var far := data.base_rects.all(func(rect: Rect2i) -> bool: return p.distance_to(rect.get_center()) >= SPAWN_BASE_DISTANCE)
		if far and data.is_circle_passable(roundi(p.x), roundi(p.y), RADIUS):
			return p
	return Vector2(data.width, data.height) / 2.0


func step(delta: float) -> void:
	if dormant > 0:
		dormant -= 1
		return
	visible = true
	if _ticks % RETARGET_TICKS == 0:
		target = best_target()
	var angle := heading.angle()
	var to_target := target - body[0]
	var desired := angle
	if to_target.length() > TerrainData.CHUNK / 2.0:
		desired = to_target.angle()
	desired += WIGGLE * sin(TAU * _ticks / WIGGLE_TICKS)
	_ticks += 1
	angle += clampf(angle_difference(angle, desired), -TURN_RATE * delta, TURN_RATE * delta)

	# Blocked headings turn by 45 degree steps, toward the target side first.
	var side := -1.0 if angle_difference(angle, to_target.angle()) < 0.0 else 1.0
	for turn in [0, 1, -1, 2, -2, 3, -3, 4]:
		var dir := Vector2.from_angle(angle + side * turn * PI / 4.0)
		var next := body[0] + dir * SPEED * delta
		if _passable(next):
			heading = dir
			body[0] = next
			break
	for i in range(1, body.size()):
		var gap := body[i] - body[i - 1]
		if gap.length() > SEGMENT_SPACING:
			body[i] = body[i - 1] + gap.normalized() * SEGMENT_SPACING
	var tail := body[body.size() - 1]
	terrain.fill_circle(roundi(tail.x), roundi(tail.y), FILL_RADIUS)
	position = body[0]
	Sfx.play(Sfx.Kind.RUMBLE, body[0])

	for tank in tanks:
		if not tank.is_dead and body.any(func(p: Vector2) -> bool: return p.distance_to(tank.global_position) <= RADIUS + tank.tank_radius):
			tank.destroy()
	queue_redraw()


# Center of the chunk with the best score outside the base no-go zones, or the head when no chunk has AIR.
func best_target() -> Vector2:
	var best := -INF
	var best_pos := body[0]
	var c := TerrainData.CHUNK
	for i in terrain.air_chunks.size():
		var air := terrain.air_chunks[i]
		if air == 0:
			continue
		var center := Vector2((i % terrain.chunk_cols) * c, (i / terrain.chunk_cols) * c) + Vector2(c, c) / 2.0
		var score := air - DISTANCE_PENALTY * center.distance_to(body[0]) / c
		if score > best and not _near_base(center):
			best = score
			best_pos = center
	return best_pos


func _passable(p: Vector2) -> bool:
	return terrain.is_circle_passable(roundi(p.x), roundi(p.y), RADIUS) and not _near_base(p)


func _near_base(p: Vector2) -> bool:
	for rect in terrain.base_rects:
		if Rect2(rect).grow(BASE_CLEARANCE).has_point(p):
			return true
	return false


# Tail first, so the head stays on top; segments under the ground are faint and the tail tapers.
func _draw() -> void:
	for i in range(body.size() - 1, -1, -1):
		var p := body[i]
		var buried := TerrainData.is_diggable(terrain.get_cell(roundi(p.x), roundi(p.y)))
		var color := COLOR_HEAD if i == 0 else COLOR
		draw_circle(p - position, RADIUS * lerpf(1.0, 0.6, float(i) / body.size()), Color(color, BURIED_ALPHA if buried else 1.0))
