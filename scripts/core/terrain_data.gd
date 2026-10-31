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

const BORDER := 2
const BASE_SIZE := 31
const BASE_DOOR := 9
const PAD_SIZE := 9
const ROCK_COVERAGE := 0.05
const ROCK_RADIUS_MIN := 5.0
const ROCK_RADIUS_MAX := 11.0
const ROCK_STRETCH_MAX := 2.2
const ROCK_WOBBLE := 0.25
const GOLD_COVERAGE := 0.01
const GOLD_RADIUS_MIN := 2.0
const GOLD_RADIUS_MAX := 4.0
# Money per dug gold cell; a dirt cell is worth 1.
const GOLD_VALUE := 10
const ENERGY_COVERAGE := 0.005
const ENERGY_RADIUS_MIN := 2.0
const ENERGY_RADIUS_MAX := 4.0
# Battery recharged per dug energy cell, so bigger blobs give more.
const ENERGY_VALUE := 1.0
# Slot order spreads the first bases far apart on the 3x2 region grid.
const SLOT_ORDER: Array[int] = [0, 5, 2, 3, 1, 4]

var width: int
var height: int
var cells: PackedByteArray
var map_seed: int = 0
var base_rects: Array[Rect2i] = []
# Energy cells removed by the last dig_circle call.
var dug_energy: int = 0


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
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy > r2:
				continue
			var i := y * width + x
			if cells[i] == DIRT or cells[i] == GOLD or cells[i] == ENERGY:
				dug += GOLD_VALUE if cells[i] == GOLD else 1
				dug_energy += 1 if cells[i] == ENERGY else 0
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
	var region := Vector2i(width / 3, height / 2)
	var max_jitter := (region - Vector2i(BASE_SIZE, BASE_SIZE)) / 2 - Vector2i(6, 6)
	for i in mini(base_count, SLOT_ORDER.size()):
		var slot := SLOT_ORDER[i]
		var center := Vector2i((slot % 3) * region.x + region.x / 2, (slot / 3) * region.y + region.y / 2)
		center += Vector2i(rng.randi_range(-max_jitter.x, max_jitter.x), rng.randi_range(-max_jitter.y, max_jitter.y))
		base_rects.append(Rect2i(center - Vector2i(BASE_SIZE / 2, BASE_SIZE / 2), Vector2i(BASE_SIZE, BASE_SIZE)))

	_place_blobs(rng, BEDROCK, ROCK_COVERAGE, ROCK_RADIUS_MIN, ROCK_RADIUS_MAX)
	_place_blobs(rng, GOLD, GOLD_COVERAGE, GOLD_RADIUS_MIN, GOLD_RADIUS_MAX)
	_place_blobs(rng, ENERGY, ENERGY_COVERAGE, ENERGY_RADIUS_MIN, ENERGY_RADIUS_MAX)
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
