extends "res://tests/test_case.gd"

const NetScript := preload("res://scripts/core/net.gd")
const GridScene := preload("res://scenes/ui/viewport_grid.tscn")


func _make_net(slot_count: int) -> Node:
	var net: Node = NetScript.new()
	for i in slot_count:
		net.slot_peers.append(i + 1)
	net.reset_inputs()
	return net


func test_inputs_wait_for_every_slot() -> void:
	var net := _make_net(3)
	var tick: int = NetScript.INPUT_DELAY + 1
	check_eq(net.take_inputs(1).size(), 3, "delay ticks are pre-filled")
	check(net.take_inputs(tick).is_empty(), "nothing arrived yet")
	net._receive_input(tick, 2, Vector2.LEFT, true)
	net._receive_input(tick + 1, 0, Vector2.UP, false)
	net._receive_input(tick, 0, Vector2.RIGHT, false)
	check(net.take_inputs(tick).is_empty(), "slot 1 still missing")
	net._receive_input(tick, 1, Vector2.DOWN, false, -1.0)
	var inputs: Array[Dictionary] = net.take_inputs(tick)
	check_eq(inputs.size(), 3, "complete once all slots arrived")
	check_eq(inputs[0]["move"], Vector2.RIGHT, "slot 0 input")
	check(inputs[2]["fire"], "slot 2 fire")
	check_eq(inputs[1]["turn"], -1.0, "slot 1 turret turn")
	check(net.take_inputs(tick).is_empty(), "a tick is taken once")
	net.free()


func test_disconnected_slot_is_idle() -> void:
	var net := _make_net(2)
	net.in_match = true
	var tick: int = NetScript.INPUT_DELAY + 1
	net._receive_input(tick, 0, Vector2.UP, true)
	net._on_peer_disconnected(2)
	var inputs: Array[Dictionary] = net.take_inputs(tick)
	check_eq(inputs.size(), 2, "tick runs without the gone peer")
	check_eq(inputs[1]["move"], Vector2.ZERO, "gone slot does not move")
	check(not inputs[1]["fire"], "gone slot does not fire")
	check_eq(inputs[1]["turn"], 0.0, "gone slot does not turn")
	net.free()


func test_slot_order_groups_local_players() -> void:
	var order := NetScript.slot_order({1: ["a", "b"], 3: ["c"], 2: ["d"]})
	check_eq(order, [1, 1, 2, 3] as Array[int], "peers ascending, then local players")
	check_eq(NetScript.slot_name_order({1: ["a", "b"], 3: ["c"], 2: ["d"]}), ["a", "b", "d", "c"], "names in slot order")


func test_gone_peer_idles_all_its_slots() -> void:
	var net: Node = NetScript.new()
	net.slot_peers.assign([1, 2, 2])
	net.reset_inputs()
	net.in_match = true
	var tick: int = NetScript.INPUT_DELAY + 1
	net._receive_input(tick, 0, Vector2.UP, false)
	net._on_peer_disconnected(2)
	var inputs: Array[Dictionary] = net.take_inputs(tick)
	check_eq(inputs.size(), 3, "tick runs without both of the gone PC's players")
	check_eq(inputs[2]["move"], Vector2.ZERO, "second gone slot idle")
	net.free()


func _press_keys(router: InputRouter, keycodes: Array) -> void:
	for keycode in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.pressed = true
		router.process_input(ev)


func test_sample_all_merges_devices() -> void:
	var router := InputRouter.new()
	router.assign_devices([] as Array[int])
	_press_keys(router, [KEY_W, KEY_RIGHT, KEY_ENTER])
	var input := router.sample_all()
	check(input["move"].is_equal_approx(Vector2(1, -1).normalized()), "both keyboards steer one tank")
	check(input["fire"], "keyboard B fire counts")
	router.free()


func test_sample_local_splits_devices() -> void:
	var router := InputRouter.new()
	router.assign_devices([] as Array[int])
	_press_keys(router, [KEY_W, KEY_RIGHT, KEY_ENTER])
	var solo := router.sample_local(1)
	check_eq(solo.size(), 1, "one local player")
	check(solo[0]["move"].is_equal_approx(Vector2(1, -1).normalized()), "a lone player uses every device")
	var pair := router.sample_local(2)
	check_eq(pair[0]["move"], Vector2.UP, "player 1 on WASD")
	check(not pair[0]["fire"], "Enter is not player 1's fire")
	check_eq(pair[1]["move"], Vector2.RIGHT, "player 2 on arrows")
	check(pair[1]["fire"], "Enter fires for player 2")
	check_eq(InputRouter.device_label(1), "Arrows + Enter", "lobby label for player 2")
	router.free()


func test_turret_aim_keys() -> void:
	var router := InputRouter.new()
	router.assign_devices([] as Array[int])
	_press_keys(router, [KEY_W, KEY_RIGHT])
	var solo := router.sample_local(1)
	check(solo[0]["move"].is_equal_approx(Vector2(1, -1).normalized()), "a lone player still drives with WASD and the arrows")
	check_eq(solo[0]["turn"], 0.0, "the arrows do not turn the turret")
	_press_keys(router, [KEY_H])
	check_eq(router.sample_local(1)[0]["turn"], 1.0, "a lone player turns the turret with F/H")
	_press_keys(router, [KEY_KP_6])
	var pair := router.sample_local(2)
	check_eq(pair[0]["turn"], 1.0, "player 1 turns with F/H")
	check_eq(pair[1]["move"], Vector2.RIGHT, "player 2 still drives with the arrows")
	check_eq(pair[1]["turn"], 1.0, "player 2 turns with numpad 4/6")
	check_eq(InputRouter.device_label(0, true), "WASD + F/H + Space", "turret lobby label for player 1")
	router.free()


func test_same_seed_and_inputs_stay_in_sync() -> void:
	var games: Array[GameManager] = []
	for g in 2:
		var manager: ViewportManager = GridScene.instantiate()
		tree.root.add_child(manager)
		var gm: GameManager = manager.get_node("GameManager")
		gm.setup(3, 1234)
		games.append(gm)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var dirs := [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, 1)]
	for t in 300:
		var inputs: Array[Dictionary] = []
		for p in 3:
			inputs.append({"move": dirs[rng.randi() % dirs.size()], "fire": rng.randf() < 0.2})
		for gm in games:
			gm.simulate(inputs)

	var a := games[0]
	var b := games[1]
	check(a.terrain.cells == b.terrain.cells, "terrain identical")
	check_eq(a.terrain.map_seed, b.terrain.map_seed, "same round seed")
	var ok := true
	for i in 3:
		ok = ok and a.tanks[i].position == b.tanks[i].position and a.tanks[i].energy == b.tanks[i].energy
		ok = ok and a.tanks[i].is_dead == b.tanks[i].is_dead and a.tanks[i].kills == b.tanks[i].kills
	check(ok, "tanks identical")
	for gm in games:
		gm.manager.free()
