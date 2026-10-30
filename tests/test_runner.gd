extends SceneTree
## Headless entry point: godot --headless --path . -s tests/test_runner.gd

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	# The root window only joins the tree after _initialize, so nodes would have no World2D/physics space.
	await process_frame
	print("[TEST HARNESS] Starting headless test run...")
	var failed: int = 0

	for path in _discover_tests():
		print("%s" % path)
		var script_res: GDScript = load(path)
		if script_res == null:
			print("  [FAIL] could not load script")
			failed += 1
			continue
		var test_instance = script_res.new()
		test_instance.tree = self
		if test_instance.has_method("run_all"):
			failed += test_instance.run_all()

	if failed > 0:
		print("[TEST HARNESS] FAILED: %d assertions failed." % failed)
		quit(1)
	else:
		print("[TEST HARNESS] SUCCESS: All assertions passed.")
		quit(0)


func _discover_tests() -> Array[String]:
	var paths: Array[String] = []
	for dir_path in TEST_DIRS:
		for file_name in DirAccess.get_files_at(dir_path):
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				paths.append(dir_path.path_join(file_name))
	return paths
