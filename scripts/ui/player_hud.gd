class_name PlayerHud
extends CanvasLayer
## Per-viewport overlay: battery gauge, radar compass, wins and round banner.

const RADAR_RADIUS := 22.0
const NEEDLE_COLOR := Color(1.0, 0.25, 0.2)

var player_id: int = 0
var color: Color = Color.WHITE
var _radar_dir: Vector2 = Vector2.ZERO

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var wins_label: Label = $WinsLabel
@onready var radar: Control = $Radar
@onready var banner: Label = $Banner


func _ready() -> void:
	radar.draw.connect(_draw_radar)
	banner.hide()


func setup(id: int, player_color: Color) -> void:
	player_id = id
	color = player_color
	energy_bar.self_modulate = color
	radar.queue_redraw()


func update_hud(tank: Tank, wins: int) -> void:
	energy_bar.value = tank.energy
	wins_label.text = "P%d  WINS %d" % [player_id + 1, wins]
	var dir := tank.radar_dir if tank.radar_time > 0.0 else Vector2.ZERO
	if dir != _radar_dir:
		_radar_dir = dir
		radar.queue_redraw()


func show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func hide_banner() -> void:
	banner.hide()


func _draw_radar() -> void:
	var center := radar.size / 2.0
	radar.draw_circle(center, RADAR_RADIUS, Color(0.0, 0.0, 0.0, 0.55))
	radar.draw_arc(center, RADAR_RADIUS, 0.0, TAU, 32, color, 1.5)
	if _radar_dir != Vector2.ZERO:
		var tip := center + Vector2.from_angle(_radar_dir.angle()) * (RADAR_RADIUS - 4.0)
		radar.draw_line(center, tip, NEEDLE_COLOR, 2.0)
