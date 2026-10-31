class_name TerrainRenderer
extends Sprite2D
## Mirrors TerrainData into one Image/ImageTexture. Uploads at most once per frame.

const COLOR_AIR := Color8(24, 14, 8)
const COLOR_BASE := Color8(46, 36, 30)
const DIRT_COLORS: Array[Color] = [Color8(166, 104, 42), Color8(148, 90, 34), Color8(184, 120, 52)]
const BEDROCK_COLORS: Array[Color] = [Color8(112, 112, 124), Color8(96, 96, 108)]
const GOLD_COLORS: Array[Color] = [Color8(255, 200, 40), Color8(230, 175, 20)]
const ENERGY_COLORS: Array[Color] = [Color8(70, 170, 255), Color8(40, 140, 235)]
const DRAIN_COLORS: Array[Color] = [Color8(220, 30, 30), Color8(190, 15, 20)]
const BASE_FLOOR_DARKEN := 0.75
# Pad tint and icon color in Tank.Upgrade order.
const PAD_COLORS: Array[Color] = [Color8(70, 120, 255), Color8(255, 210, 60), Color8(90, 230, 90), Color8(80, 230, 230)]
const PAD_TINT := 0.25
# PAD_SIZE x PAD_SIZE icons in Tank.Upgrade order; "#" is a lit pixel.
const PAD_ICONS := [
	[
		".........",
		".#######.",
		".#.....#.",
		".#.....#.",
		".#.....#.",
		"..#...#..",
		"...#.#...",
		"....#....",
		".........",
	],
	[
		".........",
		"...###...",
		".#######.",
		".#.....#.",
		".#.###.#.",
		".#.....#.",
		".#.###.#.",
		".#######.",
		".........",
	],
	[
		".........",
		"....#....",
		"...#.#...",
		"..#...#..",
		"....#....",
		"...#.#...",
		"..#...#..",
		".#.....#.",
		".........",
	],
	[
		".........",
		"...###...",
		"..#...#..",
		".#.....#.",
		".#..#..#.",
		".#.....#.",
		"..#...#..",
		"...###...",
		".........",
	],
]
# Special switch pads in other players' bases, in Tank.Special order.
const SPECIAL_COLORS: Array[Color] = [Color8(255, 140, 40), Color8(255, 60, 50), Color8(170, 255, 60), Color8(40, 200, 160)]
const SPECIAL_ICONS := [
	[
		".........",
		".#..#..#.",
		"..#.#.#..",
		"...###...",
		".#######.",
		"...###...",
		"...###...",
		"...###...",
		".........",
	],
	[
		".........",
		".........",
		".##......",
		".###.....",
		".#######.",
		".###.....",
		".##......",
		".........",
		".........",
	],
	[
		".........",
		"....#....",
		"...#.#...",
		"..#...#..",
		".#.....#.",
		".#.....#.",
		".#.....#.",
		"..#####..",
		".........",
	],
	[
		".........",
		"...###...",
		"..#...##.",
		".#...#.#.",
		".#..#..#.",
		".#.....#.",
		"..#...#..",
		"...###...",
		".........",
	],
]

var terrain: TerrainData
var image: Image
# Owner color per terrain.base_rects entry: walls use it directly, the floor a darkened shade.
var base_colors: Array[Color] = []
var _dirty := false


func bind(data: TerrainData) -> void:
	if terrain != null:
		terrain.cells_changed.disconnect(_on_cells_changed)
	terrain = data
	centered = false
	# Below the per-viewport pad overlays.
	z_index = -2
	image = Image.create(terrain.width, terrain.height, false, Image.FORMAT_RGBA8)
	_on_cells_changed(Rect2i(0, 0, terrain.width, terrain.height))
	texture = ImageTexture.create_from_image(image)
	_dirty = false
	terrain.cells_changed.connect(_on_cells_changed)


func _process(_delta: float) -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


func _on_cells_changed(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, _color_at(x, y))
	_dirty = true


func _color_at(x: int, y: int) -> Color:
	var noise := (x * 31 + y * 17 + (x ^ y)) % 6
	var cell := terrain.cells[y * terrain.width + x]
	if cell == TerrainData.BEDROCK or cell == TerrainData.BASE_START:
		var base_index := _base_owner(x, y)
		if base_index >= 0:
			if cell == TerrainData.BEDROCK:
				return base_colors[base_index]
			var floor_color := base_colors[base_index].darkened(BASE_FLOOR_DARKEN)
			var base := terrain.base_rects[base_index]
			var pad := TerrainData.pad_at(base, Vector2i(x, y))
			if pad < 0:
				return floor_color
			var local := Vector2i(x, y) - TerrainData.pad_rects(base)[pad].position
			if PAD_ICONS[pad][local.y][local.x] == "#":
				return PAD_COLORS[pad]
			return floor_color.lerp(PAD_COLORS[pad], PAD_TINT)
	match cell:
		TerrainData.DIRT:
			return DIRT_COLORS[noise % 3]
		TerrainData.BEDROCK:
			return BEDROCK_COLORS[noise % 2]
		TerrainData.GOLD:
			return GOLD_COLORS[noise % 2]
		TerrainData.ENERGY:
			return ENERGY_COLORS[noise % 2]
		TerrainData.DRAIN:
			return DRAIN_COLORS[noise % 2]
		TerrainData.BASE_START:
			return COLOR_BASE
	return COLOR_AIR


# Transparent except for the special pads in every base but own's, as player own sees them.
func pad_overlay(own: int) -> Image:
	var overlay := Image.create(terrain.width, terrain.height, false, Image.FORMAT_RGBA8)
	for i in mini(terrain.base_rects.size(), base_colors.size()):
		if i == own:
			continue
		var floor_color := base_colors[i].darkened(BASE_FLOOR_DARKEN)
		var rects := TerrainData.pad_rects(terrain.base_rects[i])
		for pad in rects.size():
			for y in TerrainData.PAD_SIZE:
				for x in TerrainData.PAD_SIZE:
					var lit: bool = SPECIAL_ICONS[pad][y][x] == "#"
					overlay.set_pixelv(rects[pad].position + Vector2i(x, y), SPECIAL_COLORS[pad] if lit else floor_color.lerp(SPECIAL_COLORS[pad], PAD_TINT))
	return overlay


func _base_owner(x: int, y: int) -> int:
	for i in mini(terrain.base_rects.size(), base_colors.size()):
		if terrain.base_rects[i].has_point(Vector2i(x, y)):
			return i
	return -1
