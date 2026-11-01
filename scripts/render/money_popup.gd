class_name MoneyPopup
extends Node2D
## Money spent or lost: "-$N" rising from the tank and fading out.

static var DURATION := 2.0
static var RISE := 16.0
const FONT_SIZE := 6
const COLOR := Color(1.0, 0.3, 0.2)

var amount: int = 0
var _time: float = 0.0


# Under the fog, so it only shows where the player can see.
func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	var alpha := clampf(2.0 - 2.0 * t, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var text := "-$%d" % amount
	var pos := Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, -RISE * t)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color(Color.BLACK, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(COLOR, alpha))
