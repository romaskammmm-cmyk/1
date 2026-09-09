extends Area3D
## Базовый интерактивный объект [code-05]
## kind: note | seal | key | door_key | door_origin | altar | pa_panel
## chapter1 слушает сигнал interacted.

signal interacted(node: Area3D)

@export var kind := "note"
@export var note_title := ""
@export_multiline var note_text := ""
@export var one_shot := true
@export var prompt_text := "[E] Взаимодействовать"
var used := false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 8
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.2, 1.6)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)

func interact() -> void:
	if one_shot and used: return
	used = true
	interacted.emit(self)

func prompt() -> String:
	if one_shot and used: return ""
	return prompt_text
