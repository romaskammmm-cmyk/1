class_name MuseumDoor
extends StaticBody3D
## Дверь музея: может быть заперта флагом; открывается по активации.

signal door_opened

var locked_flag := ""            # если задан — нужен Game.has(flag)
var opens_with := ""             # подсказка, чего не хватает
var opened_flag := ""            # флаг, который ставится после открытия
var opened := false
var is_side := false             # боковая дверь (не в проёме)

func get_prompt() -> String:
	if opened:
		return ""
	if locked_flag != "" and not Game.has(locked_flag):
		return "[E] — открыть"
	return "[E] — открыть"

func force_open() -> void:
	opened = true
	collision_layer = 0
	visible = false

func _init() -> void:
	collision_layer = 2
	collision_mask = 1

func build_door(w := 1.1, h := 2.2, thick := 0.08) -> void:
	var wood := Kit.mat("parquet_dark", Color(0.4, 0.36, 0.3), 0.65)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(w, h, thick)
	m.mesh = b
	m.material_override = wood
	add_child(m)
	# филёнки
	for fx in [-1, 1]:
		var p := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(w * 0.28, h * 0.18, thick * 0.6)
		p.mesh = pb
		p.material_override = wood
		p.position = Vector3(fx * w * 0.26, h * (0.6 if fx < 0 else 0.32), thick * 0.3)
		add_child(p)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, thick)
	cs.shape = sh
	add_child(cs)
	# ручка
	var hb := MeshInstance3D.new()
	var hs := CylinderMesh.new()
	hs.top_radius = 0.02; hs.bottom_radius = 0.02; hs.height = 0.18
	hb.mesh = hs
	hb.material_override = Kit.M("brass")
	hb.position = Vector3(w * 0.32, h * 0.5, thick * 0.6)
	hb.rotation.z = PI / 2
	add_child(hb)

func activate(player) -> void:
	if opened:
		return
	if locked_flag != "" and not Game.has(locked_flag):
		AudioMgr.play("click", 0.0, 0.7)
		Game.prompt_shown.emit(opens_with if opens_with != "" else "Заперто.")
		return
	opened = true
	collision_layer = 0
	visible = false
	if opened_flag != "":
		Game.setf(opened_flag)
	AudioMgr.play("door", 0.0, 1.0)
	door_opened.emit()
