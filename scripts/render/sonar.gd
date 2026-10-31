class_name Sonar
extends Node2D
## Radar special: a line sweeping around the own tank that flares up in a player's color while it points at them, longer the closer they are.

const LENGTH := 14.0
const TURN_TIME := 1.5
const HIT_ANGLE := PI / 12.0
const COLOR := Color(0.4, 1.0, 0.5)
# Flare is 2x long up to NEAR view radii away, shrinking linearly to 0.5x at FAR.
const NEAR := 2.0
const FAR := 10.0

# Directions, distances and colors of the other living tanks.
var angles: Array[float] = []
var distances: Array[float] = []
var colors: Array[Color] = []
# Reveal radius of the own tank.
var radius: float = LENGTH
# Purely visual, so it runs on frame time outside the lockstep simulation.
var _sweep: float = 0.0


func _process(delta: float) -> void:
	_sweep = fmod(_sweep + TAU * delta / TURN_TIME, TAU)
	queue_redraw()


func _draw() -> void:
	var hit := -1
	for i in angles.size():
		if absf(angle_difference(_sweep, angles[i])) <= HIT_ANGLE and (hit < 0 or distances[i] < distances[hit]):
			hit = i
	if hit < 0:
		draw_line(Vector2.ZERO, Vector2.from_angle(_sweep) * LENGTH, Color(COLOR, 0.5), 0.75)
		return
	var t := clampf((distances[hit] - NEAR * radius) / ((FAR - NEAR) * radius), 0.0, 1.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(_sweep) * LENGTH * lerpf(2.0, 0.5, t), colors[hit], 1.5)
