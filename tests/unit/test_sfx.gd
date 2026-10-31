extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")


func test_every_kind_rendered() -> void:
	for kind in Sfx.Kind.values():
		var streams: Array = Sfx.banks[kind]
		check(not streams.is_empty(), "kind %d has streams" % kind)
		for stream in streams:
			check(stream.data.size() > 0, "kind %d stream has samples" % kind)


func test_volume_by_distance() -> void:
	check_eq(Sfx.volume_at(Vector2(1000, 1000)), 1.0, "no listeners plays at full volume")
	var near: Tank = TankScene.instantiate()
	var far: Tank = TankScene.instantiate()
	near.position = Vector2(100, 100)
	far.position = Vector2(1000, 100)
	tree.root.add_child(near)
	tree.root.add_child(far)
	Sfx.listeners.assign([far, near])
	check_eq(Sfx.volume_at(Vector2(100 + Sfx.NEAR, 100)), 1.0, "full volume within NEAR")
	check_eq(Sfx.volume_at(Vector2(100, 100 + Sfx.FAR)), 0.0, "silent beyond FAR")
	var mid := Sfx.volume_at(Vector2(100, 100 + (Sfx.NEAR + Sfx.FAR) / 2.0))
	check(mid > 0.0 and mid < 1.0, "fades in between")
	check_eq(Sfx.volume_at(Vector2(1000 + Sfx.NEAR, 100)), 1.0, "nearest listener counts")
	Sfx.listeners.clear()
	near.free()
	far.free()


func test_off_plays_nothing() -> void:
	var style: int = Sfx.style
	Sfx.style = Sfx.Style.OFF
	check(Sfx.play(Sfx.Kind.FIRE) == null, "off plays nothing")
	Sfx.style = Sfx.Style.ON
	check(Sfx.play(Sfx.Kind.FIRE) != null, "on plays")
	Sfx.style = style
