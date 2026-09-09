extends Node
## Smoke-тест главы 1 (headless) [qa-08]
## Запуск: godot --headless --path . res://tests/smoke.tscn

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t0 := Time.get_ticks_msec()
	var ch = (load("res://scenes/chapter1.tscn") as PackedScene).instantiate()
	add_child(ch)
	for i in range(10):
		await get_tree().process_frame
	# базовая сборка
	check("игрок создан и в группе player", ch.player != null and ch.player.is_in_group("player"))
	check("музей построен (>120 узлов)", ch.museum.get_child_count() > 120)
	check("Жирафа на месте", ch.giraffe != null)
	var inters := get_tree().get_nodes_in_group("interactable")
	check("интерактивов >= 12 (есть %d)" % inters.size(), inters.size() >= 12)
	check("спотов Жирафы >= 7", ch.museum.spots.size() >= 7)
	# собираем три печати
	var seals := 0
	for a in inters:
		if String(a.kind) == "seal":
			a.interact()
			seals += 1
	check("печатей в главе = 3 (есть %d)" % seals, seals == 3)
	check("Game.state.seals == 3", Game.state.seals == 3)
	# дверь Происхождения открывается
	var door = ch.museum.origin_door
	var y0: float = door.position.y
	for a in inters:
		if String(a.kind) == "door_origin":
			a.interact()
			break
	await get_tree().create_timer(5.0).timeout
	check("дверь Происхождения уехала вниз", door.position.y < y0 - 1.5)
	# мутация и имя вида
	Game.mutate("troglodyte")
	check("имя вида = Homo custos caecus", Game.species_name() == "Homo custos caecus")
	# записка
	for a in inters:
		if String(a.kind) == "note":
			a.interact()
			break
	await get_tree().process_frame
	check("записка открылась (пауза)", ch.hud.note_open == true)
	ch.hud._close_note()
	await get_tree().process_frame
	check("записка закрылась (пауза снята)", ch.hud.note_open == false and not get_tree().paused)
	check("заметка в журнале", Game.state.notes.size() >= 1)
	# алтарь: отказ
	ch.hud.show_altar("тест", "Глаза троглобита")
	await get_tree().process_frame
	ch.hud._close_altar(true)
	await get_tree().process_frame
	check("алтарь закрыт, пауза снята", not ch.hud.altar_open and not get_tree().paused)
	# смерть и респавн
	ch.giraffe._catch()
	await get_tree().create_timer(3.5).timeout
	var cp: Vector3 = ch.museum.checkpoints.get(String(Game.state.checkpoint), Vector3(0, 0, 0))
	check("после смерти игрок у контрольной точки", ch.player.global_position.distance_to(cp) < 4.0)
	check("смерти учтены", Game.state.deaths >= 1)
	check("жирафа ушла на дальний спот", ch.giraffe.global_position.distance_to(ch.player.global_position) > 6.0)
	# сохранение
	Game.save_game()
	check("файл сохранения создан", Game.has_save())
	var dt := Time.get_ticks_msec() - t0
	var log := "SMOKE %s · %d проверок · %d провалено · %d мс\n" % ["PASS" if fails == 0 else "FAIL", 17, fails, dt]
	var f := FileAccess.open("res://tests/smoke_result.txt", FileAccess.WRITE)
	if f: f.store_string(log)
	print(log)
	get_tree().quit(0 if fails == 0 else 1)
