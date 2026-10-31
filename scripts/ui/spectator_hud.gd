class_name SpectatorHud
extends CanvasLayer
## Spectator overlay: every player's kills in their color and the round banner.

var scores: RichTextLabel
var banner: Label


func _init() -> void:
	scores = RichTextLabel.new()
	scores.position = Vector2(8, 4)
	scores.size = Vector2(400, 0)
	scores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scores.fit_content = true
	scores.scroll_active = false
	scores.autowrap_mode = TextServer.AUTOWRAP_OFF
	scores.add_theme_color_override("font_outline_color", Color.BLACK)
	scores.add_theme_constant_override("outline_size", 4)
	add_child(scores)
	banner = Label.new()
	banner.visible = false
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_font_size_override("font_size", 32)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(banner)


# names[i] belongs to tanks[i].
func update_scores(tanks: Array[Tank], names: Array) -> void:
	scores.clear()
	for i in tanks.size():
		scores.push_color(tanks[i].color)
		scores.add_text("%s  KILLS %d/%d\n" % [names[i], tanks[i].kills, GameManager.KILLS_TO_WIN])
		scores.pop()


func show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func hide_banner() -> void:
	banner.hide()
