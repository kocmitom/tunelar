class_name Bullet
extends Node2D
## Grid-stepped projectile: dents dirt, ricochets off bedrock, hits tanks.

const BULLET_SPEED := 180.0
const MAX_BOUNCES := 2
const DENT_RADIUS := 3
const COLOR := Color(1.0, 0.95, 0.5)

var terrain: TerrainData
var tanks: Array[Tank] = []
var shooter: Tank
# Credited with the hit instead of the shooter when set, as for shrapnel.
var attacker: Tank
var velocity: Vector2 = Vector2.ZERO
var bounces: int = 0
var max_bounces: int = MAX_BOUNCES
# Tanks already hit by this bullet's volley, shared by all its bullets; each takes one hit per volley.
var volley: Array[Tank] = []
var is_dead: bool = false


func _draw() -> void:
	draw_rect(Rect2(-0.5, -0.5, 1.0, 1.0), COLOR)


func step(delta: float) -> void:
	if is_dead:
		return
	# 1 px substeps so fast bullets never skip a cell.
	var steps := ceili(velocity.length() * delta)
	for i in steps:
		var next := global_position + velocity * delta / steps
		var cell := terrain.get_cell(roundi(next.x), roundi(next.y))
		if cell == TerrainData.BEDROCK:
			if bounces >= max_bounces:
				_die()
				return
			bounces += 1
			velocity = velocity.bounce(_wall_normal(next))
			continue
		global_position = next
		if TerrainData.is_diggable(cell):
			terrain.dig_circle(roundi(next.x), roundi(next.y), DENT_RADIUS)
			_die()
			return
		for tank in tanks:
			if tank != shooter and not tank.is_dead and tank.global_position.distance_to(next) <= tank.tank_radius + 0.5:
				if tank not in volley:
					volley.append(tank)
					tank.hit(attacker if attacker else shooter)
				_die()
				return


func _wall_normal(next: Vector2) -> Vector2:
	var normal := Vector2.ZERO
	if terrain.get_cell(roundi(next.x), roundi(global_position.y)) == TerrainData.BEDROCK:
		normal.x = -signf(velocity.x)
	if terrain.get_cell(roundi(global_position.x), roundi(next.y)) == TerrainData.BEDROCK:
		normal.y = -signf(velocity.y)
	if normal == Vector2.ZERO:
		normal = -velocity.sign()
	return normal.normalized()


func _die() -> void:
	is_dead = true
	queue_free()
