class_name TerrainData
extends RefCounted
## Pure grid model of the destructible terrain. One byte per cell.

signal cells_changed(rect: Rect2i)

const AIR := 0
const DIRT := 1
const BEDROCK := 2
const BASE_START := 3
const GOLD := 4
const ENERGY := 5
const DRAIN := 6

const BORDER := 2
const BASE_SIZE := 33
const BASE_DOOR := 11
const PAD_SIZE := 9
static var ROCK_COVERAGE := 0.05
static var ROCK_RADIUS_MIN := 5.0
static var ROCK_RADIUS_MAX := 11.0
static var ROCK_STRETCH_MAX := 2.2
static var ROCK_WOBBLE := 0.25
static var GOLD_COVERAGE := 0.01
static var GOLD_RADIUS_MIN := 2.0
static var GOLD_RADIUS_MAX := 4.0
# Money per dug gold cell; a dirt cell is worth 1.
static var GOLD_VALUE := 10
static var ENERGY_COVERAGE := 0.005
static var ENERGY_RADIUS_MIN := 2.0
static var ENERGY_RADIUS_MAX := 4.0
# Battery recharged per dug energy cell, so bigger blobs give more.
static var ENERGY_VALUE := 1.0
# Red blobs the size of energy blobs; each dug cell drains DRAIN_VALUE from the battery.
static var DRAIN_COVERAGE := 0.005
static var DRAIN_VALUE := 1.0
# Bases sit evenly on a circle of RING_RADIUS half-sides, each shifted by up to RING_JITTER of the gap to its neighbors.
static var RING_RADIUS := 0.6
static var RING_JITTER := 0.15
# Solid rock beyond a wobbly outline between the circle of EDGE_IN and EDGE_OUT half-sides, so the map reads as an irregular cave and its edge is never reached.
static var EDGE_IN := 0.76
static var EDGE_OUT := 0.9
# Between the bases, away from their sides, bays reach in down to EDGE_DEEP half-sides.
static var EDGE_DEEP := 0.55
# Clearance kept beside a base, in pixels, before the bays may deepen.
static var EDGE_BASE_CLEAR := 36.0
# The outline is computed once per direction bin.
static var EDGE_BINS := 720
# How far the outer limit bulges from the EDGE_OUT circle toward the EDGE_OUT square, into the corners.
static var EDGE_SQUARE := 0.5
# Noise frequency around the unit circle, so every map size gets the same number of lobes.
static var EDGE_FREQUENCY := 1.2
static var EDGE_CONTRAST := 0.7
# Pixel-scale roughness on top of the lobes, in half-sides, for rock fingers, bays and islands.
static var EDGE_ROUGH := 0.05
static var EDGE_ROUGH_FREQUENCY := 0.04

var width: int
var height: int
var cells: PackedByteArray
var map_seed: int = 0
var base_rects: Array[Rect2i] = []
# Energy and drain cells removed by the last dig_circle call.
var dug_energy: int = 0
var dug_drain: int = 0


func _init(w: int = 320, h: int = 200) -> void:
	width = w
	height = h
	cells.resize(width * height)
	cells.fill(DIRT)
	_stamp_border()


func get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return BEDROCK
	return cells[y * width + x]


func set_cell(x: int, y: int, value: int) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	cells[y * width + x] = value
	cells_changed.emit(Rect2i(x, y, 1, 1))


static func is_diggable(cell: int) -> bool:
	return cell == DIRT or cell == GOLD or cell == ENERGY or cell == DRAIN


func is_passable(x: int, y: int) -> bool:
	return get_cell(x, y) != BEDROCK


func is_circle_passable(cx: int, cy: int, radius: int) -> bool:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= r2 and get_cell(cx + dx, cy + dy) == BEDROCK:
				return false
	return true


func dig_circle(cx: int, cy: int, radius: int) -> int:
	var x0 := maxi(cx - radius, 0)
	var y0 := maxi(cy - radius, 0)
	var x1 := mini(cx + radius, width - 1)
	var y1 := mini(cy + radius, height - 1)
	var r2 := radius * radius
	var dug := 0
	dug_energy = 0
	dug_drain = 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy > r2:
				continue
			var i := y * width + x
			if is_diggable(cells[i]):
				dug += GOLD_VALUE if cells[i] == GOLD else 1
				dug_energy += 1 if cells[i] == ENERGY else 0
				dug_drain += 1 if cells[i] == DRAIN else 0
				cells[i] = AIR
	if dug > 0:
		cells_changed.emit(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	return dug


# Upgrade pads in the base's inner corners, in Tank.Upgrade order: top-left, top-right, bottom-left, bottom-right.
static func pad_rects(base: Rect2i) -> Array[Rect2i]:
	var inner := base.grow(-1)
	var far := inner.size - Vector2i(PAD_SIZE, PAD_SIZE)
	var rects: Array[Rect2i] = []
	for corner in [Vector2i(0, 0), Vector2i(far.x, 0), Vector2i(0, far.y), far]:
		rects.append(Rect2i(inner.position + corner, Vector2i(PAD_SIZE, PAD_SIZE)))
	return rects


static func pad_at(base: Rect2i, point: Vector2i) -> int:
	var rects := pad_rects(base)
	for i in rects.size():
		if rects[i].has_point(point):
			return i
	return -1


func generate(new_seed: int, base_count: int) -> void:
	map_seed = new_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed

	cells.fill(DIRT)
	_stamp_border()

	base_rects.clear()
	var center := Vector2(width, height) / 2.0
	var ring := RING_RADIUS * minf(width, height) / 2.0
	var start := rng.randf() * TAU
	for i in base_count:
		var angle := start + TAU * (i + rng.randf_range(-RING_JITTER, RING_JITTER)) / base_count
		var c := Vector2i((center + Vector2.from_angle(angle) * ring).round())
		base_rects.append(Rect2i(c - Vector2i(BASE_SIZE / 2, BASE_SIZE / 2), Vector2i(BASE_SIZE, BASE_SIZE)))

	_place_blobs(rng, BEDROCK, ROCK_COVERAGE, ROCK_RADIUS_MIN, ROCK_RADIUS_MAX)
	_place_blobs(rng, GOLD, GOLD_COVERAGE, GOLD_RADIUS_MIN, GOLD_RADIUS_MAX)
	_place_blobs(rng, ENERGY, ENERGY_COVERAGE, ENERGY_RADIUS_MIN, ENERGY_RADIUS_MAX)
	_place_blobs(rng, DRAIN, DRAIN_COVERAGE, ENERGY_RADIUS_MIN, ENERGY_RADIUS_MAX)
	_stamp_edge(rng)
	for rect in base_rects:
		_stamp_base(rect)

	cells_changed.emit(Rect2i(0, 0, width, height))


# Scatters a few formations of cell (stretched, noise-edged blobs) over dirt until coverage is reached.
func _place_blobs(rng: RandomNumberGenerator, cell: int, coverage: float, radius_min: float, radius_max: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.15
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	var target := int(coverage * width * height)
	var placed := 0
	var attempts := 0
	while placed < target and attempts < target / 10:
		attempts += 1
		var radius := rng.randf_range(radius_min, radius_max)
		var stretch := rng.randf_range(1.0, ROCK_STRETCH_MAX)
		var axis := Vector2.from_angle(rng.randf() * PI)
		var center := Vector2(rng.randf_range(BORDER, width - BORDER), rng.randf_range(BORDER, height - BORDER))
		if _near_base(center, radius * stretch * (1.0 + ROCK_WOBBLE)):
			continue
		placed += _stamp_blob(cell, center, radius, stretch, axis, noise)


func _near_base(point: Vector2, reach: float) -> bool:
	for rect in base_rects:
		if Rect2(rect).grow(reach + 6.0).has_point(point):
			return true
	return false


# Flood fills from the center so the noisy edge never leaves detached specks.
func _stamp_blob(cell: int, center: Vector2, radius: float, stretch: float, axis: Vector2, noise: FastNoiseLite) -> int:
	var start := Vector2i(center.round())
	var stack: Array[Vector2i] = [start]
	var visited := {start: true}
	var count := 0
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			continue
		var offset := Vector2(p) - center
		var shape := Vector2(offset.dot(axis) / stretch, offset.dot(axis.orthogonal()))
		if shape.length() / radius + noise.get_noise_2d(p.x, p.y) * ROCK_WOBBLE > 1.0:
			continue
		var i := p.y * width + p.x
		if cells[i] == DIRT:
			cells[i] = cell
			count += 1
		for n in [p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN]:
			if not visited.has(n):
				visited[n] = true
				stack.append(n)
	return count


# Lobes follow the direction from the center; the roughness adds fingers and islands without ever reaching inside the inner limit.
func _stamp_edge(rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = EDGE_FREQUENCY
	var rough := FastNoiseLite.new()
	rough.seed = rng.randi()
	rough.frequency = EDGE_ROUGH_FREQUENCY
	var center := Vector2(width, height) / 2.0
	var half := minf(width, height) / 2.0
	var base_angles: Array[float] = []
	for rect in base_rects:
		base_angles.append((Vector2(rect.get_center()) - center).angle())
	var clear_angle := EDGE_BASE_CLEAR / (RING_RADIUS * half)
	var edges := PackedFloat32Array()
	edges.resize(EDGE_BINS)
	for i in EDGE_BINS:
		var angle := -PI + TAU * (i + 0.5) / EDGE_BINS
		var dir := Vector2.from_angle(angle)
		var nearest := PI
		for a in base_angles:
			nearest = minf(nearest, absf(angle_difference(angle, a)))
		var inner := lerpf(EDGE_IN, EDGE_DEEP, smoothstep(clear_angle, 2.0 * clear_angle, nearest))
		var outer := lerpf(EDGE_OUT, EDGE_OUT / maxf(absf(dir.x), absf(dir.y)), EDGE_SQUARE)
		var n := clampf(noise.get_noise_2d(dir.x, dir.y) * EDGE_CONTRAST + 0.5, 0.0, 1.0)
		edges[i] = lerpf(inner + EDGE_ROUGH, outer - EDGE_ROUGH, n)
	for y in height:
		for x in width:
			var offset := Vector2(x, y) - center
			var d := offset.length() / half
			if d < EDGE_DEEP:
				continue
			var bin := clampi(int((offset.angle() + PI) / TAU * EDGE_BINS), 0, EDGE_BINS - 1)
			if d > edges[bin] + EDGE_ROUGH * rough.get_noise_2d(x, y):
				cells[y * width + x] = BEDROCK


func _stamp_border() -> void:
	for b in BORDER:
		for x in width:
			cells[b * width + x] = BEDROCK
			cells[(height - 1 - b) * width + x] = BEDROCK
		for y in height:
			cells[y * width + b] = BEDROCK
			cells[y * width + width - 1 - b] = BEDROCK


func _stamp_base(rect: Rect2i) -> void:
	var clear := rect.grow(4)
	for y in range(clear.position.y, clear.end.y):
		for x in range(clear.position.x, clear.end.x):
			if cells[y * width + x] == BEDROCK:
				cells[y * width + x] = DIRT

	var door_x0 := rect.position.x + (BASE_SIZE - BASE_DOOR) / 2
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var on_wall := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
			var in_door := (y == rect.position.y or y == rect.end.y - 1) and x >= door_x0 and x < door_x0 + BASE_DOOR
			if on_wall and not in_door:
				cells[y * width + x] = BEDROCK
			elif on_wall:
				cells[y * width + x] = AIR
			else:
				cells[y * width + x] = BASE_START
