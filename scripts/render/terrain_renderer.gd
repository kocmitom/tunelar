class_name TerrainRenderer
extends Sprite2D
## Mirrors TerrainData into one Image/ImageTexture. Uploads at most once per frame.

const COLOR_AIR := Color8(24, 14, 8)
const COLOR_BASE := Color8(46, 36, 30)
const DIRT_COLORS: Array[Color] = [Color8(166, 104, 42), Color8(148, 90, 34), Color8(184, 120, 52)]
const BEDROCK_COLORS: Array[Color] = [Color8(112, 112, 124), Color8(96, 96, 108)]
const BASE_FLOOR_DARKEN := 0.75

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
			return base_colors[base_index] if cell == TerrainData.BEDROCK else base_colors[base_index].darkened(BASE_FLOOR_DARKEN)
	match cell:
		TerrainData.DIRT:
			return DIRT_COLORS[noise % 3]
		TerrainData.BEDROCK:
			return BEDROCK_COLORS[noise % 2]
		TerrainData.BASE_START:
			return COLOR_BASE
	return COLOR_AIR


func _base_owner(x: int, y: int) -> int:
	for i in mini(terrain.base_rects.size(), base_colors.size()):
		if terrain.base_rects[i].has_point(Vector2i(x, y)):
			return i
	return -1
