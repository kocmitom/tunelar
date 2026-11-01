class_name SpiceBlow
extends Node2D
## Spice blow: clears all sand within RADIUS of a spice pocket, kills the worm there and hits the tanks there as hard as a full tank with 2 shield levels can take; every pocket it reaches blows too.
## Tanks it destroys are fined. The whole chain counts as one blow, so its kills go to whoever set it off, if they survive it. Then it plays a short expanding ring per center.

# A bit over half the sight radius of a level 1 radar.
static var RADIUS := 30
static var POCKET_RADIUS := 2
static var DURATION := 0.6
const COLOR := Color(1.0, 0.55, 0.15)

# Blow centers relative to the node.
var centers: Array[Vector2] = []
var _time: float = 0.0


func detonate(terrain: TerrainData, tanks: Array[Tank], worms: Array[Worm], cell: Vector2i, attacker: Tank) -> void:
	position = Vector2(cell)
	var queue: Array[Vector2i] = [cell]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for spice in terrain.blow_circle(c.x, c.y, RADIUS):
			if queue.all(func(q: Vector2i) -> bool: return q.distance_squared_to(spice) > 4 * POCKET_RADIUS * POCKET_RADIUS):
				queue.append(spice)
	for c in queue:
		centers.append(Vector2(c - cell))
	Sfx.play(Sfx.Kind.DESTROY, position)
	for worm in worms:
		if queue.any(func(c: Vector2i) -> bool: return worm.touches(Vector2(c), RADIUS)):
			worm.die()
	# Own bases stay safe, as from bullets.
	var damage := Tank.MAX_SHIELDS + 2 * Tank.SHIELDS_PER_LEVEL + 1
	var victims := 0
	for tank in tanks:
		if tank.is_dead or tank.home_rect.has_point(Vector2i(tank.global_position.round())):
			continue
		if not queue.any(func(c: Vector2i) -> bool: return tank.global_position.distance_to(Vector2(c)) <= RADIUS):
			continue
		tank.shields -= damage
		if tank.shields < 0.0:
			tank.fine()
			tank.destroy(attacker)
			if tank != attacker:
				victims += 1
	# An attacker caught in its own blow gets no kills.
	if attacker and not attacker.is_dead:
		attacker.kills += victims


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	for c in centers:
		draw_circle(c, RADIUS * (0.4 + 0.6 * t), Color(COLOR, 0.35 * (1.0 - t)))
		draw_arc(c, RADIUS * (0.4 + 0.6 * t), 0.0, TAU, 48, Color(COLOR, 1.0 - t), 1.5)
