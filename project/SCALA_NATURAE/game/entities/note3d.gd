class_name Note3D
extends StaticBody3D
## Записка в мире: лист бумаги на полу/столе. Активация — чтение (UI зоны).

signal opened(note_id: String)

var note_id := "note"
var title := ""
var body := ""

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func setup(id: String, pos: Vector3, rot_y := 0.0) -> void:
	note_id = id
	position = pos
	rotation.y = rot_y
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = Kit.tex("paper")
	paper.roughness = 0.85
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.32)
	m.mesh = q
	m.material_override = paper
	add_child(m)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.24, 0.03, 0.32)
	cs.shape = sh
	add_child(cs)

func get_prompt() -> String:
	return "[E] — прочитать"

func activate(player) -> void:
	opened.emit(note_id)
