class_name ViewportManager
extends Control
## Builds the split-screen grid. SubViewport_1 owns the World2D, the rest share it.

const SPECTATE_SPEED := 240.0

@export var camera_zoom: float = 4.0

var viewports: Array[SubViewport] = []
var cameras: Array[Camera2D] = []
var fogs: Array[FogOfWar] = []
var tanks: Array[Tank] = []
var slots: Array[int] = []
var world_root: Node2D
var map_shown: bool = false

@onready var grid: GridContainer = $GridContainer
@onready var version_label: Label = $VersionLabel
@onready var round_restart_button: Button = $RoundRestartButton


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	version_label.text = "v%s" % version
	get_window().title = "%s v%s" % [ProjectSettings.get_setting("application/config/name"), version]


# One viewport per local slot; viewport i follows tanks[local_slots[i]].
func build(local_slots: Array[int], map_size: Vector2i) -> void:
	for child in grid.get_children():
		child.free()
	viewports.clear()
	cameras.clear()
	fogs.clear()
	tanks.clear()
	slots = local_slots
	var count := local_slots.size()
	grid.columns = 3 if count > 4 else (2 if count > 1 else 1)

	for i in count:
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
		cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
		viewport.add_child(cam)
		cam.make_current()

		viewports.append(viewport)
		cameras.append(cam)

	# Fog i sits on its own visibility layer, which only viewport i draws.
	for i in count:
		var fog := FogOfWar.new()
		fog.name = "FogOfWar_%d" % (i + 1)
		fog.visibility_layer = 1 << (i + 1)
		viewports[i].canvas_cull_mask = 1 | fog.visibility_layer
		world_root.add_child(fog)
		fogs.append(fog)


func reset_fog(map_size: Vector2i) -> void:
	for i in fogs.size():
		var tank := tanks[slots[i]]
		fogs[i].reset(map_size)
		fogs[i].visible = true
		fogs[i].reveal(tank.global_position, FogOfWar.SPAWN_REVEAL_SCALE * tank.reveal_radius())


# At the end of a round every viewport spectates until someone goes back to the lobby.
func show_map(shown: bool) -> void:
	map_shown = shown
	round_restart_button.visible = shown


func _on_restart_button_pressed() -> void:
	Net.request_lobby()


func _on_round_restart_button_pressed() -> void:
	Net.request_lobby()


# Each camera follows its tank, and the tank reveals the fog of that viewport.
# A dead tank's viewport, or every viewport once the map is shown, drops its fog and pans with that player's move input.
func update_cameras(inputs: Array[Dictionary] = [], delta: float = 0.0) -> void:
	for i in cameras.size():
		var cam := cameras[i]
		var tank := tanks[slots[i]]
		if not is_instance_valid(tank):
			continue
		if tank.is_dead or map_shown:
			fogs[i].visible = false
			if not inputs.is_empty():
				var half := Vector2(viewports[i].size) / cam.zoom / 2.0
				var pos: Vector2 = cam.global_position + inputs[slots[i]]["move"] * SPECTATE_SPEED * delta
				cam.global_position = pos.clamp(half, Vector2(cam.limit_right, cam.limit_bottom) - half)
		else:
			cam.global_position = tank.global_position
			fogs[i].reveal(tank.global_position, tank.reveal_radius())
