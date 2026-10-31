extends "res://tests/test_case.gd"

const NetScript := preload("res://scripts/core/net.gd")
const TankScene := preload("res://scenes/tank/tank.tscn")


func test_defaults_and_apply() -> void:
	check_eq(DevSettings.defaults["Tank.SPEED_CLEAR"], Tank.SPEED_CLEAR, "default is the code value")
	check_eq(DevSettings.defaults["TerrainData.GOLD_VALUE"], TerrainData.GOLD_VALUE, "int default is the code value")
	var original := Tank.SPEED_CLEAR
	DevSettings.apply("Tank.SPEED_CLEAR", 90.0)
	check_eq(Tank.SPEED_CLEAR, 90.0, "apply sets the static var")
	DevSettings.apply("TerrainData.GOLD_VALUE", 20.0)
	check_eq(typeof(TerrainData.GOLD_VALUE), TYPE_INT, "int vars stay ints")
	check_eq(TerrainData.GOLD_VALUE, 20, "int value applied")
	check_eq(DevSettings.values()["Tank.SPEED_CLEAR"], 90.0, "values reports the change")
	DevSettings.load_values(DevSettings.defaults)
	check_eq(Tank.SPEED_CLEAR, original, "load_values restores the defaults")
	check_eq(TerrainData.GOLD_VALUE, DevSettings.defaults["TerrainData.GOLD_VALUE"], "int default restored")


func test_tank_uses_new_value() -> void:
	var terrain := TerrainData.new()
	for x in range(40, 250):
		terrain.dig_circle(x, 100, 5)
	var tank: Tank = TankScene.instantiate()
	tank.terrain = terrain
	tank.position = Vector2(60, 100)
	tree.root.add_child(tank)
	DevSettings.apply("Tank.SPEED_CLEAR", 90.0)
	for i in GameManager.TICK_RATE:
		tank.step_movement(GameManager.TICK_DT, Vector2.RIGHT)
	check_near(tank.position.x, 150.0, 1.0, "tunnel speed follows the tuned value")
	DevSettings.load_values(DevSettings.defaults)
	tank.free()


func test_tuning_waits_for_its_tick() -> void:
	var net: Node = NetScript.new()
	net.slot_peers.assign([1, 2])
	net.reset_inputs()
	net.in_match = true
	net._receive_tuning(5, "Bullet.BULLET_SPEED", 300.0)
	net.apply_tunings(4)
	check_eq(Bullet.BULLET_SPEED, DevSettings.defaults["Bullet.BULLET_SPEED"], "not applied before its tick")
	net.apply_tunings(5)
	check_eq(Bullet.BULLET_SPEED, 300.0, "applied on its tick")
	check(net.tunings.is_empty(), "applied tunings are dropped")
	net.send_tuning("Bullet.BULLET_SPEED", 200.0)
	check(net.tunings.has(net.sent_tick + 1), "a match change is scheduled after the last sent input")
	DevSettings.load_values(DevSettings.defaults)
	net.free()
