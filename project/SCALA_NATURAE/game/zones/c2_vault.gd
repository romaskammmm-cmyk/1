extends Node3D
## ГЛАВА II «ЗАЛ НЕПРИЗНАННЫХ» — крипта музея.
## Лабораторные ниши с пробами-семенами, зеркала, Мать Воды, спуск в болото.

const SPECTRA := [
	{"id": "a", "flag": "specimen_taken_a", "name": "ПРОБА A",
	 "diary": "Семя первое. Оно лежало в банке A, в формалине, но семя не тонет. Когда я взял его, за стеклом ниши кто-то выдохнул: «форма не дана. форма — ответ почвы»."},
	{"id": "b", "flag": "specimen_taken_b", "name": "ПРОБА B",
	 "diary": "Семя второе. Сухое и тёплое, как птичье крыло. Голос за стеклом: «наследуется ли рана? спроси у того, кто носит рану, но не помнит, когда получил её»."},
	{"id": "c", "flag": "specimen_taken_c", "name": "ПРОБА C",
	 "diary": "Семя третье. Тяжёлое, как камень с горы. «Один вид — два имени. А у человека, которому положено быть одним, — сколько имён?» Вода замолчала. Теперь она ждёт меня внизу."},
]

var w: Node3D = null
var _spawn_points := {}
var _heart_t := 0.0

func build(world: Node3D) -> void:
	w = world
	add_to_group("zone_c2")
	_build_room()
	_build_labs()
	_build_water_niche()
	_build_mirrors_and_descent()
	if not Game.has("c2_enter"):
		Game.diary_add("self",
			"Крипта. Здесь музей прячет то, что не влезло в каталог: переходные формы, ошибки природы, почти-виды. Таблички на латыни — как приговоры.")

func apply_flags(game) -> void:
	for k: String in ["a", "b", "c"]:
		if Game.has("specimen_taken_" + k):
			var n: Node = find_child("Specimen" + k, true, false)
			if n: n.queue_free()

func player_spawn(spawn_name := "default") -> Dictionary:
	if _spawn_points.is_empty():
		return {"pos": Vector3(0, 0.1, 15.0), "yaw": 0.0}
	return {"pos": _spawn_points.get(spawn_name, Vector3(0, 0.1, 15.0)), "yaw": 0.0}

# ============================================================ ЗАЛ
func _build_room() -> void:
	var wall_m := Kit.M("plaster")
	var floor_m := Kit.M("stone")
	var black := Kit.M("black")
	# 4 отсека 12.8x12.8 с центральным крестом проходов
	var centers := [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]
	for c in centers:
		Kit.mesh(self, floor_m, "box", Vector3(12.6, 0.12, 12.6), c + Vector3(0, -0.06, 0), Vector3.ZERO, true, "surf_stone")
		Kit.mesh(self, black, "box", Vector3(12.6, 0.12, 12.6), c + Vector3(0, 6.0, 0))
	# внешние стены: y=0..6, x/z на периметре ±13.3
	_seg_wall(wall_m, Vector3(26.6, 6.0, 0), 0, -13.3, 0.3, [], false)
	_seg_wall(wall_m, Vector3(26.6, 6.0, 0), 0, 13.3, 0.3, [], false)
	_seg_wall(wall_m, Vector3(26.6, 6.0, 0), -13.3, 0, 0.3, [], true)
	_seg_wall(wall_m, Vector3(26.6, 6.0, 0), 13.3, 0, 0.3, [], true)
	# простенки креста с арками (центр 0,0)
	for x in [-0.4, 0.4]:
		_seg_wall(wall_m, Vector3(7.2, 6.0, 0), x, -7.0, 0.55, [[0.30, 0.70]], false)
		_seg_wall(wall_m, Vector3(7.2, 6.0, 0), x, 7.0, 0.55, [[0.30, 0.70]], false)
	for z in [-0.4, 0.4]:
		_seg_wall(wall_m, Vector3(7.2, 6.0, 0), -7.0, z, 0.55, [[0.30, 0.70]], true)
		_seg_wall(wall_m, Vector3(7.2, 6.0, 0), 7.0, z, 0.55, [[0.30, 0.70]], true)
	# колонны арки
	for x in [-0.4, 0.4]:
		for z in [-7.0, 7.0]:
			Kit.column(self, Vector3(x, 0, z), 6.0, 0.16, false)
	for x in [-7.0, 7.0]:
		for z in [-0.4, 0.4]:
			Kit.column(self, Vector3(x, 0, z), 6.0, 0.16, false)
	# свет
	for i in range(7):
		Kit.wall_lamp(self, Vector3(-12.9, 2.8, -10.0 + i * 3.33), 0.8)
		Kit.wall_lamp(self, Vector3(12.9, 2.8, -10.0 + i * 3.33), 0.8)
	for i in range(4):
		Kit.wall_lamp(self, Vector3(-10.0 + i * 6.7, 2.8, -12.9), 0.8)
		Kit.wall_lamp(self, Vector3(-10.0 + i * 6.7, 2.8, 12.9), 0.8)
	# вход с юга (лестница из зала №4) — оформление южной стены
	Kit.plate(self, "SPECIMINA NON RECOGNITA · ЗАЛ №4", Vector3(0, 4.4, 13.12), 1.6, true)
	Kit.plate(self, "«ошибки природы, изъятые из обращения»", Vector3(0, 3.7, 13.12), 0.9, false)
	_spawn_points["default"] = Vector3(-2.5, 0.1, 10.5)
	_spawn_points["from_swamp"] = Vector3(11.9, 0.1, 6.4)

func _seg_wall(m: Material, run: Vector3, cx: float, cz: float, thick: float, gaps: Array, along_z: bool) -> void:
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
			if c[0] > cur + 0.05:
				spans.append([cur, c[0]])
			cur = maxf(cur, c[1])
		if cur < length / 2 - 0.05:
			spans.append([cur, length / 2])
	for sp in spans:
		var mid: float = (sp[0] + sp[1]) / 2
		var l: float = sp[1] - sp[0]
		if along_z:
			Kit.mesh(self, m, "box", Vector3(thick, run.y + 0.1, l), Vector3(cx, run.y / 2, cz + mid), Vector3.ZERO, true)
		else:
			Kit.mesh(self, m, "box", Vector3(l, run.y + 0.1, thick), Vector3(cx + mid, run.y / 2, cz), Vector3.ZERO, true)

# ============================================================ НИШИ С ПРОБАМИ (западная стена)
func _build_labs() -> void:
	# столы у западной стены (грань стены x=-13.15)
	var niche_z := [-8.0, -0.5, 7.0]
	for i in range(3):
		var key: String = ["a", "b", "c"][i]
		var nz: float = niche_z[i]
		var wood := Kit.mat("parquet_dark", Color(0.2, 0.17, 0.13), 0.6)
		var cx := -12.2
		# столешница
		Kit.mesh(self, wood, "box", Vector3(1.6, 0.1, 0.85), Vector3(cx, 0.97, nz), Vector3.ZERO, true)
		# ножки
		for fx in [-0.68, 0.68]:
			Kit.mesh(self, wood, "box", Vector3(0.09, 0.92, 0.09), Vector3(cx + fx, 0.46, nz - 0.28), Vector3.ZERO, true)
			Kit.mesh(self, wood, "box", Vector3(0.09, 0.92, 0.09), Vector3(cx + fx, 0.46, nz + 0.28), Vector3.ZERO, true)
		if not Game.has("specimen_taken_" + key):
			var spec := Node3D.new()
			spec.name = "Specimen" + key
			spec.position = Vector3(cx - 0.15, 0, nz)
			add_child(spec)
			var glass_m := Kit.mat_alpha("glass_grime", 0.1)
			Kit.mesh(spec, glass_m, "cyl", Vector3(0.17, 0.5, 0), Vector3(0, 1.22, 0), Vector3.ZERO, false)
			Kit.mesh(spec, Kit.M("black"), "cyl", Vector3(0.19, 0.06, 0), Vector3(0, 1.5, 0), Vector3.ZERO, false)
			var seed := SeedPickup.new()
			var d_line := ""
			for sp: Dictionary in SPECTRA:
				if sp.id == key:
					d_line = sp.diary
					break
			seed.setup_key(key, Vector3(0, 1.22, 0), "взять пробу — семя возражения", d_line)
			spec.add_child(seed)
		# карточка-описание на столе (лежит)
		var paper := Note3D.new()
		paper.setup("n_spectrum_" + key, Vector3(cx + 0.45, 1.03, nz + 0.1), 0.5)
		add_child(paper)
		paper.opened.connect(_on_note_opened)
		# ярлык на стене над столом
		Kit.plate(self, SPECTRA[i].name, Vector3(-12.85, 2.3, nz), 0.62, false, PI / 2)

func _on_note_opened(id: String) -> void:
	w.open_note(id)

# ============================================================ НИША МАТЕРИ ВОДЫ (запад, между a и b)
func _build_water_niche() -> void:
	# «аквариум без воды» перед западной стеной (z=-3.0, между пробами A и B)
	var nz := -3.0
	# затемнённый проём-рама на стене
	var black := Kit.M("black")
	Kit.mesh(self, black, "box", Vector3(0.16, 3.6, 2.6), Vector3(-12.94, 1.8, nz), Vector3.ZERO, false)
	# фигура за стеклом (между стеклом и стеной)
	var figure := Node3D.new()
	figure.position = Vector3(-12.62, 0, nz)
	add_child(figure)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.06, 0.05)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 1.5, 0.42)
	body.mesh = bm
	body.material_override = dark
	body.position = Vector3(0, 0.95, 0)
	figure.add_child(body)
	var hair := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.24; hm.bottom_radius = 0.09; hm.height = 0.8
	hair.mesh = hm
	hair.material_override = dark
	hair.position = Vector3(0, 2.0, -0.02)
	figure.add_child(hair)
	var skirt := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.2; sm.bottom_radius = 0.4; sm.height = 0.7
	skirt.mesh = sm
	skirt.material_override = dark
	skirt.position = Vector3(0, 0.35, 0)
	figure.add_child(skirt)
	# руки-«волосы в воде» — тонкие цилиндры в стороны
	for sgn in [-1.0, 1.0]:
		Kit.mesh(figure, dark, "cyl", Vector3(0.02, 0.9, 0), Vector3(sgn * 0.42, 1.15, 0.0), Vector3(0, 0, sgn * 1.2), false)
	# стекло перед фигурой, лицом в зал (+x)
	var glass := Kit.mat_alpha("glass_grime", 0.06)
	var gmi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.3, 3.2)
	gmi.mesh = q
	gmi.material_override = glass
	gmi.position = Vector3(-12.35, 1.6, nz)
	gmi.rotation.y = PI / 2
	add_child(gmi)
	# зелёное свечение фигуры
	var glow := OmniLight3D.new()
	glow.position = Vector3(-12.55, 1.4, nz)
	glow.light_color = Color(0.3, 1.0, 0.6)
	glow.light_energy = 1.1
	glow.omni_range = 4.2
	glow.shadow_enabled = false
	add_child(glow)
	var fl := LampFlicker.new()
	fl.light_node = glow
	add_child(fl)
	# записка на полу перед нишей (биография) — с ней связана бумага
	var paper := Note3D.new()
	paper.setup("n_agnessa", Vector3(-11.6, 0.03, nz + 0.6), -1.2)
	add_child(paper)
	paper.opened.connect(_on_note_opened)

# ============================================================ ЗЕРКАЛА И СПУСК
func _build_mirrors_and_descent() -> void:
	var m1 := MirrorDream.new()
	m1.setup("m1", Vector3(7.4, 0, 12.4), deg_to_rad(135))
	add_child(m1)
	var m2 := MirrorDream.new()
	m2.setup("m2", Vector3(-4.2, 0, 12.5), deg_to_rad(180))
	add_child(m2)
	var m3 := MirrorDream.new()
	m3.setup("m3", Vector3(12.5, 0, -7.2), deg_to_rad(-90))
	add_child(m3)
	# спуск в болото — восточная стена, в отсеке (7,7), севернее центра
	var door_pos := Vector3(12.95, 0, 4.5)
	var door := MuseumDoor.new()
	door.name = "DoorSwamp"
	add_child(door)
	door.position = door_pos
	door.rotation.y = -PI / 2
	door.build_door(1.9, 2.3)
	door.locked_flag = "specimen_taken_c"
	door.opens_with = "Заперто. На двери выцарапано: «три возражения — и вода откроет путь»."
	door.opened_flag = "swamp_door_open"
	Kit.door_frame(self, door_pos + Vector3(-0.2, 0, 0), 2.0, 2.4, 0.24, Kit.M("brass_dark"))
	Kit.plate(self, "ВНИЗ · К ВОДАМ", door_pos + Vector3(-0.4, 2.7, 0), 0.6)
	# за дверью: лестница вниз и гейт
	var descent := Node3D.new()
	descent.position = Vector3(13.6, 0, 4.5)
	add_child(descent)
	for i in range(8):
		var y := -0.42 * (i + 1)
		var zz: float = 0.0
		Kit.mesh(descent, Kit.M("stone"), "box", Vector3(2.2, 0.14, 0.8), Vector3(0, y - 0.06, zz + i * 0.75), Vector3.ZERO, true, "surf_stone")
	Kit.mesh(descent, Kit.M("black"), "box", Vector3(0.24, 3.6, 7.0), Vector3(-1.15, -1.8, 2.8), Vector3.ZERO, true)
	Kit.mesh(descent, Kit.M("black"), "box", Vector3(0.24, 3.6, 7.0), Vector3(1.15, -1.8, 2.8), Vector3.ZERO, true)
	# гейт в главу III
	var gate := ZoneGate.new()
	add_child(gate)
	gate.setup("c3_swamp", Vector3(13.6, -3.4, 7.2), Vector3(1.4, 2.4, 1.2), "default")

func on_seed_taken(_key: String) -> void:
	var n: int = int(Game.counters.get("seeds", 0))
	Game.counters["seeds"] = n
	if n >= 3 and not Game.has("water_full"):
		Game.setf("water_full")
		AudioMgr.play("bell", -4.0, 0.8)
		Game.diary_add("water",
			"Три возражения со мной. Вода за стеклом впервые подняла лицо — и я увидел, что у неё лицо Ханса. Нет. Оно уже изменилось — стало моим. «Ты понял? Мы все — переходные формы. Даже те, кто стоит наверху лестницы. Спускайся. Я покажу тебе, что делает вода, когда ей не мешают».")

func _process(_delta: float) -> void:
	# сердце и шёпот вблизи ниши воды, пока не выпит разговор
	if Game.has("water_full"):
		return
	var p: Player = w.player if w else null
	if p == null:
		return
	var d: float = p.global_position.distance_to(Vector3(-13.25, 0, -3.0))
	if d < 10.0 and Game.counters.get("seeds", 0) > 0:
		var inten: float = clampf(1.0 - d / 10.0, 0.0, 1.0)
		AudioMgr.play_heart(inten)
		AudioMgr.set_tension(inten * 0.4)
