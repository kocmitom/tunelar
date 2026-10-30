extends "res://tests/test_case.gd"

const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func test_version_is_semver_and_shown() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var semver := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	check(semver.search(version) != null, "version '%s' is MAJOR.MINOR.PATCH" % version)

	var manager: ViewportManager = GridScene.instantiate()
	tree.root.add_child(manager)
	check_eq(manager.version_label.text, "v%s" % version, "version label shows the project version")
	check(manager.get_window().title.ends_with("v%s" % version), "window title shows the project version")
	manager.free()
