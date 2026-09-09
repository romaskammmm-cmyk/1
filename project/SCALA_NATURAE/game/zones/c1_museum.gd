extends Node3D
## ГЛАВА I «ДЕЖУРСТВО» — ночной музей: атриум с Лестницей Природы, коридор, дежурка, зал птиц.
## Собирается кодом из кирпичей Kit. Содержит квест: гербарий голубя → пустой пьедестал.

var w: Node3D = null
var heaven_light: OmniLight3D = null
var _angels: Array = []

func build(world: Node3D) -> void:
	w = world
	add_to_group("zone_c1")
	_build_atrium()
	_build_corridor()
	_build_office()
	_build_birds_hall()
	_build_hall4_shaft()
	_spawn_angels()
	_initial_diary()
	if Game.has("placed_herbarium"):
		on_herbarium_placed()

func apply_flags(game) -> void:
	if Game.has("door_h4_open"):
		var d: Node = find_child("DoorHall4", true, false)
		if d and d.has_method("force_open"):
			d.force_open()

func player_spawn(spawn_name := "default") -> Dictionary:
	if spawn_name == "shaft":
		return {"pos": Vector3(2.4, -4.2, -35.2), "yaw": PI}
	return {"pos": Vector3(0, 0.06, 15.2), "yaw": 0.0}

func _process(_delta: float) -> void:
	if _angels.size() > 1 and Game.has("placed_herbarium"):
		var a: Specimen = _angels[1]
		if a and not a.enabled:
			a.enabled = true
			a.global_position = a.home

# ============================================================ АТРИУМ
func _build_atrium() -> void:
	var walls := Kit.M("plaster")
	var parquet := Kit.M("parquet")
	var black := Kit.M("black")
	var wainscot := Kit.mat("parquet_dark", Color(0.33, 0.28, 0.22), 0.7)
	# большой зал 26x34, потолок 13 (север=проём в коридор, юг=вход)
	Kit.room(self, 0, 0, 26, 34, 13.0, walls, parquet, black, {
		2: [[0.344, 0.42]],   # север: в коридор (x -1.3..1.3)
		3: [[0.35, 0.41]],    # юг: главный вход
	})
	# вайнскот
	for zz in [-16.6, 16.6]:
		Kit.mesh(self, wainscot, "box", Vector3(26.6, 1.35, 0.06), Vector3(0, 0.67, zz), Vector3.ZERO, false)
	for xx in [-12.85, 12.85]:
		Kit.mesh(self, wainscot, "box", Vector3(0.06, 1.35, 33.6), Vector3(xx, 0.67, 0), Vector3.ZERO, false)
	# пилястры
	for px in [-10.5, -3.5, 3.5, 10.5]:
		for pz in [-14.5, 14.5]:
			Kit.column(self, Vector3(px, 0, pz), 13.0, 0.26)
		for px2 in [-12.4, 12.4]:
			Kit.column(self, Vector3(px2, 0, px), 13.0, 0.26)
	# двери юга (закрыты, снаружи) и востока (залы I–VI, декоративные, закрыты)
	_make_doors(Vector3(0, 0, 16.75), 2.1, 3.8, "ВХОД ДЛЯ СЛУЖАЩИХ", false)
	_make_doors(Vector3(13.15, 0, -4), 5.0, 6.5, "ЗАЛЫ I–VI · ЭКСПОЗИЦИЯ НЕИЗМЕННА", true)
	Kit.plate(self, Game.shift_label(), Vector3(0, 4.2, 16.0), 1.0, true, PI)
	# люстры и лампы
	Kit.chandelier(self, Vector3(0, 11.6, 9))
	Kit.chandelier(self, Vector3(0, 11.6, -7))
	for lx in [-8.5, 8.5]:
		Kit.chandelier(self, Vector3(lx, 11.6, 1))
	for i in range(8):
		var zz := -14.0 + i * 4.0
		Kit.wall_lamp(self, Vector3(-12.5, 2.6, zz))
		Kit.wall_lamp(self, Vector3(12.5, 2.6, zz))
	Kit.rug(self, Vector3(0, 0, 8), 3.2, 15.0)
	# таблички на стенах (северная и южная, т.к. quad без поворота)
	Kit.plate(self, "MUSEUM HISTORIAE NATURALIS · EST. 1881", Vector3(3.5, 2.3, -16.84), 1.4, true)
	Kit.plate(self, "ВХОД В ЭКСПОЗИЦИЮ ВОСПРЕЩЁН БЕЗ БИЛЕТА ВЕЧНОСТИ", Vector3(-4.0, 2.3, 16.84), 0.6, true, PI)
	# гравюры на стенах
	Kit.picture(self, "res://assets/prints/scala_chain.png", Vector3(5.8, 1.0, 16.8), 1.9, 2.6, PI)
	Kit.picture(self, "res://assets/prints/vacua.png", Vector3(-5.8, 1.0, 16.8), 1.6, 2.19, PI)
	Kit.picture(self, "res://assets/prints/columba.png", Vector3(12.7, 1.1, -2.2), 1.5, 2.05, -PI / 2)
	Kit.picture(self, "res://assets/prints/oculus.png", Vector3(-12.7, 1.1, 2.6), 1.5, 2.05, PI / 2)

	# ===== ЛЕСТНИЦА ПРИРОДЫ =====
	_build_ladder()

func _build_ladder() -> void:
	var peat := Kit.M("peat")
	var parquet := Kit.M("parquet")
	var tread_mat := Kit.mat("parquet_dark", Color(0.5, 0.42, 0.32), 0.7)
	var black := Kit.M("black")
	# нижний ствол-кожух (под лестницей) и верхний ствол
	Kit.mesh(self, peat, "cyl", Vector3(2.35, 6.5, 0), Vector3(0, 3.25, 0), Vector3.ZERO, true)
	Kit.mesh(self, peat, "cyl", Vector3(1.5, 7.0, 0), Vector3(0, 9.9, 0), Vector3.ZERO, true)
	# корни у основания
	for i in range(6):
		var a := i * PI * 2 / 6 + 0.3
		Kit.mesh(self, peat, "cyl", Vector3(0.18, 1.7, 0), Vector3(cos(a) * 2.9, 0.85, sin(a) * 2.9),
			Vector3(0.45, a, 0), true)
	# верхняя «крона»: платформа Бога и витки экспозиции
	Kit.mesh(self, black, "box", Vector3(7.4, 0.24, 7.4), Vector3(0, 11.85, 0), Vector3.ZERO, false)
	Kit.pedestal(self, Vector3(0, 12.0, 0), 2.2, 0.9, 2.2, "CAELUM — VACAT", true)
	var dim := OmniLight3D.new()
	dim.position = Vector3(0, 12.4, 0)
	dim.light_color = Color(0.9, 0.8, 0.62)
	dim.light_energy = 0.55
	dim.omni_range = 18.0
	add_child(dim)
	heaven_light = OmniLight3D.new()
	heaven_light.name = "HeavenLight"
	heaven_light.position = Vector3(0, 12.6, 0)
	heaven_light.light_color = Color(1.0, 0.85, 0.55)
	heaven_light.light_energy = 0.0
	heaven_light.omni_range = 9.0
	add_child(heaven_light)
	# витки-платформы с силуэтами «цепи бытия» (декор, недоступно)
	for lvl: float in [8.7, 10.9]:
		for i in range(8):
			var a := i * PI * 2 / 8 + lvl * 0.3
			Kit.spiral_tread(self, tread_mat, a, 2.35, lvl - 0.05, 1.25, 0.55)
			var ex := MeshInstance3D.new()
			var s: float = 0.12 + (i % 4) * 0.06
			if i % 3 == 0:
				var bm := SphereMesh.new(); bm.radius = s * 0.5; bm.height = s
				ex.mesh = bm
			elif i % 3 == 1:
				var bm := CylinderMesh.new(); bm.top_radius = s * 0.24; bm.bottom_radius = s * 0.4; bm.height = s * 1.6
				ex.mesh = bm
			else:
				var bm := BoxMesh.new(); bm.size = Vector3(s, s * 1.8, s * 0.6)
				ex.mesh = bm
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.02, 0.022, 0.024)
			dark.roughness = 0.9
			ex.material_override = dark
			ex.position = Vector3(cos(a) * 2.6, lvl + 0.02, sin(a) * 2.6)
			add_child(ex)
	# спиральные ступени (r=3.6, подъём 0.18, шаг 18°)
	for i in range(34):
		var a := deg_to_rad(18.0 * i)
		Kit.spiral_tread(self, tread_mat, a, 3.6, 0.18 * i, 2.05, 0.62)
	# площадка у ствола наверху лестницы (y 6.02, φ=270)
	Kit.spiral_tread(self, tread_mat, deg_to_rad(270), 3.6, 6.02, 2.4, 1.1)
	# галерея-кольцо (разрыв: сегменты i11, i12 — 247.5°..292.5° — юго… северо-запад)
	for i in range(16):
		if i == 11 or i == 12:
			continue
		var a := i * PI * 2 / 16
		# сегмент: длинная ось X — по касательной в точке a (хорда длиннее дуги: перекрытия скрывают стыки)
		var yaw := atan2(-cos(a), -sin(a))
		Kit.mesh(self, parquet, "box", Vector3(4.55, 0.22, 2.8),
			Vector3(cos(a) * 8.5, 6.0, sin(a) * 8.5), Vector3(0, yaw, 0), true)
	# галерея: боксы сегментов ориентированы хордами: ось X по касательной в точке a: yaw = PI/2 - a
	# мост с лестницы на галерею: от (0,-3.6) к началу сегмента i13 (φ≈292.5°, r 7.3)
	var A := Vector3(0, 6.06, -3.9)
	var B := Vector3(cos(deg_to_rad(288)) * 7.4, 6.06, sin(deg_to_rad(288)) * 7.4)
	_make_bridge(A, B)
	# пьедестал ЧЕЛОВЕКА на галерее (север, φ270) — сюда кладут гербарий
	Kit.pedestal(self, Vector3(0, 6.11, -8.5), 1.9, 1.1, 1.4, "HOMO SAPIENS — SPECIMEN EXPECTATUR", true)
	Kit.plate(self, "ВИДЫ НЕ ПРЕВРАЩАЮТСЯ. ВИДЫ ПРЕБЫВАЮТ.", Vector3(0, 7.0, -9.35), 0.8)
	_place_herb_trigger(Vector3(0, 6.11, -8.5))

## хорда-мост между двумя точками (ось бокса вдоль направления)
func _make_bridge(A: Vector3, B: Vector3) -> void:
	var dir := B - A
	var len := dir.length()
	var yaw := atan2(-dir.z, dir.x)
	var wood := Kit.mat("parquet_dark", Color(0.55, 0.44, 0.34), 0.6)
	Kit.mesh(self, wood, "box", Vector3(len, 0.1, 1.1), (A + B) / 2.0, Vector3(0, yaw, 0), true)
	# поручень (справа по ходу из центра)
	var n := Vector3(dir.z, 0, -dir.x).normalized()
	Kit.mesh(self, wood, "box", Vector3(len, 0.05, 0.06), (A + B) / 2.0 + n * 0.85 + Vector3(0, 0.95, 0), Vector3(0, yaw, 0), false)
	for P in [A, B]:
		Kit.mesh(self, wood, "cyl", Vector3(0.03, 0.95, 0), P + n * 0.85 + Vector3(0, 0.5, 0), Vector3.ZERO, false)
		Kit.mesh(self, wood, "box", Vector3(0.05, 0.06, 1.1), P + Vector3(0, 0.05, 0), Vector3.ZERO, true)

func _place_herb_trigger(pos: Vector3) -> void:
	var area := StaticBody3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.position = pos + Vector3(0, 1.35, 0)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.6, 0.9, 2.0)
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	var s: Script = preload("res://entities/place_herbarium.gd")
	area.set_script(s)

func on_herbarium_placed(_instant := false) -> void:
	# музей «узнал» вас: свет Бога загорается, второй ангел просыпается
	if heaven_light:
		var tw := create_tween()
		tw.tween_property(heaven_light, "light_energy", 1.8, 3.0).set_trans(Tween.TRANS_SINE)
	AudioMgr.play("bell", 0.0, 1.0)
	Game.diary_add_cond("c1_placed", "self", Game.get_diary_line("placed_herb"))

# ============================================================ КОРИДОР СЕВЕРНЫЙ
func _build_corridor() -> void:
	var walls := Kit.M("plaster")
	var parquet := Kit.M("parquet")
	var black := Kit.M("black")
	var moss := Kit.M("stone")
	_room_hollow(self, Vector3(0, 0, -20.5), Vector3(26, 4.2, 5), walls, parquet, black, {
		"n": [[0.207, 0.292], [0.55, 0.635], [0.765, 0.85]],
		"s": [[0.45, 0.55]],
	})
	for lx in [-11.5, -8.5, -5.5, -2.5, 0.5, 3.5, 6.5, 9.5, 12.0]:
		Kit.wall_lamp(self, Vector3(lx, 2.3, -20.5))
	# ниша с фонарём Ханса в торце коридора у атриума (юго-западный угол) — на полу атриума, у проёма
	var lp := Vector3(-2.4, 0, -15.6)
	Kit.mesh(self, Kit.M("brass_dark"), "cyl", Vector3(0.09, 0.3, 0), lp + Vector3(0, 0.15, 0), Vector3.ZERO, false)
	Kit.mesh(self, Kit.M("glass"), "sphere", Vector3(0.1, 0.2, 0), lp + Vector3(0, 0.38, 0), Vector3.ZERO, false)
	var hl := OmniLight3D.new()
	hl.position = lp + Vector3(0, 0.38, 0)
	hl.light_color = Color(1.0, 0.72, 0.4)
	hl.light_energy = 1.5
	hl.omni_range = 5.0
	hl.shadow_enabled = true
	add_child(hl)
	var fl := LampFlicker.new()
	fl.light_node = hl
	add_child(fl)
	var hanz_note := Note3D.new()
	hanz_note.setup("n_hanz_note", lp + Vector3(0.45, 0.03, 0.5), 0.9)
	add_child(hanz_note)
	hanz_note.opened.connect(_on_note_opened)

# ============================================================ ДЕЖУРКА
func _build_office() -> void:
	var walls := Kit.M("plaster")
	var parquet := Kit.M("parquet")
	var black := Kit.M("black")
	var wood := Kit.mat("parquet_dark", Color(0.42, 0.36, 0.3), 0.62)
	_room_hollow(self, Vector3(8, 0, -26), Vector3(6.5, 4.2, 6), walls, parquet, black, {"s": [[0.33, 0.67]]})
	Kit.wall_lamp(self, Vector3(5.2, 2.3, -26))
	Kit.wall_lamp(self, Vector3(11.0, 2.3, -23.2))
	# стол
	Kit.mesh(self, wood, "box", Vector3(1.8, 0.09, 0.95), Vector3(8, 0.79, -24.4), Vector3.ZERO, true)
	for fx in [-0.8, 0.8]:
		Kit.mesh(self, wood, "box", Vector3(0.09, 0.76, 0.09), Vector3(8 + fx, 0.39, -24.4), Vector3.ZERO, true)
	# журнал на столе
	var jn := Note3D.new()
	jn.setup("n_hanz_journal", Vector3(8.45, 0.87, -24.1), 0.35)
	add_child(jn)
	jn.opened.connect(_on_note_opened)
	# ключ на гвозде у западной стены
	if not Game.has("key_hall4"):
		var key := Pickup.new()
		key.setup("key_hall4", Vector3(4.93, 1.45, -25.4), "взять ключ (зал №4)", "self", Game.get_diary_line("key_hall4"), "click")
		key.rotation.y = 0.9
		add_child(key)
	# схема на стене (восточная) — читается как записка
	var mn := Note3D.new()
	mn.setup("n_office_map", Vector3(11.0, 1.6, -26.3), -PI / 2)
	mn.scale = Vector3(2.4, 2.4, 2.4)
	mn.rotation.x = PI / 2
	add_child(mn)
	mn.opened.connect(_on_note_opened)
	# стул и шкаф
	_chair(Vector3(7.3, 0, -24.6))
	Kit.mesh(self, wood, "box", Vector3(1.6, 2.0, 0.6), Vector3(8.2, 1.0, -28.6), Vector3.ZERO, true)
	Kit.plate(self, "ДЕЖУРНАЯ КОМНАТА", Vector3(5.2, 3.5, -23.2), 0.8)

func _chair(pos: Vector3) -> void:
	var wood := Kit.mat("parquet_dark", Color(0.38, 0.32, 0.26), 0.62)
	Kit.mesh(self, wood, "box", Vector3(0.44, 0.07, 0.44), pos + Vector3(0, 0.52, 0), Vector3.ZERO, true)
	for sx in [-0.19, 0.19]:
		for sz in [-0.19, 0.19]:
			Kit.mesh(self, wood, "box", Vector3(0.05, 0.5, 0.05), pos + Vector3(sx, 0.28, sz), Vector3.ZERO, true)
	Kit.mesh(self, wood, "box", Vector3(0.44, 0.06, 0.05), pos + Vector3(0, 0.86, -0.2), Vector3.ZERO, true)
	Kit.mesh(self, wood, "box", Vector3(0.44, 0.7, 0.05), pos + Vector3(0, 1.2, -0.2), Vector3(0.12, 0, 0), true)

# ============================================================ ЗАЛ ПТИЦ
func _build_birds_hall() -> void:
	var walls := Kit.M("plaster")
	var parquet := Kit.M("parquet")
	var black := Kit.M("black")
	var wallpaper := Kit.M("wallpaper")
	_room_hollow(self, Vector3(-6.5, 0, -28.5), Vector3(13, 5.2, 11), wallpaper, parquet, black, {"s": [[0.41, 0.59]]})
	# верх стен — штукатурка
	for zz in [-33.8, -23.2]:
		Kit.mesh(self, walls, "box", Vector3(13.4, 3.6, 0.06), Vector3(-6.5, 3.4, zz), Vector3.ZERO, false)
	for xx in [-13.2, 0.2]:
		Kit.mesh(self, walls, "box", Vector3(0.06, 3.6, 11.4), Vector3(xx, 3.4, -28.5), Vector3.ZERO, false)
	for lx in [-11.5, -1.6]:
		Kit.wall_lamp(self, Vector3(lx, 2.6, -28.5))
	Kit.chandelier(self, Vector3(-6.5, 4.9, -28.5))
	# ВИТРИНА 7-Б (гербарий голубя) — юго-восток
	var vit_pos := Vector3(-1.4, 0, -24.9)
	Kit.vitrine(self, vit_pos, 1.8, 2.3, 1.2, func(holder: Node3D):
		if not Game.has("herbarium_pigeon"):
			var herb := Pickup.new()
			herb.setup("herbarium_pigeon", Vector3(0, 1.55, 0), "взять гербарий «COLUMBA GIRAFFA»", "self", Game.get_diary_line("got_pigeon_herb"), "page")
			herb.rotation.y = 0.4
			holder.add_child(herb))
	Kit.plate(self, "ВИТРИНА 7-Б · COLUMBA GIRAFFA (?)", vit_pos + Vector3(0, 2.45, 0.9), 0.9)
	Kit.picture(self, "res://assets/prints/lilium.png", Vector3(-6.5, 1.0, -33.72), 1.5, 2.05, 0.0)
	var hn := Note3D.new()
	hn.setup("n_herbarium_case", vit_pos + Vector3(-1.1, 0.05, -0.8), 1.2)
	add_child(hn)
	hn.opened.connect(_on_note_opened)
	# скелет «жирафо-голубя» в центре зала
	_make_giraffe_skeleton(Vector3(-6.5, 0, -30.0))
	# чучела птиц на жёрдочках (северная стена)
	for i in range(3):
		_bird_effigy(Vector3(-11.0 + i * 2.6, 0, -33.2), 0.16 + i * 0.05)
	# циркуляр директора у входа (юго-запад)
	var cn := Note3D.new()
	cn.setup("n_director_1", Vector3(-11.9, 1.7, -23.35), PI)
	cn.scale = Vector3(2.6, 2.6, 2.6)
	cn.rotation.x = PI / 2
	add_child(cn)
	cn.opened.connect(_on_note_opened)

func _bird_effigy(pos: Vector3, s: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	Kit.mesh(holder, Kit.M("brass_dark"), "cyl", Vector3(0.012, 0.9, 0), Vector3(0, 1.0, 0), Vector3(0, 0, PI / 2), false)
	var dark := Kit.M("black")
	Kit.mesh(holder, dark, "sphere", Vector3(0.13 * s * 3, 0.26 * s * 3, 0), Vector3(0, 1.2, 0))
	Kit.mesh(holder, dark, "sphere", Vector3(0.05 * s * 3, 0.1 * s * 3, 0), Vector3(0, 1.34, -0.16))
	Kit.mesh(holder, dark, "cone", Vector3(0.02, 0.09, 0), Vector3(0, 1.34, -0.28), Vector3(PI / 2, 0, 0))
	Kit.mesh(holder, dark, "cone", Vector3(0.05, 0.2, 0), Vector3(0, 1.16, 0.3), Vector3(PI * 0.7, 0, 0))
	Kit.plate(holder, "AVIS · EX SYSTEMATE", Vector3(0, 0.85, 0), 0.42, false)

func _make_giraffe_skeleton(center: Vector3) -> void:
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.88, 0.86, 0.79)
	bone.roughness = 0.8
	var holder := Node3D.new()
	holder.position = center
	add_child(holder)
	Kit.mesh(holder, Kit.M("brass_dark"), "cyl", Vector3(0.95, 0.14, 0), Vector3(0, 0.07, 0), Vector3.ZERO, true)
	# грудина
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.4; bs.height = 0.9
	body.mesh = bs
	body.material_override = bone
	body.position = Vector3(0, 0.9, 0.25)
	body.scale = Vector3(1, 0.8, 1.4)
	holder.add_child(body)
	# шея: дуга
	for i in range(15):
		var t := i / 14.0
		var ang := -0.6 + t * 1.75
		var y := 0.8 + t * 2.9
		var x := 0.42 - t * 0.6
		var z := 0.2 + sin(t * PI) * 0.3
		Kit.mesh(holder, bone, "cyl", Vector3(0.05 + t * 0.02, 0.18, 0), Vector3(x, y, z), Vector3(0, 0, ang), false)
	# череп
	var skull := MeshInstance3D.new()
	var sk := SphereMesh.new()
	sk.radius = 0.08; sk.height = 0.18
	skull.mesh = sk
	skull.material_override = bone
	skull.position = Vector3(-0.2, 3.75, 0.3)
	holder.add_child(skull)
	Kit.mesh(holder, bone, "cone", Vector3(0.025, 0.16, 0), Vector3(-0.3, 3.78, 0.3), Vector3(0, 0, PI / 2), false)
	# ноги и крылья
	for side in [-1.0, 1.0]:
		Kit.mesh(holder, bone, "cyl", Vector3(0.028, 0.95, 0), Vector3(side * 0.22, 0.5, 0.1), Vector3(0.1, 0, side * 0.15), false)
		for k in range(3):
			Kit.mesh(holder, bone, "cyl", Vector3(0.016, 0.5, 0), Vector3(side * 0.24, 1.0, 0.3 + k * 0.13), Vector3(0.25, side * 0.4, k * 0.35), false)

# ============================================================ ШАХТА ЗАЛА №4
func _build_hall4_shaft() -> void:
	var stone := Kit.M("stone")
	var brass := Kit.M("brass_dark")
	var wood := Kit.mat("parquet_dark", Color(0.45, 0.38, 0.32), 0.6)
	var black := Kit.M("black")
	# дверь в проёме северной стены коридора (проём x 1.3..3.5, центр 2.4)
	var door := MuseumDoor.new()
	door.name = "DoorHall4"
	add_child(door)
	door.position = Vector3(2.4, 0, -22.88)
	door.build_door(2.1, 2.4)
	door.locked_flag = "key_hall4"
	door.opens_with = "Заперто. Ниже табличка: «Ключ на гвозде в дежурке»."
	door.opened_flag = "door_h4_open"
	Kit.door_frame(self, Vector3(2.4, 0, -22.88), 2.3, 2.5, 0.26, brass)
	Kit.plate(self, "ЗАЛ №4 — СЛУЖЕБНЫЙ ВХОД", Vector3(2.4, 2.8, -22.6), 0.7)
	door.door_opened.connect(_on_h4_opened)
	# шахта: площадка, стены, лестница вниз (12 ступеней, к северу)
	Kit.mesh(self, wood, "box", Vector3(3.0, 0.12, 2.4), Vector3(2.4, -0.06, -24.5), Vector3.ZERO, true, "surf_wood")
	Kit.mesh(self, stone, "box", Vector3(0.3, 4.6, 10.2), Vector3(0.75, -2.2, -27.4), Vector3.ZERO, true)
	Kit.mesh(self, stone, "box", Vector3(0.3, 4.6, 10.2), Vector3(4.05, -2.2, -27.4), Vector3.ZERO, true)
	for i in range(12):
		var y := -0.35 * (i + 1)
		var z := -25.6 - 0.62 * i
		Kit.mesh(self, stone, "box", Vector3(2.9, 0.14, 0.66), Vector3(2.4, y, z), Vector3.ZERO, true)
	# северная стена с проёмом (пирсы + перемычка); проём x 1.35..3.45, y -4.45..-2.5
	Kit.mesh(self, stone, "box", Vector3(0.75, 4.6, 0.3), Vector3(0.975, -2.2, -32.6), Vector3.ZERO, true)
	Kit.mesh(self, stone, "box", Vector3(0.75, 4.6, 0.3), Vector3(3.825, -2.2, -32.6), Vector3.ZERO, true)
	Kit.mesh(self, stone, "box", Vector3(3.6, 2.6, 0.3), Vector3(2.4, -1.2, -32.6), Vector3.ZERO, true)
	Kit.plate(self, "КРИПТА · ДАЛЕЕ ТОЛЬКО С РАЗРЕШЕНИЯ ДИРЕКТОРА", Vector3(2.4, -2.2, -32.3), 1.3)
	# решётка-дверь в проёме (открывается, когда гербарий ляжет на пьедестал)
	var grate := MuseumDoor.new()
	grate.name = "DoorCrypt"
	add_child(grate)
	grate.position = Vector3(2.4, -3.35, -32.62)
	grate.build_door(2.05, 2.05)
	grate.locked_flag = "placed_herbarium"
	grate.opens_with = "Решётка заперта на висячий замок. Снизу тянет тиной и цветами."
	grate.opened_flag = "grate_open"
	grate.door_opened.connect(_on_crypt_opened)
	# пол тамбура за решёткой (уровень последней ступени)
	Kit.mesh(self, black, "box", Vector3(2.4, 0.14, 4.0), Vector3(2.4, -4.27, -34.6), Vector3.ZERO, true, "surf_stone")
	# стены и потолок тамбура (низкий, каменный)
	Kit.mesh(self, stone, "box", Vector3(0.24, 2.6, 4.2), Vector3(1.27, -3.2, -34.6), Vector3.ZERO, true)
	Kit.mesh(self, stone, "box", Vector3(0.24, 2.6, 4.2), Vector3(3.53, -3.2, -34.6), Vector3.ZERO, true)
	Kit.mesh(self, stone, "box", Vector3(2.5, 2.6, 0.24), Vector3(2.4, -3.2, -36.7), Vector3.ZERO, true)
	Kit.mesh(self, black, "box", Vector3(2.5, 0.2, 4.2), Vector3(2.4, -1.9, -34.6))
	# зелёное свечение сквозь щели дальней стены
	var gl := OmniLight3D.new()
	gl.position = Vector3(2.4, -3.4, -36.3)
	gl.light_color = Color(0.2, 0.8, 0.5)
	gl.light_energy = 0.4
	gl.omni_range = 3.4
	add_child(gl)
	var fl := LampFlicker.new()
	fl.light_node = gl
	fl.base_energy = 0.4
	add_child(fl)
	if not Game.has("saw_swamp_glow"):
		Game.setf("saw_swamp_glow")
	# портал в главу II (Крипта)
	var gate := ZoneGate.new()
	add_child(gate)
	gate.setup("c2_vault", Vector3(2.4, -3.0, -35.6), Vector3(1.8, 2.2, 1.0), "default")

func _on_h4_opened() -> void:
	Game.diary_add_cond("h4_first", "self",
		"За дверью №4 нет зала. Площадка и лестница вниз, в камень. Снизу пахнет тиной и — странно — цветами. Из глубины кто-то дышит в такт со мной.")

func _on_crypt_opened() -> void:
	AudioMgr.play("whoosh", -6.0, 0.85)
	Game.diary_add_cond("crypt_grate", "self",
		"Висячий замок щёлкнул сам, едва я коснулся решётки. Как будто музей ждал, пока я докажу, что виды — не клетки. Лестница вниз пахнет водой. Ханс, я иду.")

# ============================================================ АНГЕЛЫ
func _spawn_angels() -> void:
	var a1 := Specimen.new()
	a1.name = "AngelBirds"
	add_child(a1)
	a1.position = Vector3(-11.6, 0, -32.4)
	a1.target = w.player
	a1.name_tag = "SPECIMEN A-1"
	a1.grabbed.connect(_on_angel_grab_1)
	var a2 := Specimen.new()
	a2.name = "AngelAtrium"
	add_child(a2)
	a2.position = Vector3(-12.1, 0, 4.0)
	a2.target = w.player
	a2.enabled = false
	a2.grabbed.connect(_on_angel_grab_2)
	_angels = [a1, a2]

func _on_angel_grab_1() -> void:
	w.do_grab_effect(Vector3(7.9, 0.06, -24.0), 180.0, "other", Game.get_diary_line("grabbed_1"))

func _on_angel_grab_2() -> void:
	w.do_grab_effect(Vector3(0, 0.06, 13.0), 0.0, "other",
		"Меня снова переставили. Теперь я у входа — как встречающий. В дневнике сверху чужим почерком: «ты не убегаешь. тебя расставляют. это разные вещи».")

func _initial_diary() -> void:
	if Game.loop == 0:
		Game.diary_add_cond("c1_intro", "self", Game.get_diary_line("intro_1") % 1)
		Game.diary_add_cond("c1_intro2", "self", Game.get_diary_line("intro_2"))
	else:
		Game.diary_add_cond("c1_repeat", "self",
			"Смена №%d. Всё началось заново, с той же секунды. Фонарь Ханса снова на полу, масло снова пролито. Но я помню этот музей. И, кажется, музей помнит меня." % (Game.loop + 1))

# ============================================================ УТИЛИТЫ
func _on_note_opened(id: String) -> void:
	w.open_note(id)

func _room_hollow(parent: Node3D, center: Vector3, size: Vector3, mw: Material, mf: Material, mc: Material, side_gaps: Dictionary) -> void:
	var sx: float = size.x; var sz: float = size.z
	var h: float = size.y
	var cx: float = center.x; var cz: float = center.z
	Kit.mesh(parent, mf, "box", Vector3(sx, 0.12, sz), Vector3(cx, -0.06, cz), Vector3.ZERO, true, "surf_wood")
	Kit.mesh(parent, mc, "box", Vector3(sx, 0.12, sz), Vector3(cx, h + 0.06, cz))
	_seg_wall(parent, mw, Vector3(sx, h, 0), cx, cz - sz / 2, 0.24, side_gaps.get("n", []), false)   # север z-
	_seg_wall(parent, mw, Vector3(sx, h, 0), cx, cz + sz / 2, 0.24, side_gaps.get("s", []), false)   # юг z+
	_seg_wall(parent, mw, Vector3(sz, h, 0), cx - sx / 2, cz, 0.24, side_gaps.get("w", []), true)    # запад x-
	_seg_wall(parent, mw, Vector3(sz, h, 0), cx + sx / 2, cz, 0.24, side_gaps.get("e", []), true)    # восток x+

func _seg_wall(parent: Node3D, m: Material, run: Vector3, cx: float, cz: float, thick: float, gaps: Array, along_z: bool) -> void:
	var length: float = run.x
	var start: float = -length / 2
	var spans: Array = []
	if gaps.is_empty():
		spans = [[start, length / 2]]
	else:
		var cuts: Array = []
		for g in gaps:
			cuts.append([start + g[0] * length, start + g[1] * length])
		cuts.sort_custom(func(a, b): return a[0] < b[0])
		var cur := start
		for c in cuts:
			if c[0] > cur + 0.03:
				spans.append([cur, c[0]])
			cur = maxf(cur, c[1])
		if cur < length / 2 - 0.03:
			spans.append([cur, length / 2])
	for s in spans:
		var mid: float = (s[0] + s[1]) / 2
		var l: float = s[1] - s[0]
		if along_z:
			Kit.mesh(parent, m, "box", Vector3(thick, run.y + 0.1, l), Vector3(cx, run.y / 2, cz + mid), Vector3.ZERO, true)
		else:
			Kit.mesh(parent, m, "box", Vector3(l, run.y + 0.1, thick), Vector3(cx + mid, run.y / 2, cz), Vector3.ZERO, true)

func _make_doors(pos: Vector3, w: float, h: float, label: String, big: bool) -> void:
	var wood := Kit.mat("parquet_dark", Color(0.3, 0.26, 0.21), 0.7)
	for side in [-1.0, 1.0]:
		Kit.mesh(self, wood, "box", Vector3(w / 2, h, 0.16), pos + Vector3(side * w * 0.26, h / 2, 0.14 * side if big else 0.1 * side), Vector3(0, side * 0.06, 0), true)
	Kit.plate(self, label, pos + Vector3(0, h + 0.22, 0.12), minf(w, 3.0) * 0.5)
	for yy in [0.4, 1.6, h - 0.4]:
		Kit.mesh(self, Kit.M("brass_dark"), "box", Vector3(w + 0.08, 0.07, 0.12), pos + Vector3(0, yy, 0.12), Vector3.ZERO, false)
