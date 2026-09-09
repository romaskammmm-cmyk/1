extends Node
## SCALA NATURAE — глобальное состояние игры (autoload: Game)
## Флаги, главы, петля-цикл, дневник, UI-промпты, ввод.

signal chapter_loaded(chapter_id: String)
signal diary_changed
signal prompt_shown(text: String)
signal prompt_hidden
signal fade_requested(kind: String)   # "to_black" | "to_clear"
signal event_played(id: String)       # одноразовые события мира

const ZONE_C1 = "c1_museum"
const ZONE_C2 = "c2_vault"
const ZONE_C3 = "c3_swamp"
const ZONE_C4 = "c4_herbarium"
const ZONE_C5 = "c5_finale"
const SAVE_PATH = "user://scala_save.json"

var flags := {}                 # bool-флаги сюжета
var counters := {}              # счётчики (круги петли и т.п.)
var loop := 0                   # номер круга петли (0 — первый)
var chapter := ""               # текущая зона
var diary := []                 # записи: [{id, who, text, ch}]
var pending_fade := false

var _input_map := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"run": [KEY_SHIFT], "interact": [KEY_E], "lantern": [KEY_F], "diary": [KEY_J],
	"pause": [KEY_ESCAPE], "look_close": [KEY_R],
}

func _ready() -> void:
	_setup_input()
	randomize()
	load_game()

func _setup_input() -> void:
	for action in _input_map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in _input_map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

# ---------- флаги / дневник ----------
func has(f: String) -> bool: return flags.get(f, false)
func setf(f: String) -> void:
	flags[f] = true
	event_played.emit(f)

func diary_add(who: String, text: String) -> void:
	diary.append({"who": who, "text": text, "loop": loop})
	diary_changed.emit()
	save_game()

func diary_add_cond(f: String, who: String, text: String) -> void:
	if not flags.get("d:" + f, false):
		flags["d:" + f] = true
		diary_add(who, text)

# ---------- сохранение (между кругами петли) ----------
func save_game() -> void:
	var d := {"flags": flags, "counters": counters, "loop": loop, "diary": diary, "chapter": chapter}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		flags = (d as Dictionary).get("flags", {})
		counters = (d as Dictionary).get("counters", {})
		loop = int((d as Dictionary).get("loop", 0))
		diary = (d as Dictionary).get("diary", [])
		if (d as Dictionary).has("chapter"):
			chapter = str((d as Dictionary).get("chapter", ""))
			if not _valid_chapter(chapter):
				chapter = ""

func _valid_chapter(c: String) -> bool:
	return c in [ZONE_C1, ZONE_C2, ZONE_C3, ZONE_C4, ZONE_C5]

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and chapter != ""

# ---------- записки (JSON-контент) ----------
var _notes := {}
func _ensure_notes() -> void:
	if not _notes.is_empty():
		return
	if not FileAccess.file_exists("res://content/notes.json"):
		return
	var f := FileAccess.open("res://content/notes.json", FileAccess.READ)
	if not f: return
	var arr: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(arr) == TYPE_ARRAY:
		for it in arr:
			_notes[str((it as Dictionary).get("id", ""))] = it

func get_note(id: String) -> Dictionary:
	_ensure_notes()
	return _notes.get(id, {}) as Dictionary

func get_diary_line(key: String, fallback := "") -> String:
	if not FileAccess.file_exists("res://content/diary_lines.json"):
		return fallback
	if not _lines_loaded:
		_lines_loaded = true
		var f := FileAccess.open("res://content/diary_lines.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				_diary_lines = d
	return str(_diary_lines.get(key, fallback))

var _diary_lines := {}
var _lines_loaded := false

func reset_run() -> void:
	flags.clear(); counters.clear(); diary.clear(); loop = 0
	save_game()

# ---------- главы ----------
func start_game() -> void:
	if chapter == "":
		chapter = ZONE_C1
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func goto_menu() -> void:
	chapter = ""
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func load_chapter(id: String) -> void:
	chapter = id
	chapter_loaded.emit(id)

## зона-контроллер сообщает о готовности
func zone_ready(zone) -> void:
	zone.apply_flags(self)

## прибавить круг петли (сброс смены)
func next_loop() -> void:
	loop += 1
	counters["shifts"] = loop + 1
	save_game()

func shift_label() -> String:
	return "СМЕНА №%d" % (counters.get("shifts", 1))
