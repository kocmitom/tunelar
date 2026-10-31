class_name FogOfWar
extends Sprite2D
## One player's fog over the whole world: dark until that player's tank has seen a cell. Uploads at most once per frame.

# The revealed circle is this many tank sizes across.
const REVEAL_TANK_SIZES := 4
# The first reveal of a round is this much wider than the driving reveal.
const SPAWN_REVEAL_SCALE := 2
const COLOR_FOG := Color8(34, 40, 64)

var image: Image
var _dirty := false


func _init() -> void:
	centered = false
	z_index = 10


func reset(size: Vector2i) -> void:
	image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_FOG)
	texture = ImageTexture.create_from_image(image)
	_dirty = false


func _process(_delta: float) -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


func reveal(center: Vector2, radius: int) -> void:
	var cx := roundi(center.x)
	var cy := roundi(center.y)
	var r2 := radius * radius
	for y in range(maxi(cy - radius, 0), mini(cy + radius, image.get_height() - 1) + 1):
		for x in range(maxi(cx - radius, 0), mini(cx + radius, image.get_width() - 1) + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2 and image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
				_dirty = true


static func reveal_radius(tank_radius: int) -> int:
	return REVEAL_TANK_SIZES * (2 * tank_radius + 1) / 2
