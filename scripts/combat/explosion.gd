class_name Explosion
extends Node2D
## Carves a crater on detonation, then plays a short expanding ring.

const RADIUS := 8
const DURATION := 0.4

var _time: float = 0.0


func detonate(terrain: TerrainData) -> void:
	terrain.dig_circle(roundi(global_position.x), roundi(global_position.y), RADIUS)


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	draw_arc(Vector2.ZERO, RADIUS * (0.3 + t), 0.0, TAU, 24, Color(1.0, 0.7 - 0.5 * t, 0.1, 1.0 - t), 1.0)
