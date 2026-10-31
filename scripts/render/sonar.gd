class_name Sonar
extends Node2D
## Radar special: a line sweeping around the own tank that flares up yellow while it points at another player.

const LENGTH := 14.0
const TURN_TIME := 1.5
const HIT_ANGLE := PI / 12.0
const COLOR := Color(0.4, 1.0, 0.5)
const HIT_COLOR := Color(1.0, 0.9, 0.2)

# Directions to the other living tanks.
var angles: Array[float] = []
# Purely visual, so it runs on frame time outside the lockstep simulation.
var _sweep: float = 0.0


func _process(delta: float) -> void:
	_sweep = fmod(_sweep + TAU * delta / TURN_TIME, TAU)
	queue_redraw()


func _draw() -> void:
	var hit := angles.any(func(a: float) -> bool: return absf(angle_difference(_sweep, a)) <= HIT_ANGLE)
	draw_line(Vector2.ZERO, Vector2.from_angle(_sweep) * LENGTH, HIT_COLOR if hit else Color(COLOR, 0.5), 1.5 if hit else 0.75)
