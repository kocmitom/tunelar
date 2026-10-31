class_name Laser
extends Node2D
## Instant beam: runs through open cells until dirt, bedrock, a tank or a worm, then shows a short red line.

static var LIFETIME := 0.15
const COLOR := Color(1.0, 0.15, 0.1)

var terrain: TerrainData
var tanks: Array[Tank] = []
var worms: Array[Worm] = []
var shooter: Tank
# End of the beam, relative to the muzzle.
var end: Vector2 = Vector2.ZERO
var _time: float = 0.0


# 1 px steps from the muzzle; dirt stops the beam without being dug, but a worm buried right behind it is still hit.
func fire(dir: Vector2) -> void:
	var p := global_position
	while true:
		var worm := _worm_at(p)
		if worm:
			worm.hit()
			break
		var cell := terrain.get_cell(roundi(p.x), roundi(p.y))
		if cell != TerrainData.AIR and cell != TerrainData.BASE_START:
			break
		var target := _tank_at(p)
		if target:
			target.hit(shooter)
			break
		p += dir
	end = p - global_position
	queue_redraw()


func _tank_at(p: Vector2) -> Tank:
	for tank in tanks:
		if tank != shooter and not tank.is_dead and tank.global_position.distance_to(p) <= tank.tank_radius + 0.5:
			return tank
	return null


func _worm_at(p: Vector2) -> Worm:
	for worm in worms:
		if worm.touches(p, 0.5):
			return worm
	return null


func step(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()


func _draw() -> void:
	draw_line(Vector2.ZERO, end, COLOR, 1.0)
