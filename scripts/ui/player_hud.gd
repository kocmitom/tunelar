class_name PlayerHud
extends CanvasLayer
## Per-viewport overlay: battery gauge, wins and round banner.

var player_id: int = 0
var color: Color = Color.WHITE

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var wins_label: Label = $WinsLabel
@onready var banner: Label = $Banner


func _ready() -> void:
	banner.hide()


func setup(id: int, player_color: Color) -> void:
	player_id = id
	color = player_color
	energy_bar.self_modulate = color


func update_hud(tank: Tank, wins: int) -> void:
	energy_bar.value = tank.energy
	wins_label.text = "P%d  WINS %d" % [player_id + 1, wins]


func show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func hide_banner() -> void:
	banner.hide()
