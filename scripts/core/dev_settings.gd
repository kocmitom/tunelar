extends CanvasLayer
## Developer panel (F1): edits the tuning static vars live. Changes go through Net, so every PC in a match applies them on the same tick.

# [class name, script, tuning vars, when changes take effect].
var groups := [
	["Tank", Tank, [
		"MAX_ENERGY", "SPEED_CLEAR", "SPEED_DIGGING", "ENERGY_DRAIN_IDLE", "ENERGY_DRAIN_MOVE_CLEAR",
		"ENERGY_PER_DUG_CELL", "ENERGY_DRAIN_JELLY", "ENERGY_RECHARGE_BASE", "ENERGY_REGEN_PASSIVE", "LOW_ENERGY", "SPEED_FACTOR_EMPTY",
		"DIG_MARGIN", "ENERGY_COST_FIRE", "FIRE_COOLDOWN", "MAX_SHIELDS", "SHIELDS_PER_LEVEL",
		"SHIELD_RECHARGE_BASE", "MAX_LEVEL", "UPGRADE_COST", "ENERGY_PER_LEVEL", "SPEED_PER_LEVEL",
		"RADAR_PER_LEVEL", "ENERGY_COST_LASER", "ENERGY_COST_SPREAD",
	], ""],
	["Bullet", Bullet, ["BULLET_SPEED", "MAX_BOUNCES", "DENT_RADIUS"], ""],
	["Explosion", Explosion, ["RADIUS", "DURATION"], ""],
	["Jelly", Jelly, ["LIFETIME_TICKS", "RADIUS"], ""],
	["Laser", Laser, ["LIFETIME"], ""],
	["Worm", Worm, [
		"SPEED", "SEGMENTS", "SEGMENT_SPACING", "RADIUS", "FILL_RADIUS", "TURN_RATE", "WIGGLE", "WIGGLE_TICKS",
		"RETARGET_TICKS", "DISTANCE_PENALTY", "BASE_CLEARANCE", "SPAWN_DELAY_TICKS", "SPAWN_BASE_DISTANCE",
	], "segments, spawn: next round"],
	["GameManager", GameManager, ["KILLS_TO_WIN", "SHRAPNEL_COUNT", "MAP_AREA_PER_PLAYER", "MAP_ASPECT"], "map size: next match"],
	["TerrainData", TerrainData, [
		"ROCK_COVERAGE", "ROCK_RADIUS_MIN", "ROCK_RADIUS_MAX", "ROCK_STRETCH_MAX", "ROCK_WOBBLE",
		"GOLD_COVERAGE", "GOLD_RADIUS_MIN", "GOLD_RADIUS_MAX", "GOLD_VALUE",
		"ENERGY_COVERAGE", "ENERGY_RADIUS_MIN", "ENERGY_RADIUS_MAX", "ENERGY_VALUE",
		"DRAIN_COVERAGE", "DRAIN_VALUE", "RING_RADIUS", "RING_JITTER",
		"EDGE_IN", "EDGE_OUT", "EDGE_DEEP", "EDGE_BASE_CLEAR", "EDGE_BINS", "EDGE_SQUARE",
		"EDGE_FREQUENCY", "EDGE_CONTRAST", "EDGE_ROUGH", "EDGE_ROUGH_FREQUENCY",
	], "map: next round"],
	["FogOfWar", FogOfWar, ["REVEAL_TANK_SIZES", "SIGHT_SCALE", "SPAWN_REVEAL_SCALE", "EXPLORED_DIM"], ""],
	["Sonar", Sonar, ["LENGTH", "TURN_TIME", "HIT_ANGLE", "NEAR", "FAR"], ""],
]
const COLOR_HEADER := Color(0.5, 0.8, 1.0)
const COLOR_CHANGED := Color(1.0, 0.85, 0.2)
const PANEL_WIDTH := 420

# Code values per "Class.NAME" key.
var defaults := {}
var _scripts := {}
var _boxes := {}
var _labels := {}
var _panel: PanelContainer


func _ready() -> void:
	layer = 100
	for group in groups:
		for var_name in group[2]:
			var key := "%s.%s" % [group[0], var_name]
			_scripts[key] = group[1]
			defaults[key] = group[1].get(var_name)
	_build_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_panel.visible = not _panel.visible


func get_value(key: String) -> Variant:
	return _scripts[key].get(key.get_slice(".", 1))


# Sets the static var, converted to the type of its code value.
func apply(key: String, value: Variant) -> void:
	value = type_convert(value, typeof(defaults[key]))
	_scripts[key].set(key.get_slice(".", 1), value)
	_boxes[key].set_value_no_signal(value)
	_labels[key].modulate = Color.WHITE if value == defaults[key] else COLOR_CHANGED


func values() -> Dictionary:
	var result := {}
	for key in defaults:
		result[key] = get_value(key)
	return result


func load_values(new_values: Dictionary) -> void:
	for key in new_values:
		apply(key, new_values[key])


func _reset_all() -> void:
	for key in defaults:
		if get_value(key) != defaults[key]:
			Net.send_tuning(key, defaults[key])


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_WIDTH
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var reset := Button.new()
	reset.text = "Reset all"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset_all)
	list.add_child(reset)
	for group in groups:
		var header := Label.new()
		header.text = group[0] if group[3] == "" else "%s (%s)" % [group[0], group[3]]
		header.add_theme_color_override("font_color", COLOR_HEADER)
		list.add_child(header)
		for var_name in group[2]:
			var key := "%s.%s" % [group[0], var_name]
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = var_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var box := SpinBox.new()
			var is_int: bool = typeof(defaults[key]) == TYPE_INT
			box.step = 1.0 if is_int else 0.001
			# Arrow clicks change the value by a tenth of its code value.
			box.custom_arrow_step = maxf(1.0 if is_int else 0.001, absf(defaults[key]) * 0.1)
			box.allow_greater = true
			box.allow_lesser = true
			box.custom_minimum_size.x = 140
			box.set_value_no_signal(defaults[key])
			box.value_changed.connect(func(v: float) -> void: Net.send_tuning(key, v))
			row.add_child(box)
			list.add_child(row)
			_boxes[key] = box
			_labels[key] = label
