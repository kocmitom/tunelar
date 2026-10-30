extends "res://tests/test_case.gd"


func test_border_is_bedrock() -> void:
	var t := TerrainData.new()
	check_eq(t.width, 320, "default width")
	check_eq(t.height, 200, "default height")
	var ok := true
	for x in t.width:
		ok = ok and t.get_cell(x, 0) == TerrainData.BEDROCK and t.get_cell(x, t.height - 1) == TerrainData.BEDROCK
	for y in t.height:
		ok = ok and t.get_cell(0, y) == TerrainData.BEDROCK and t.get_cell(t.width - 1, y) == TerrainData.BEDROCK
	check(ok, "outer border cells are bedrock")
	check_eq(t.get_cell(TerrainData.BORDER, TerrainData.BORDER), TerrainData.DIRT, "first interior cell is dirt")
	check_eq(t.get_cell(-1, 5), TerrainData.BEDROCK, "out of bounds reads as bedrock")
	check(not t.is_passable(0, 0), "border not passable")
	check(t.is_passable(50, 50), "dirt passable")


func test_dig_circle_exact() -> void:
	var t := TerrainData.new()
	var dug := t.dig_circle(50, 50, 3)
	check_eq(dug, 29, "radius 3 circle cell count")
	var ok := true
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var expected := TerrainData.AIR if dx * dx + dy * dy <= 9 else TerrainData.DIRT
			ok = ok and t.get_cell(50 + dx, 50 + dy) == expected
	check(ok, "only cells inside the circle became air")
	check_eq(t.dig_circle(50, 50, 3), 0, "re-digging returns 0")


func test_dig_ignores_bedrock() -> void:
	var t := TerrainData.new()
	for y in range(48, 53):
		for x in range(48, 53):
			t.cells[y * t.width + x] = TerrainData.BEDROCK
	var dug := t.dig_circle(50, 50, 3)
	check_eq(dug, 29 - 25, "only dirt counted")
	check_eq(t.get_cell(50, 50), TerrainData.BEDROCK, "bedrock center survives")
	check_eq(t.get_cell(50, 47), TerrainData.AIR, "dirt around bedrock dug")
	t.dig_circle(0, 0, 5)
	check_eq(t.get_cell(0, 0), TerrainData.BEDROCK, "border survives digging")


func test_circle_passable() -> void:
	var t := TerrainData.new()
	check(t.is_circle_passable(50, 50, 3), "dirt circle passable")
	check(not t.is_circle_passable(3, 50, 3), "circle touching border blocked")


func test_generate_bases() -> void:
	var t := TerrainData.new()
	t.generate(1234, 6)
	check_eq(t.base_rects.size(), 6, "six bases")
	var ok := true
	for rect in t.base_rects:
		var c := rect.get_center()
		ok = ok and t.get_cell(c.x, c.y) == TerrainData.BASE_START
		ok = ok and t.is_circle_passable(c.x, rect.position.y, 3) and t.is_circle_passable(c.x, rect.end.y - 1, 3)
	check(ok, "base interiors and doors are open")
	var copy := TerrainData.new()
	copy.generate(1234, 6)
	check(copy.cells == t.cells, "generation is deterministic per seed")
	copy.generate(99, 6)
	check(copy.cells != t.cells, "different seed differs")


func test_rocks_rare_and_clustered() -> void:
	for map_seed in [1, 7, 42, 1234, 99999, 31337, 2026, 5]:
		var t := TerrainData.new()
		t.generate(map_seed, 6)
		var rock := {}
		var interior := 0
		for y in t.height:
			for x in t.width:
				var in_base := false
				for rect in t.base_rects:
					in_base = in_base or rect.has_point(Vector2i(x, y))
				if not in_base and t.get_cell(x, y) == TerrainData.BEDROCK:
					rock[Vector2i(x, y)] = true
					var on_border := x < TerrainData.BORDER or y < TerrainData.BORDER or x >= t.width - TerrainData.BORDER or y >= t.height - TerrainData.BORDER
					interior += 0 if on_border else 1
		var coverage := float(interior) / (t.width * t.height)
		check(coverage > 0.02 and coverage < 0.08, "seed %d rock coverage %.3f" % [map_seed, coverage])

		var smallest := 1 << 30
		var seen := {}
		for start in rock:
			if seen.has(start):
				continue
			var size := 0
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				size += 1
				for n in [p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN]:
					if rock.has(n) and not seen.has(n):
						seen[n] = true
						stack.append(n)
			smallest = mini(smallest, size)
		check(smallest >= 12, "seed %d has no rock specks (smallest formation %d cells)" % [map_seed, smallest])


func test_renderer_tracks_digs() -> void:
	var t := TerrainData.new()
	var r := TerrainRenderer.new()
	r.bind(t)
	check_eq(r.image.get_size(), Vector2i(t.width, t.height), "image matches grid")
	t.dig_circle(50, 50, 3)
	check_eq(r.image.get_pixel(50, 50), TerrainRenderer.COLOR_AIR, "dug pixel recolored")
	r.free()
