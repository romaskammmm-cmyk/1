class_name MirrorDream
extends StaticBody3D
## «Зеркало» крипты: стекло, за которым — комната, которой нет.
## Пока смотришь — за стеклом кто-то сидит. Смотри дольше — встанет.

var mirror_id := ""
var _look_time := 0.0
var _stage := 0        # 0 спит, 1 смотрит, 2 встал, 3 событие
var _figure: Node3D = null
var _chair: Node3D = null
var _fig_base := Vector3.ZERO
var _vp: SubViewport = null
var _warned := false
var _tick_t := 0.0

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func setup(id: String, pos: Vector3, yaw := 0.0) -> void:
	mirror_id = id
	position = pos
	rotation.y = yaw
	# построение — в _ready (после добавления в дерево)
	var st := self as Node
	_need_build = true

var _need_build := false

func _ready() -> void:
	if _need_build:
		_need_build = false
		_build_frame()
		_build_diorama()

func _build_frame() -> void:
	var dark := Kit.mat("parquet_dark", Color(0.12, 0.1, 0.08), 0.6)
	var t2 := 0.14
	var w := 1.3; var h := 2.3
	Kit.mesh(self, dark, "box", Vector3(w + t2 * 2, t2, 0.16), Vector3(0, h + t2 / 2, 0))
	Kit.mesh(self, dark, "box", Vector3(w + t2 * 2, t2, 0.16), Vector3(0, -t2 / 2, 0))
	Kit.mesh(self, dark, "box", Vector3(t2, h, 0.16), Vector3(-w / 2 - t2 / 2, h / 2, 0))
	Kit.mesh(self, dark, "box", Vector3(t2, h, 0.16), Vector3(w / 2 + t2 / 2, h / 2, 0))
	Kit.plate(self, "SPECULUM — ne intuearis diu", Vector3(0, h + 0.35, 0.1), 0.7, false)
	# стекло (двусторонний тёмный материал, на него ляжет текстура диорамы)
	_vp = SubViewport.new()
	_vp.size = Vector2i(220, 400)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _vp.get_texture()
	m.roughness = 0.15
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission_energy_multiplier = 0.9
	m.emission_texture = _vp.get_texture()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 2.3)
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0, h / 2, 0.02)
	add_child(mi)

func _build_diorama() -> void:
	# комната за стеклом (в своём мире вьюпорта)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.35, -1.2)
	cam.fov = 70.0
	cam.near = 0.08
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 1.2, 2.0), Vector3.UP)
	var room := Node3D.new()
	room.name = "Diorama"
	_vp.add_child(room)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.032, 0.034)
	dark.roughness = 0.9
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.09, 0.075, 0.06)
	wall.roughness = 0.95
	# пол, стены
	Kit.mesh(room, wall, "box", Vector3(4.4, 0.1, 4.4), Vector3(0, -0.05, 2.2))
	Kit.mesh(room, wall, "box", Vector3(0.1, 3.0, 4.6), Vector3(-2.2, 1.5, 2.2))
	Kit.mesh(room, wall, "box", Vector3(0.1, 3.0, 4.6), Vector3(2.2, 1.5, 2.2))
	Kit.mesh(room, wall, "box", Vector3(4.4, 3.0, 0.1), Vector3(0, 1.5, 4.4))
	Kit.mesh(room, dark, "box", Vector3(4.4, 0.1, 4.4), Vector3(0, 3.0, 2.2))
	# стул
	_chair = Node3D.new()
	_chair.position = Vector3(0.35, 0, 2.6)
	room.add_child(_chair)
	Kit.mesh(_chair, dark, "box", Vector3(0.02, 0.9, 0.9), Vector3(0, 0.45, 0))
	# фигура
	_figure = Node3D.new()
	_figure.position = Vector3(0.35, 0, 2.3)
	room.add_child(_figure)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.95, 0.24)
	body.mesh = bm
	body.material_override = dark
	body.position = Vector3(0, 1.35, 0)
	_figure.add_child(body)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.17, 0.17, 0.18)
	head.mesh = hm
	head.material_override = dark
	head.position = Vector3(0, 2.0, 0.02)
	_figure.add_child(head)
	# тусклый свет комнаты
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.4, 1.0)
	l.light_color = Color(0.9, 0.8, 0.6)
	l.light_energy = 0.5
	l.omni_range = 3.0
	l.shadow_enabled = false
	room.add_child(l)
	# тумба с лампой сбоку (мерцание)
	Kit.mesh(room, dark, "box", Vector3(0.5, 0.8, 0.5), Vector3(1.6, 0.4, 1.2))
	var l2 := OmniLight3D.new()
	l2.position = Vector3(1.6, 1.15, 1.2)
	l2.light_color = Color(1.0, 0.6, 0.35)
	l2.light_energy = 1.4
	l2.omni_range = 2.4
	l2.shadow_enabled = false
	room.add_child(l2)
	var fl := LampFlicker.new()
	fl.light_node = l2
	fl.base_energy = 1.4
	room.add_child(fl)
	_fig_base = _figure.position

func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player_body")
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	# экономим рендер: диорама «оживает» только рядом
	if _vp:
		if dist < 13.0 and _vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif dist >= 13.0 and _vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if player.has_method("is_seeing") and player.is_seeing(global_position + Vector3(0, 1.2, 0), 7.0, 0.86):
		_look_time += delta
	else:
		_look_time = maxf(0.0, _look_time - delta * 0.7)
	# тиканье вблизи
	if dist < 3.5:
		_tick_t += delta
		if _tick_t > 4.5:
			_tick_t = 0.0
			AudioMgr.play("tick", -10.0, 0.9)
	if _look_time > 0.4 and _stage == 0 and dist < 6.0:
		_stage = 1
		AudioMgr.play("tick", -6.0, 0.75)
	if _look_time > 1.8 and _stage == 1:
		_stage = 2
		_wake_figure()
	if _look_time > 4.0 and _stage == 2 and not _warned:
		_warned = true
		_stage = 3
		_do_event()

func _wake_figure() -> void:
	if _figure == null:
		return
	var tw := create_tween()
	# фигура встаёт из-за стула и поворачивается к стеклу
	var target := _fig_base + Vector3(0.0, 0.0, -0.45)
	tw.tween_property(_figure, "position", target, 1.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_figure, "rotation:x", -0.12, 1.6)

func _do_event() -> void:
	AudioMgr.play("sting", -6.0, 1.1)
	AudioMgr.whisper_random(true)
	var zone: Node = get_tree().get_first_node_in_group("zone_c2")
	if zone and zone.has_method("on_mirror_event"):
		zone.call("on_mirror_event", mirror_id)
	# фигура исчезает (или, наоборот, оказывается ближе — пугающий вариант)
	var tw := create_tween()
	var target: Vector3 = _figure.position + Vector3(0.6, 0, 1.4)
	tw.tween_property(_figure, "position", target, 0.35)
	tw.tween_interval(0.3)
	tw.tween_property(_figure, "visible", false, 0.01)
	await tw.finished
	_stage = 4
	_look_time = 0.0
