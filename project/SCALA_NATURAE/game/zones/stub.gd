extends Node3D
## ВРЕМЕННАЯ заглушка зоны (c3/c4/c5 в разработке). Убирается при сдаче главы.
## НЕ ИГРОВОЙ КОНТЕНТ.

func build(world: Node3D) -> void:
	add_to_group("zone_stub")
	Kit.mesh(self, Kit.M("plaster"), "box", Vector3(14.0, 0.12, 14.0), Vector3(0, -0.06, 0), Vector3.ZERO, true, "surf_wood")
	for side in [[-7.0, 0.0, 0.0], [7.0, 0.0, 0.0], [0.0, -7.0, PI / 2], [0.0, 7.0, PI / 2]]:
		Kit.mesh(self, Kit.M("plaster"), "box", Vector3(14.2, 5.0, 0.3), Vector3(side[0], 2.5, side[1]), Vector3(0, side[2], 0), true)
	Kit.mesh(self, Kit.M("black"), "box", Vector3(14.2, 0.12, 14.2), Vector3(0, 5.0, 0))
	Kit.plate(self, "ЗОНА В РАЗРАБОТКЕ · ВЕРНИТЕСЬ В МУЗЕЙ", Vector3(0, 2.6, 0), 1.2, true)
	Kit.wall_lamp(self, Vector3(0, 2.0, 3.0))
	# выход обратно в зал №4-коридор для тестов
	var gate := ZoneGate.new()
	add_child(gate)
	gate.setup("c2_vault", Vector3(0, 0.1, 6.0), Vector3(3.0, 3.0, 1.6), "default")
	if world.player:
		world.player.freeze = false

func player_spawn(_spawn_name := "default") -> Dictionary:
	return {"pos": Vector3(0, 0.1, 0.0), "yaw": PI}
