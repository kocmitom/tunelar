class_name FogOfWar
extends Sprite2D
## One player's fog over the whole world: dark until that player's tank has seen a cell, then the terrain as last seen, dimmed.
## Only the tank's current view circle is clear, so tanks and bullets elsewhere stay hidden. Uploads at most once per frame.

# The revealed circle is this many tank sizes across.
const REVEAL_TANK_SIZES := 4
# The first reveal of a round is this much wider than the driving reveal.
const SPAWN_REVEAL_SCALE := 2
const COLOR_FOG := Color8(34, 40, 64)
# How far explored terrain is blended toward COLOR_FOG.
const EXPLORED_DIM := 0.5

var image: Image
var terrain_image: Image
var _view_center := Vector2i.ZERO
var _view_radius := -1
var _dirty := false


func _init() -> void:
	centered = false
	z_index = 10


func reset(terrain: Image) -> void:
	terrain_image = terrain
	image = Image.create(terrain.get_width(), terrain.get_height(), false, Image.FORMAT_RGBA8)
	image.fill(COLOR_FOG)
	texture = ImageTexture.create_from_image(image)
	_view_radius = -1
	_dirty = false


func _process(_delta: float) -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


func reveal(center: Vector2, radius: int) -> void:
	var c := Vector2i(roundi(center.x), roundi(center.y))
	if c == _view_center and radius == _view_radius:
		return
	var r2 := radius * radius
	# Cells leaving the view keep the terrain as it was last seen.
	var old_r2 := _view_radius * _view_radius
	for y in range(maxi(_view_center.y - _view_radius, 0), mini(_view_center.y + _view_radius, image.get_height() - 1) + 1):
		for x in range(maxi(_view_center.x - _view_radius, 0), mini(_view_center.x + _view_radius, image.get_width() - 1) + 1):
			if (Vector2i(x, y) - _view_center).length_squared() <= old_r2 and (Vector2i(x, y) - c).length_squared() > r2:
				image.set_pixel(x, y, terrain_image.get_pixel(x, y).lerp(COLOR_FOG, EXPLORED_DIM))
				_dirty = true
	for y in range(maxi(c.y - radius, 0), mini(c.y + radius, image.get_height() - 1) + 1):
		for x in range(maxi(c.x - radius, 0), mini(c.x + radius, image.get_width() - 1) + 1):
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r2 and image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
				_dirty = true
	_view_center = c
	_view_radius = radius


static func reveal_radius(tank_radius: int) -> int:
	return REVEAL_TANK_SIZES * (2 * tank_radius + 1) / 2
