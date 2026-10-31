extends "res://tests/test_case.gd"

const TankScene := preload("res://scenes/tank/tank.tscn")


func test_every_kind_rendered() -> void:
	for style in [Sfx.Style.ORIGINAL, Sfx.Style.MODERN]:
		for kind in Sfx.Kind.values():
			var streams: Array = Sfx.banks[style][kind]
			check(not streams.is_empty(), "style %d kind %d has streams" % [style, kind])
			for stream in streams:
				check(stream.data.size() > 0, "style %d kind %d stream has samples" % [style, kind])


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
	Sfx.style = Sfx.Style.ORIGINAL
	check(Sfx.play(Sfx.Kind.FIRE) != null, "original plays")
	Sfx.style = style
