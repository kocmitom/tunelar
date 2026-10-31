class_name Jelly
extends Sprite2D
## Trail in its owner's color left by tanks with the jelly special; other tanks drive through it at digging speed and drain ENERGY_DRAIN_JELLY. Uploads at most once per frame.

static var LIFETIME_TICKS := 5 * GameManager.TICK_RATE
static var RADIUS := 1
const ALPHA := 0.5

var image: Image
var now: int = 0
# Tick each cell expires at, 0 without jelly.
var _expiry: PackedInt32Array
var _owner: PackedByteArray
# Vector2i(cell index, expiry) in laying order, so the oldest is first.
var _queue: Array[Vector2i] = []
var _dirty := false


func _init() -> void:
	centered = false


func reset(size: Vector2i) -> void:
	image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	_expiry.resize(size.x * size.y)
	_expiry.fill(0)
	_owner.resize(size.x * size.y)
	_queue.clear()
	now = 0
	_dirty = false


func _process(_delta: float) -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


func lay(center: Vector2, owner_id: int, color: Color) -> void:
	var w := image.get_width()
	var c := Vector2i(center.round())
	for y in range(maxi(c.y - RADIUS, 0), mini(c.y + RADIUS, image.get_height() - 1) + 1):
		for x in range(maxi(c.x - RADIUS, 0), mini(c.x + RADIUS, w - 1) + 1):
			var i := y * w + x
			_expiry[i] = now + LIFETIME_TICKS
			_owner[i] = owner_id
			_queue.append(Vector2i(i, now + LIFETIME_TICKS))
			image.set_pixel(x, y, Color(color, ALPHA))
	_dirty = true


# Advances one tick; a cell laid again since an entry was queued keeps its newer expiry.
func step() -> void:
	now += 1
	var w := image.get_width()
	while not _queue.is_empty() and _queue[0].y <= now:
		var entry: Vector2i = _queue.pop_front()
		if _expiry[entry.x] == entry.y:
			_expiry[entry.x] = 0
			image.set_pixel(entry.x % w, entry.x / w, Color.TRANSPARENT)
			_dirty = true


# True when any cell under the tank holds another player's jelly.
func slows(tank: Tank) -> bool:
	var w := image.get_width()
	var c := Vector2i(tank.global_position.round())
	var r := tank.tank_radius
	for y in range(maxi(c.y - r, 0), mini(c.y + r, image.get_height() - 1) + 1):
		for x in range(maxi(c.x - r, 0), mini(c.x + r, w - 1) + 1):
			var i := y * w + x
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r * r and _expiry[i] > 0 and _owner[i] != tank.player_id:
				return true
	return false
