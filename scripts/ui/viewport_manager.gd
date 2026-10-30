class_name ViewportManager
extends Control
## Builds the split-screen grid. SubViewport_1 owns the World2D, the rest share it.

@export var camera_zoom: float = 4.0

var viewports: Array[SubViewport] = []
var cameras: Array[Camera2D] = []
var tanks: Array[Tank] = []
var world_root: Node2D

@onready var grid: GridContainer = $GridContainer


func _physics_process(_delta: float) -> void:
	update_cameras()


func build(player_count: int, map_size: Vector2i) -> void:
	for child in grid.get_children():
		child.free()
	viewports.clear()
	cameras.clear()
	tanks.clear()
	grid.columns = 3 if player_count > 4 else (2 if player_count > 1 else 1)

	for i in player_count:
		var container := SubViewportContainer.new()
		container.name = "SubViewportContainer_%d" % (i + 1)
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var viewport := SubViewport.new()
		viewport.name = "SubViewport_%d" % (i + 1)
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		container.add_child(viewport)
		grid.add_child(container)

		if i == 0:
			world_root = Node2D.new()
			world_root.name = "WorldRoot"
			viewport.add_child(world_root)
			var listener := AudioListener2D.new()
			viewport.add_child(listener)
			listener.make_current()
		else:
			viewport.world_2d = viewports[0].world_2d

		var cam := Camera2D.new()
		cam.name = "Camera2D_%d" % (i + 1)
		cam.zoom = Vector2(camera_zoom, camera_zoom)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
		viewport.add_child(cam)
		cam.make_current()

		viewports.append(viewport)
		cameras.append(cam)


func update_cameras() -> void:
	for i in mini(cameras.size(), tanks.size()):
		var cam := cameras[i]
		var tank := tanks[i]
		if is_instance_valid(tank):
			cam.global_position = tank.global_position
