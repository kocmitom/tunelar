class_name PlayerHud
extends CanvasLayer
## Per-viewport overlay: battery gauge, shields, money and upgrades, kills and round banner.

# In Tank.Special order.
const SPECIAL_NAMES := ["5-WAY", "LASER", "JELLY", "RADAR"]

var player_id: int = 0
var color: Color = Color.WHITE

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var shield_segments: Array = $Shields.get_children()
@onready var money_label: Label = $MoneyLabel
@onready var wins_label: Label = $WinsLabel
@onready var banner: Label = $Banner
@onready var radar: Polygon2D = $Radar


func _ready() -> void:
	banner.hide()


func setup(id: int, player_color: Color) -> void:
	player_id = id
	color = player_color
	energy_bar.self_modulate = color


# target is the tank the radar points to.
func update_hud(tank: Tank, target: Tank = null) -> void:
	energy_bar.max_value = tank.max_energy()
	energy_bar.value = tank.energy
	for i in shield_segments.size():
		shield_segments[i].visible = i < tank.max_shields()
		shield_segments[i].modulate.a = lerpf(0.15, 1.0, clampf(tank.shields - i, 0.0, 1.0))
	money_label.text = "$ %d  SH %d  EN %d  SP %d  RA %d" % ([tank.money] + tank.levels)
	if tank.special >= 0:
		money_label.text += "  " + SPECIAL_NAMES[tank.special]
	radar.visible = tank.special == Tank.Special.RADAR and target != null
	if radar.visible:
		radar.rotation = (target.global_position - tank.global_position).angle()
	wins_label.text = "P%d  KILLS %d/%d" % [player_id + 1, tank.kills, GameManager.KILLS_TO_WIN]


func show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func hide_banner() -> void:
	banner.hide()
