extends Control
## Main menu: lists the players in the LAN lobby; each PC can add local players and anyone can start the match.

@onready var status_label: Label = %Status
@onready var player_list: VBoxContainer = %Players
@onready var add_button: Button = %AddButton
@onready var remove_button: Button = %RemoveButton
@onready var start_button: Button = %StartButton
# In GameManager.MAP_SIZE_NAMES order, after the "Map" label.
@onready var map_buttons: Array = %MapSize.get_children().slice(1)
@onready var turret_button: Button = %TurretButton
@onready var version_label: Label = $VersionLabel


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	version_label.text = "v%s" % version
	get_window().title = "%s v%s" % [ProjectSettings.get_setting("application/config/name"), version]
	Net.lobby_changed.connect(_refresh)
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _refresh())
	for i in map_buttons.size():
		map_buttons[i].pressed.connect(Net.set_map_size.bind(i))
	turret_button.toggled.connect(Net.set_turret_mode)
	Net.start()
	_refresh()
	start_button.grab_focus()


# Listed in slot order, so each name shows the color its tank will have.
func _refresh() -> void:
	status_label.text = Net.status
	for child in player_list.get_children():
		child.free()
	var my_id := multiplayer.get_unique_id()
	var own: Array = Net.players.get(my_id, [])
	var slot := 0
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		for k in Net.players[id].size():
			var label := Label.new()
			label.text = Net.players[id][k]
			if id == my_id and own.size() > 1:
				label.text += "  (%s)" % InputRouter.device_label(k, Net.turret_mode)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_color", GameManager.PLAYER_COLORS[slot])
			player_list.add_child(label)
			slot += 1
	var free_devices := 2 + Input.get_connected_joypads().size() - Net.local_count
	add_button.disabled = own.is_empty() or slot >= Net.MAX_PLAYERS or free_devices <= 0
	remove_button.disabled = own.size() <= 1
	start_button.disabled = slot < 2
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(i == Net.map_size)
		map_buttons[i].disabled = own.is_empty()
	turret_button.set_pressed_no_signal(Net.turret_mode)
	turret_button.disabled = own.is_empty()


func _on_add_button_pressed() -> void:
	Net.add_local_player()


func _on_remove_button_pressed() -> void:
	Net.remove_local_player()


func _on_start_button_pressed() -> void:
	Net.request_start()
