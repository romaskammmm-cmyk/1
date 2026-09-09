class_name ZoneGate
extends Area3D
## Переход между главами. Срабатывает при входе игрока (с fade через world).

var target := ""
var spawn_name := "default"
var prompt_text := ""
var used := false

func _init() -> void:
	collision_layer = 0
	collision_mask = 4   # только игрок (layer 4)
	monitoring = true

func setup(gate_target: String, pos: Vector3, size := Vector3(2.0, 2.6, 1.6), sn := "default") -> void:
	target = gate_target
	spawn_name = sn
	position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node3D) -> void:
	if used or target == "":
		return
	if b is Player:
		used = true
		var w := get_tree().current_scene
		if w and w.has_method("goto_chapter"):
			w.call("goto_chapter", target, spawn_name)
