extends Node3D
## Глава 1 «ЭКСПОЗИЦИЯ» — дирижёр сцены [lev-03 + code-05 + narr-02]

const PlayerScene := preload("res://scenes/player.tscn")
const GiraffeScene := preload("res://scenes/giraffe.tscn")
const MuseumScript := preload("res://scripts/museum_builder.gd")
const HudScript := preload("res://scripts/hud.gd")
const PauseScript := preload("res://scripts/pause_menu.gd")

var museum
var player
var giraffe
var hud
var pause

var current_inter
var whisper_t := 50.0
var paused_now := false

func _ready() -> void:
	museum = MuseumScript.new()
	add_child(museum)
	player = PlayerScene.instantiate()
	var cp: Vector3 = museum.checkpoints.get(String(Game.state.checkpoint), museum.spawn)
	add_child(player)
	player.global_position = cp
	giraffe = GiraffeScene.instantiate()
	add_child(giraffe)
	giraffe.global_position = museum.giraffe_spawn
	giraffe.setup(player, museum.spots)
	hud = HudScript.new()
	add_child(hud)
	pause = PauseScript.new()
	add_child(pause)
	_wire()
	_ambience()

func _wire() -> void:
	for a in get_tree().get_nodes_in_group("interactable"):
		a.interacted.connect(_on_interact)
	Game.died.connect(func(): _on_death())
	hud.death_finished.connect(_after_death)
	hud.death_dismissed.connect(func():
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	hud.altar_answered.connect(_on_altar)
	hud.menu_requested.connect(_to_menu)
	pause.menu_requested.connect(_to_menu)
	pause.resume_requested.connect(_on_resume)
	pause.restart_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/chapter1.tscn"))
	# первая PA-фраза
	if not Game.photo_mode:
		get_tree().create_timer(18.0).timeout.connect(func(): _pa("Внимание. Ночное перемещение по фондам запрещено. Хранителям — оставаться в витринах."))

func _ambience() -> void:
	var hall := AudioStreamPlayer.new()
	add_child(hall)
	Game.play_loop(hall, "res://assets/audio/drone_hall.wav", -13.0)
	for wing in [Vector3(-26, 2.5, 0), Vector3(26, 2.5, 0)]:
		var p := AudioStreamPlayer3D.new()
		p.position = wing
		p.max_distance = 26.0
		p.unit_size = 9.0
		add_child(p)
		Game.play_loop(p, "res://assets/audio/drone_wing.wav", -7.0)

func _process(delta: float) -> void:
	if Game.photo_mode: return
	if not player.frozen:
		current_inter = player.current_interactable()
		hud.set_prompt(current_inter.prompt() if current_inter else "")
	_checkpoints()
	# шёпот из экспозиции
	whisper_t -= delta
	if whisper_t <= 0.0:
		whisper_t = randf_range(45.0, 95.0)
		Game.play_ui("res://assets/audio/whisper.wav", -16.0)
	# виньетка близости образца
	hud.set_dread(float(giraffe.dread) if not hud.death_on else 0.0)

func _checkpoints() -> void:
	for key: String in museum.checkpoints:
		var pos: Vector3 = museum.checkpoints[key]
		if player.global_position.distance_to(pos) < 2.8 and String(Game.state.checkpoint) != key:
			Game.state.checkpoint = key
			Game.save_game()
			hud.flash("ЗАПИСЬ В ЖУРНАЛ… (сохранено)")

func _unhandled_input(event: InputEvent) -> void:
	if Game.photo_mode: return
	if event.is_action_pressed("pause"):
		if hud.note_open or hud.altar_open or hud.death_on or hud.end_layer: return
		pause.toggle()
		paused_now = get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused_now else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if hud.note_open or hud.altar_open or hud.death_on or hud.end_layer: return
		if current_inter:
			current_inter.interact()
			get_viewport().set_input_as_handled()

func _on_resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------------------------------------------------------------- интеракции
func _on_interact(node) -> void:
	match String(node.kind):
		"note":
			hud.show_note(String(node.note_title), String(node.note_text))
			if node.has_meta("note_id"):
				Game.add_note(String(node.get_meta("note_id")), String(node.note_text))
		"seal":
			Game.add_seal()
			Game.play_ui("res://assets/audio/seal_pickup.wav", -8.0)
			_hide_nearby_mesh(node, 0.5)
			match Game.state.seals:
				1: _pa("Пересчёт образцов начат. Недостающий — один.")
				2: _pa("Образец 214, вернитесь в зал. Вы не экспонат. Пока.")
				3:
					_pa("Образец 0. К вам идут. Не стремитесь.")
					Game.say("Три печати. Гнезда совпали. Дверь в Зал Происхождения помнит ваш вес.", 6.0)
		"key":
			Game.give_key()
			Game.play_ui("res://assets/audio/paper.wav", -10.0)
			hud.flash("КЛЮЧ ХРАНИТЕЛЯ — в кармане халата")
			_hide_nearby_mesh(node, 0.4)
		"door_key":
			if Game.state.has_key:
				_open_door(museum.cabinet_door, 2.4)
				node.set_meta("opened", true)
				node.one_shot = true
				node.used = true
			else:
				Game.play_ui("res://assets/audio/door_locked.wav", -6.0)
				Game.say("Заперто. Ключ хранителя — у смотрителя в восточном крыле.", 4.5)
				node.used = false
		"door_origin":
			if node.has_meta("opened"): return
			if Game.state.seals >= 3:
				node.set_meta("opened", true)
				_open_door(museum.origin_door, 4.0)
				Game.state.checkpoint = "origin"
				Game.save_game()
				_pa("Образец 0. Дверь узнала печати. Спускайтесь.")
			else:
				Game.play_ui("res://assets/audio/door_locked.wav", -6.0)
				Game.say("Три гнезда под печати. Печати — в крыльях и в кабинете.", 5.0)
				node.used = false
		"altar":
			var def: Dictionary = Game.MUT_DEFS["troglodyte"]
			hud.show_altar(String(def.offer), String(def.name))
			node.used = false
		"pa_panel":
			if not node.has_meta("used_panel"):
				node.set_meta("used_panel", true)
				_pa("Образец 88, прекратите шум. Образец 0, вас ждут.")
		"end":
			_end_slice()

func _on_altar(accepted: bool) -> void:
	if accepted:
		Game.mutate("troglodyte")
		Game.state.accepted_altar = true
		Game.play_ui("res://assets/audio/whisper.wav", -4.0)
	else:
		Game.say("Стремление ждёт. Оно умеет ждать.", 4.0)

func _hide_nearby_mesh(node: Node3D, radius: float) -> void:
	for child in museum.get_children():
		if child is MeshInstance3D and child.global_position.distance_to(node.global_position) < radius:
			child.visible = false

func _open_door(door: Node3D, dur: float) -> void:
	Game.play_ui("res://assets/audio/door_open.wav", -4.0)
	var tw := create_tween()
	tw.tween_property(door, "position:y", door.position.y - 2.9, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# ---------------------------------------------------------------- PA/смерть/финал
func _pa(text: String) -> void:
	Game.play_ui("res://assets/audio/pa_gong.wav", -9.0)
	Game.pa_say(text, 6.5)
	var v := AudioStreamPlayer.new()
	add_child(v)
	v.stream = load("res://assets/audio/pa_voice.wav")
	v.volume_db = -7.0
	v.play()
	v.finished.connect(v.queue_free)

func _on_death() -> void:
	player.frozen = true
	hud.play_death()

func _after_death() -> void:
	Game.state.deaths += 1
	giraffe.respawn_after_death()
	var cp: Vector3 = museum.checkpoints.get(String(Game.state.checkpoint), museum.spawn)
	player.global_position = cp
	player.velocity = Vector3.ZERO

func _end_slice() -> void:
	if Game.photo_mode: return
	Game.save_game()
	var mins := int(Game.elapsed()) / 60
	var secs := int(Game.elapsed()) % 60
	var stats := "ВИД: %s\nЗАПИСОК ПРОЧИТАНО: %d / 4\nМУТАЦИЙ: %d\nСМЕРТЕЙ: %d\nВРЕМЯ СМЕНЫ: %02d:%02d" % [
		Game.species_name(), Game.state.notes.size(), Game.state.mutations.size(), Game.state.deaths, mins, secs]
	hud.show_slice_end(stats)
