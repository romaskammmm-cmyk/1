class_name Specimen
extends Node3D
## «Чучело-ангел»: движется, только когда его никто не видит.
## Не убивает — ПЕРЕСТАВЛЯЕТ (эффект: игрок оказывается в другом месте коллекции).

signal grabbed

var target: Node3D = null            # за кем идти (игрок)
var home := Vector3.ZERO
var chase := true
var speed := 1.6
var reach := 1.5                     # дистанция «перестановки»
var max_dist := 30.0
var audio_key := "creak"
var tick := 0.0
var sense_interval := 0.12
var caught := false
var enabled := true
var name_tag := "SPECIMEN"

func _ready() -> void:
	home = global_position
	build_body()

func build_body() -> void:
	## тёмная человекообразная фигура из примитивов (силуэт в темноте)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.016, 0.017, 0.02)
	black.roughness = 0.85
	var mi := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.44, 1.25, 0.26)
	mi.mesh = body
	mi.material_override = black
	mi.position = Vector3(0, 1.5, 0)
	add_child(mi)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.2, 0.2, 0.24)
	head.mesh = hb
	head.material_override = black
	head.position = Vector3(0, 2.25, 0.0)
	add_child(head)
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.02; hm.bottom_radius = 0.14; hm.height = 0.12
	hat.mesh = hm
	hat.material_override = black
	hat.position = Vector3(0, 2.4, 0.0)
	add_child(hat)
	# латунная бирка
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.5, 0.45, 0.36)
	plate_mat.roughness = 0.5
	plate_mat.metallic = 0.9
	var tag := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.05)
	tag.mesh = q
	tag.material_override = plate_mat
	tag.position = Vector3(0, 1.35, 0.14)
	add_child(tag)
	# фантомная физика не нужна: идёт сквозь всё, но с проверкой линии взгляда

func _physics_process(delta: float) -> void:
	if not enabled or caught or target == null:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = sense_interval
	var player: Node3D = target
	var seen: bool = false
	if player.has_method("is_seeing"):
		seen = player.is_seeing(global_position, max_dist)
	if not seen:
		# крадётся к игроку, пока не виден
		var to_p: Vector3 = player.global_position - global_position
		var d: float = to_p.length()
		if d > max_dist * 1.2:
			return
		to_p.y = 0.0
		if to_p.length() > 0.01:
			global_position += to_p.normalized() * speed * sense_interval * 3.2
			look_at(player.global_position + Vector3.UP * 1.5, Vector3.UP)
		if d < reach and not seen:
			_do_grab()

func _do_grab() -> void:
	caught = true
	grabbed.emit()
	AudioMgr.play("sting", 0.0, 0.85)
