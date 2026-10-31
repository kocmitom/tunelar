class_name PlayerHud
extends CanvasLayer
## Per-viewport overlay: battery gauge, shields, money and upgrades, kills and round banner.

# In Tank.Special order.
const SPECIAL_NAMES := ["3-WAY", "LASER", "JELLY", "RADAR"]
# On-screen size of the 9x9 upgrade icons.
const ICON_SIZE := 18

# The base pad icons in white with a black outline, in Tank.Upgrade order.
static var _upgrade_icons: Array[ImageTexture] = []

var player_id: int = 0
var color: Color = Color.WHITE

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var money_label: RichTextLabel = $MoneyLabel
@onready var wins_label: Label = $WinsLabel
@onready var banner: Label = $Banner


func _ready() -> void:
	if _upgrade_icons.is_empty():
		for icon in TerrainRenderer.PAD_ICONS:
			_upgrade_icons.append(_build_icon(icon))
	banner.hide()


func setup(id: int, player_color: Color) -> void:
	player_id = id
	color = player_color
	energy_bar.self_modulate = color


func update_hud(tank: Tank) -> void:
	energy_bar.max_value = tank.max_energy()
	energy_bar.value = tank.energy
	shield_bar.max_value = tank.max_shields()
	shield_bar.value = tank.shields
	money_label.clear()
	money_label.add_text("$ %d" % tank.money)
	for i in tank.levels.size():
		money_label.add_text("  ")
		money_label.add_image(_upgrade_icons[i], ICON_SIZE, ICON_SIZE)
		money_label.add_text(" %d" % tank.levels[i])
	if tank.special >= 0:
		money_label.add_text("  " + SPECIAL_NAMES[tank.special])
	wins_label.text = "P%d  KILLS %d/%d" % [player_id + 1, tank.kills, GameManager.KILLS_TO_WIN]


func show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func hide_banner() -> void:
	banner.hide()


# "#" pixels white, "." pixels touching one black, the rest transparent.
static func _build_icon(rows: Array) -> ImageTexture:
	var size: int = rows.size()
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			if rows[y][x] == "#":
				img.set_pixel(x, y, Color.WHITE)
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if x + dx >= 0 and y + dy >= 0 and x + dx < size and y + dy < size and rows[y + dy][x + dx] == "#":
						img.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(img)
