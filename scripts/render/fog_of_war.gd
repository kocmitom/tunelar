class_name FogOfWar
extends Sprite2D
## One player's fog over the whole world: dark until that player's tank has explored a cell, then the terrain as last seen, dimmed.
## Explored cells within the tank's sight circle are clear, so tanks and bullets elsewhere stay hidden. Uploads at most once per frame.

# The explored circle is this many tank sizes across.
const REVEAL_TANK_SIZES := 4
# The sight circle is this many times wider than the explored circle.
const SIGHT_SCALE := 3
# The first reveal of a round is this much wider than the driving reveal.
const SPAWN_REVEAL_SCALE := 2
const COLOR_FOG := Color8(34, 40, 64)
# How far explored terrain is blended toward COLOR_FOG.
const EXPLORED_DIM := 0.5

var image: Image
var terrain_image: Image
# This player's pad overlay; its opaque pixels replace the terrain as last seen.
var pads_image: Image
var _explored: PackedByteArray
var _view_center := Vector2i.ZERO
var _view_radius := -1
var _dirty := false


func _init() -> void:
	centered = false
	z_index = 10


func reset(terrain: Image, pads: Image) -> void:
	terrain_image = terrain
	pads_image = pads
	image = Image.create(terrain.get_width(), terrain.get_height(), false, Image.FORMAT_RGBA8)
	image.fill(COLOR_FOG)
	texture = ImageTexture.create_from_image(image)
	_explored.resize(terrain.get_width() * terrain.get_height())
	_explored.fill(0)
	_view_radius = -1
	_dirty = false


func _process(_delta: float) -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


# Explores the circle of radius, then moves the sight circle (SIGHT_SCALE times wider) to center.
func reveal(center: Vector2, radius: int) -> void:
	var c := Vector2i(roundi(center.x), roundi(center.y))
	var sight := radius * SIGHT_SCALE
	if c == _view_center and sight == _view_radius:
		return
	var w := image.get_width()
	var h := image.get_height()
	var r2 := radius * radius
	# Newly explored cells always lie inside the new sight circle, so they go clear.
	for y in range(maxi(c.y - radius, 0), mini(c.y + radius, h - 1) + 1):
		for x in range(maxi(c.x - radius, 0), mini(c.x + radius, w - 1) + 1):
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r2 and _explored[y * w + x] == 0:
				_explored[y * w + x] = 1
				image.set_pixel(x, y, Color.TRANSPARENT)
				_dirty = true
	# Only cells between the old and new sight circles change, so each row touches just the span difference.
	var y0 := c.y - sight
	var y1 := c.y + sight
	if _view_radius >= 0:
		y0 = mini(y0, _view_center.y - _view_radius)
		y1 = maxi(y1, _view_center.y + _view_radius)
	for y in range(maxi(y0, 0), mini(y1, h - 1) + 1):
		var o := _span(_view_center, _view_radius, y)
		var n := _span(c, sight, y)
		_set_live(y, o.x, mini(o.y, n.x - 1), false)
		_set_live(y, maxi(o.x, n.y + 1), o.y, false)
		_set_live(y, n.x, mini(n.y, o.x - 1), true)
		_set_live(y, maxi(n.x, o.y + 1), n.y, true)
	_view_center = c
	_view_radius = sight


# Columns of row y inside the circle, or an inverted span that misses every column.
static func _span(center: Vector2i, radius: int, y: int) -> Vector2i:
	var dy := y - center.y
	if radius < 0 or dy * dy > radius * radius:
		return Vector2i(1 << 30, -(1 << 30))
	var dx := int(sqrt(radius * radius - dy * dy))
	return Vector2i(center.x - dx, center.x + dx)


# Explored cells x0..x1 of row y go clear in sight, otherwise back to the terrain as last seen.
func _set_live(y: int, x0: int, x1: int, live: bool) -> void:
	var w := image.get_width()
	for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
		if _explored[y * w + x] == 0:
			continue
		var seen := pads_image.get_pixel(x, y)
		if seen.a == 0.0:
			seen = terrain_image.get_pixel(x, y)
		image.set_pixel(x, y, Color.TRANSPARENT if live else seen.lerp(COLOR_FOG, EXPLORED_DIM))
		_dirty = true


static func reveal_radius(tank_radius: int) -> int:
	return REVEAL_TANK_SIZES * (2 * tank_radius + 1) / 2
