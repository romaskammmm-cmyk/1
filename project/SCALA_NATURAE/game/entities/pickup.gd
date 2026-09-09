class_name Pickup
extends StaticBody3D
## Подбираемый предмет: ключи, гербарий и т.п.

var flag := ""
var prompt := "Взять"
var diary_who := "self"
var diary_line := ""
var sfx := "page"

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func setup(flag_name: String, pos: Vector3, prompt_text: String, d_who := "self", d_line := "", kind := "key") -> void:
	flag = flag_name
	prompt = prompt_text
	diary_who = d_who
	diary_line = d_line
	position = pos
	_build(kind)

func _build(kind: String) -> void:
	var brass := Kit.M("brass")
	var dark := Kit.M("brass_dark")
	if kind == "key":
		var shaft := Kit.mesh(self, brass, "box", Vector3(0.03, 0.05, 0.22), Vector3(0, 0.03, 0.1), Vector3.ZERO, false)
		var bit := Kit.mesh(self, brass, "box", Vector3(0.03, 0.05, 0.08), Vector3(0, -0.03, 0.2), Vector3.ZERO, false)
		var head := Kit.mesh(self, brass, "box", Vector3(0.05, 0.03, 0.06), Vector3(0, 0.09, -0.04), Vector3.ZERO, false)
	elif kind == "folder":
		var paper := Kit.mat_alpha("paper", 0.8)
		var m := Kit.mesh(self, paper, "quad", Vector3(0.2, 0.26, 1), Vector3(0, 0.02, 0), Vector3(PI / 2, 0, 0), false)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.1, 0.14, 0.3)
	cs.shape = sh
	add_child(cs)
	# слабое свечение-наводка (едва заметное)
	var l := OmniLight3D.new()
	l.light_color = Color(0.9, 0.8, 0.55)
	l.light_energy = 0.5
	l.omni_range = 2.2
	add_child(l)

func get_prompt() -> String:
	if Game.has(flag):
		return ""
	return "[E] — " + prompt

func activate(player) -> void:
	if Game.has(flag):
		return
	Game.setf(flag)
	if diary_line != "":
		Game.diary_add_cond(flag, diary_who, diary_line)
	AudioMgr.play(sfx, 0.0, 1.0)
	queue_free()
