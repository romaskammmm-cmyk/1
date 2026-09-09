extends Node
## НЕДОСТАЮЩЕЕ ЗВЕНО — синглтон состояния игры [code-05 + ux-07]
## Шина событий, инвентарь, карточка вида, сохранения, инпуты.

signal seal_added(total: int)
signal mutation_added(mutation: Dictionary)
signal note_added(id: String)
signal subtitle_requested(text: String, kind: String, dur: float)
signal prompt_requested(text: String)
signal died
signal checkpoint_saved(where: String)

const SPECIES_BASE := "Homo custos"
const MUT_DEFS := {
	"troglodyte": {
		"name": "Глаза троглобита",
		"latin": "caecus",
		"offer": "Темнота перестанет быть темнотой.\nЦвета умрут. Витрину от Таксидермиста не отличишь.",
		"desc": "Вы видите в темноте. Мир стал серым.",
	},
	"diver": {
		"name": "Лёгкие ныряльщика",
		"latin": "batialis",
		"offer": "Вода станет воздухом.\nСухие залы будут жечь.",
		"desc": "Вы дышите водой. Сухое жжёт.",
	},
	"mole": {
		"name": "Слух крота",
		"latin": "audiens",
		"offer": "Вы услышите образцы сквозь стены.\nОни услышат вас.",
		"desc": "Вы слышите сквозь стены.",
	},
	"tail": {
		"name": "Хвостовой отдел",
		"latin": "caudatus",
		"offer": "Вы побежите быстрее.\nУзкие витрины перестанут вас пропускать.",
		"desc": "Вы стали быстрее. И шире.",
	},
}

var state := {
	"chapter": 1,
	"seals": 0,
	"notes": [],
	"mutations": [],
	"has_key": false,
	"deaths": 0,
	"time_started": 0.0,
	"checkpoint": "spawn",
	"accepted_altar": false,
}
var mouse_sens := 0.0022
var volume_db := 0.0
var photo_mode := false
var time_started := 0.0

func _enter_tree() -> void:
	_register_inputs()

func _ready() -> void:
	_apply_theme()
	time_started = Time.get_ticks_msec() / 1000.0
	state.time_started = time_started

func _register_inputs() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "interact": [KEY_E],
		"flashlight": [KEY_F], "pause": [KEY_ESCAPE],
		"dev_screenshot": [KEY_F12],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for kc in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(action, ev)

func _apply_theme() -> void:
	var font := load("res://assets/fonts/DejaVuSans.ttf")
	if font == null: return
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 19
	get_window().theme = theme

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_screenshot"):
		_screenshot("res://shots/dev_%d.png" % Time.get_ticks_msec())

func _screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[Game] скриншот: ", path)

# ---------------------------------------------------------------- state API
func reset() -> void:
	state = {
		"chapter": 1, "seals": 0, "notes": [], "mutations": [],
		"has_key": false, "deaths": 0,
		"time_started": Time.get_ticks_msec() / 1000.0,
		"checkpoint": "spawn", "accepted_altar": false,
	}

func add_seal() -> void:
	state.seals += 1
	seal_added.emit(state.seals)

func give_key() -> void:
	state.has_key = true

func add_note(id: String, text: String) -> void:
	if id not in state.notes:
		state.notes.append(id)
		note_added.emit(id)

func mutate(id: String) -> void:
	if id in state.mutations: return
	state.mutations.append(id)
	if MUT_DEFS.has(id):
		mutation_added.emit(MUT_DEFS[id])
		if id == "troglodyte":
			_set_desaturation(0.12)

func _set_desaturation(v: float) -> void:
	var env_node := get_tree().get_first_node_in_group("env")
	if env_node is WorldEnvironment:
		var env: Environment = env_node.environment
		env.adjustment_enabled = true
		env.adjustment_saturation = v

func species_name() -> String:
	var parts: Array[String] = [SPECIES_BASE]
	for m in state.mutations:
		if MUT_DEFS.has(m):
			parts.append(MUT_DEFS[m].latin)
	return " ".join(parts)

func has_mutation(id: String) -> bool:
	return id in state.mutations

func elapsed() -> float:
	return Time.get_ticks_msec() / 1000.0 - float(state.time_started)

func save_game() -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))
	checkpoint_saved.emit(String(state.checkpoint))

func load_game() -> bool:
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if f == null: return false
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		state = parsed
		return true
	return false

func has_save() -> bool:
	return FileAccess.file_exists("user://save.json")

# ---------------------------------------------------------------- UI bus
func make_loop(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	return s

func play_loop(player, path: String, vol_db := 0.0) -> void:
	player.stream = make_loop(path)
	player.volume_db = vol_db
	player.play()

func play_at(node3d: Node3D, path: String, vol_db := 0.0, max_dist := 12.0) -> void:
	if node3d == null or not is_instance_valid(node3d): return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = 6.0
	node3d.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_rand_at(node3d: Node3D, pattern: String, n: int, vol_db := 0.0, max_dist := 12.0) -> void:
	play_at(node3d, pattern % randi_range(1, n), vol_db, max_dist)

func play_ui(path: String, vol_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	get_tree().root.add_child(p)
	p.stream = load(path)
	p.volume_db = vol_db
	p.finished.connect(p.queue_free)
	p.play()

func say(text: String, dur: float = 4.0) -> void:
	subtitle_requested.emit(text, "voice", dur)

func pa_say(text: String, dur: float = 5.0) -> void:
	subtitle_requested.emit(text, "pa", dur)

func prompt(text: String) -> void:
	prompt_requested.emit(text)
