extends Node3D
## Строитель музея ИЭТ — Глава 1 «ЭКСПОЗИЦИЯ» [lev-03]
## Вся геометрия процедурная: ротонда-октагон, крылья, кабинет хранителя.

const WALL_H := 4.2
const WALL_T := 0.35

var mats := {}
var spots: Array[Vector3] = []
var spawn := Vector3(0, 0.3, -5.2)
var giraffe_spawn := Vector3(-23.0, 0.2, 4.0)
var checkpoints := {
	"spawn": Vector3(0, 0.3, -5.2),
	"west": Vector3(-14.0, 0.3, 0.0),
	"east": Vector3(14.0, 0.3, 0.0),
	"cabinet": Vector3(12.1, 0.3, 2.6),
	"origin": Vector3(0, 0.3, 5.0),
}
var origin_door: Node3D
var cabinet_door: Node3D
var flickers: Array[OmniLight3D] = []

func _ready() -> void:
	_make_materials()
	build()

# ================================================================ материалы
func _make_materials() -> void:
	mats["parquet"] = _tex_mat("res://assets/textures/parquet.png", 1.0)
	mats["marble"] = _tex_mat("res://assets/textures/marble.png", 0.55)
	mats["wall"] = _tex_mat("res://assets/textures/wall_twotone.png", 1.0)
	mats["ceiling"] = _tex_mat("res://assets/textures/ceiling.png", 1.0)
	mats["linoleum"] = _tex_mat("res://assets/textures/linoleum.png", 1.0)
	mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", 1.0)
	mats["wood_door"] = _tex_mat("res://assets/textures/door_wood.png", 0.9)
	mats["velvet"] = _tex_mat("res://assets/textures/velvet.png", 1.0)
	mats["fur"] = _tex_mat("res://assets/textures/fur_dark.png", 1.0)
	mats["skin"] = _tex_mat("res://assets/textures/giraffe_skin.png", 1.0)
	mats["bone"] = _tex_mat("res://assets/textures/bone.png", 0.9)
	mats["metal"] = _plain(Color(0.16, 0.17, 0.18), 0.45)
	mats["brass"] = _plain(Color(0.42, 0.33, 0.16), 0.35)
	mats["glass"] = _glass()
	mats["lamp"] = _emis(Color(1.0, 0.85, 0.6), 1.4)
	mats["redlamp"] = _emis(Color(1.0, 0.12, 0.07), 1.2)
	mats["moon"] = _emis(Color(0.55, 0.65, 1.0), 0.8)

func _tex_mat(path: String, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = rough
	m.metallic = 0.0
	return m

func _plain(c: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _emis(c: Color, e := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.albedo_color = Color(0.1, 0.1, 0.1)
	return m

func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.82, 0.8, 0.10)
	m.roughness = 0.08
	m.metallic = 0.1
	return m

# ================================================================ хелперы
func solid_box(pos: Vector3, size: Vector3, mat: Material, uv := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if uv != Vector3.ONE and mat is StandardMaterial3D:
		var sm := (mat as StandardMaterial3D)
		sm.uv1_scale = uv
	mi.position = pos
	add_child(mi)
	_collide(mi, size)
	return mi

func _collide(mi: MeshInstance3D, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	mi.add_child(sb)

func ghost_box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	## без коллизии (декор)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func wall_x(z: float, x0: float, x1: float, mat: Material = null) -> void:
	## стена вдоль оси X на глубине z
	mat = mat if mat else mats["wall"]
	var len := absf(x1 - x0)
	var cx := (x0 + x1) / 2.0
	var w := solid_box(Vector3(cx, WALL_H / 2.0, z), Vector3(len, WALL_H, WALL_T), mat)
	_uv(w, Vector3(len / 3.0, 1.0, 1.0))

func wall_z(x: float, z0: float, z1: float, mat: Material = null) -> void:
	mat = mat if mat else mats["wall"]
	var len := absf(z1 - z0)
	var cz := (z0 + z1) / 2.0
	var w := solid_box(Vector3(x, WALL_H / 2.0, cz), Vector3(WALL_T, WALL_H, len), mat)
	_uv(w, Vector3(len / 3.0, 1.0, 1.0))

func _uv(mi: MeshInstance3D, uv: Vector3) -> void:
	if mi.material_override is StandardMaterial3D:
		(mi.material_override as StandardMaterial3D).uv1_scale = uv

func floor_box(c: Vector2, size: Vector2, mat: Material, y := -0.1) -> MeshInstance3D:
	var mi := solid_box(Vector3(c.x, y, c.y), Vector3(size.x, 0.2, size.y), mat, Vector3(size.x / 3.0, size.y / 3.0, 1.0))
	return mi

func ceiling_box(c: Vector2, size: Vector2, h: float, mat: Material = null) -> void:
	mat = mat if mat else mats["ceiling"]
	solid_box(Vector3(c.x, h, c.y), Vector3(size.x, 0.25, size.y), mat, Vector3(size.x / 3.0, size.y / 3.0, 1.0))

func omni(pos: Vector3, color: Color, energy: float, flicker := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 11.0
	l.shadow_enabled = false
	add_child(l)
	if flicker:
		flickers.append(l)
	return l

func bulb(pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07; sm.height = 0.14
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

# ================================================================ сборка
func build() -> void:
	_environment()
	_rotunda()
	_east_corridor()
	_east_hall()
	_west_corridor()
	_west_hall()
	_cabinet()
	_vestibule()

func _environment() -> void:
	var we := WorldEnvironment.new()
	we.add_to_group("env")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.013, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.055, 0.07)
	env.ambient_light_energy = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.028, 0.03, 0.038)
	env.fog_density = 0.032
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_hdr_threshold = 0.9
	we.environment = env
	add_child(we)

func _rotunda() -> void:
	# пол — мраморный круг
	var fl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 8.8; cm.bottom_radius = 8.8; cm.height = 0.24
	cm.radial_segments = 24
	fl.mesh = cm
	fl.material_override = mats["marble"]
	fl.position = Vector3(0, -0.12, 0)
	add_child(fl)
	_collide(fl, Vector3(15.0, 0.24, 15.0))
	# стены октагона
	wall_x(8.0, -3.0, -1.25); wall_x(8.0, 1.25, 3.0)            # N (проём — Зал Происхождения)
	wall_x(-8.0, -3.0, 3.0)                                      # S — вход (наглухо)
	wall_z(8.0, -3.0, -1.55); wall_z(8.0, 1.55, 3.0)            # E → восточный коридор
	wall_z(-8.0, -3.0, -1.55); wall_z(-8.0, 1.55, 3.0)          # W → западный коридор
	# диагонали
	_diag(Vector3(3, 0, 8), Vector3(8, 0, 3))
	_diag(Vector3(8, 0, -3), Vector3(3, 0, -8))
	_diag(Vector3(-3, 0, -8), Vector3(-8, 0, -3))
	_diag(Vector3(-8, 0, 3), Vector3(-3, 0, 8))
	# купол-потолок (восьмигранный)
	var dome := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 8.9; dm.bottom_radius = 8.9; dm.height = 0.4; dm.radial_segments = 8
	dome.mesh = dm
	dome.material_override = mats["ceiling"]
	dome.position = Vector3(0, WALL_H + 0.2, 0)
	add_child(dome)
	# окulus: лунный колодец
	var oculus := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 2.2)
	oculus.mesh = pm
	oculus.material_override = mats["moon"]
	oculus.rotation.x = -PI / 2
	oculus.position = Vector3(0, WALL_H + 0.02, 0)
	add_child(oculus)
	var moon := SpotLight3D.new()
	moon.position = Vector3(0, WALL_H + 1.2, 0)
	moon.rotation.x = -PI / 2         # вниз
	moon.light_color = Color(0.6, 0.68, 1.0)
	moon.light_energy = 2.4
	moon.spot_range = 16.0
	moon.spot_angle = 34.0
	moon.shadow_enabled = true
	add_child(moon)
	# фейковый «объём» лунного света
	_shaft(Vector3(0, WALL_H / 2.0, 0), 1.0, 4.2, WALL_H, Color(0.5, 0.6, 1.0, 0.02))
	# тёплые лампы по углам
	omni(Vector3(-5.5, 3.9, 5.5), Color(1.0, 0.8, 0.55), 0.3)
	omni(Vector3(5.5, 3.9, -5.5), Color(1.0, 0.8, 0.55), 0.3)
	bulb(Vector3(-5.5, 4.0, 5.5), mats["lamp"]); bulb(Vector3(5.5, 4.0, -5.5), mats["lamp"])
	# центральная витрина «Образец №0» — ПУСТАЯ
	add_exhibit(Vector3(0, 0, 0), 0.0, "empty_zero", "label_zero", 1.35)
	# угловые чучела
	add_exhibit(Vector3(-5.4, 0, 5.0), face_to_center(Vector3(-5.4, 0, 5.0)), "wolf", "label_wolf")
	add_exhibit(Vector3(5.4, 0, 5.0), face_to_center(Vector3(5.4, 0, 5.0)), "owl", "label_owl")
	add_exhibit(Vector3(5.4, 0, -5.0), face_to_center(Vector3(5.4, 0, -5.0)), "fish", "label_fish")
	add_exhibit(Vector3(-5.4, 0, -5.0), face_to_center(Vector3(-5.4, 0, -5.0)), "mole", "label_mole")
	# скамьи
	for bpos in [Vector3(-2.6, 0.25, -3.4), Vector3(2.6, 0.25, -3.4)]:
		ghost_box(bpos, Vector3(1.8, 0.5, 0.55), mats["velvet"])
	# главный вход (опечатан) + табличка Линника
	ghost_box(Vector3(0, 1.6, -7.7), Vector3(2.6, 3.2, 0.18), mats["wood_door"])
	ghost_box(Vector3(0, 3.3, -7.62), Vector3(3.0, 0.35, 0.3), mats["brass"])
	_note(Vector3(1.9, 1.5, -7.5), 0.0, "note_linnik", "Табличка у входа", "«Deus creavit, Linnaeus disposuit».\n\nБог создал — Линней расставил.\n\nНиже, другой рукой, коряво:\n«Расставил. Переставил. Переставляет.»")
	# дверь Зала Происхождения
	origin_door = solid_box(Vector3(0, 1.55, 8.0), Vector3(2.5, 3.1, 0.22), mats["metal"], Vector3.ONE)
	origin_door.add_to_group("door_origin")
	_interactable(Vector3(0, 1.4, 7.55), "door_origin", "[E] Дверь Зала Происхождения — три гнезда под печати")
	# перекладина над проёмом
	solid_box(Vector3(0, 3.7, 8.0), Vector3(2.7, 1.0, WALL_T), mats["wall"])
	# перекладины над входами в коридоры
	for hx in [-8.0, 8.0]:
		solid_box(Vector3(hx, 3.7, 0), Vector3(WALL_T, 1.0, 3.2), mats["wall"])
	spots.append_array([Vector3(-5.4, 0, 5.0), Vector3(5.4, 0, 5.0), Vector3(5.4, 0, -5.0), Vector3(-5.4, 0, -5.0), Vector3(0, 0, 6.2)])

func face_to_center(pos: Vector3) -> float:
	return atan2(-pos.x, -pos.z)

func _diag(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2.0
	var len := a.distance_to(b)
	var w := solid_box(Vector3(mid.x, WALL_H / 2.0, mid.z), Vector3(len, WALL_H, WALL_T), mats["wall"])
	w.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	_uv(w, Vector3(len / 3.0, 1.0, 1.0))

func _shaft(pos: Vector3, top_r: float, bot_r: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r; cm.bottom_radius = bot_r; cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	add_child(mi)

# ---------------------------------------------------------------- восток
func _east_corridor() -> void:
	floor_box(Vector2(14.0, 0.0), Vector2(12.0, 3.2), mats["parquet"])
	wall_x(1.6, 8.0, 11.4); wall_x(1.6, 12.8, 20.0)    # север коридора (проём в кабинет)
	ghost_box(Vector3(12.1, 2.85, 1.6), Vector3(1.6, 1.4, WALL_T), mats["wall"])
	wall_x(-1.6, 8.0, 20.0)                            # юг коридора
	ceiling_box(Vector2(14.0, 0.0), Vector2(12.0, 3.2), 3.2)
	omni(Vector3(14, 3.0, 0), Color(1.0, 0.8, 0.55), 0.34, true)
	bulb(Vector3(14, 3.05, 0), mats["lamp"])
	add_exhibit(Vector3(14, 0, -1.1), PI, "fish", "label_fish", 0.9)
	spots.append(Vector3(14, 0, 1.0))

func _east_hall() -> void:
	floor_box(Vector2(26.0, 0.0), Vector2(12.0, 12.0), mats["parquet"])
	wall_z(20.0, -6.0, -1.55); wall_z(20.0, 1.55, 6.0)
	wall_z(32.0, -6.0, 6.0)
	wall_x(6.0, 20.0, 32.0)
	wall_x(-6.0, 20.0, 32.0)
	ceiling_box(Vector2(26.0, 0.0), Vector2(12.0, 12.0), 3.6)
	solid_box(Vector3(20.0, 3.9, 0), Vector3(WALL_T, 0.7, 3.2), mats["wall"])
	omni(Vector3(23, 3.4, 0), Color(1.0, 0.8, 0.55), 0.4)
	omni(Vector3(29, 3.4, 0), Color(1.0, 0.8, 0.55), 0.28, true)
	bulb(Vector3(23, 3.45, 0), mats["lamp"]); bulb(Vector3(29, 3.45, 0), mats["lamp"])
	# красная аварийная над столом смотрителя
	omni(Vector3(27, 3.2, 3.0), Color(1.0, 0.12, 0.07), 0.55)
	bulb(Vector3(27, 3.25, 3.0), mats["redlamp"])
	# филины вдоль южной стены
	for x in [21.5, 24.0, 26.5, 29.0]:
		add_exhibit(Vector3(x, 0, -4.9), PI, "owl", "label_owl")
	spots.append(Vector3(24.0, 0, -3.2))
	# рабочий стол смотрителя: ключ + дневник Ж.
	_desk(Vector3(27, 0, 3.6), PI)
	_key(Vector3(27.4, 1.02, 3.2))
	_note(Vector3(26.5, 1.06, 3.8), PI, "note_zh", "Дневник лаборанта Ж.", "«Сегодня снова не хватило. Корм подвесили выше.\nЯ просто потянулась. Стало легче.\nЗавтра потянусь выше.\n\n(почерк тянется вниз по странице, буквы вытягиваются)\n\nвыше. выше. выше. выше.»")
	# печать №2 на витрине
	_seal(Vector3(22.5, 0, 3.6), "seal_east")

# ---------------------------------------------------------------- запад
func _west_corridor() -> void:
	floor_box(Vector2(-14.0, 0.0), Vector2(12.0, 3.2), mats["parquet"])
	wall_x(1.6, -20.0, -8.0)
	wall_x(-1.6, -20.0, -8.0)
	ceiling_box(Vector2(-14.0, 0.0), Vector2(12.0, 3.2), 3.2)
	omni(Vector3(-14, 3.0, 0), Color(1.0, 0.8, 0.55), 0.34, true)
	bulb(Vector3(-14, 3.05, 0), mats["lamp"])
	add_exhibit(Vector3(-14, 0, -1.1), PI, "mole", "label_mole", 0.9)

func _west_hall() -> void:
	floor_box(Vector2(-26.0, 0.0), Vector2(12.0, 12.0), mats["parquet"])
	wall_z(-20.0, -6.0, -1.55); wall_z(-20.0, 1.55, 6.0)
	wall_z(-32.0, -6.0, 6.0)
	wall_x(6.0, -32.0, -20.0)
	wall_x(-6.0, -32.0, -20.0)
	ceiling_box(Vector2(-26.0, 0.0), Vector2(12.0, 12.0), 3.6)
	solid_box(Vector3(-20.0, 3.9, 0), Vector3(WALL_T, 0.7, 3.2), mats["wall"])
	omni(Vector3(-23, 3.4, 0), Color(1.0, 0.8, 0.55), 0.36, true)
	omni(Vector3(-29, 3.4, 0), Color(1.0, 0.8, 0.55), 0.26)
	bulb(Vector3(-23, 3.45, 0), mats["lamp"]); bulb(Vector3(-29, 3.45, 0), mats["lamp"])
	# волки вдоль южной стены
	for x in [-21.5, -24.0, -26.5]:
		add_exhibit(Vector3(x, 0, -4.9), PI, "wolf", "label_wolf")
	# чучела жираф среди экспозиции (мимо них ходит ЖИРАФА)
	add_exhibit(Vector3(-23.5, 0, 4.4), 0.0, "giraffe_fake", "label_giraffe", 1.1)
	add_exhibit(Vector3(-29.0, 0, 4.0), 0.0, "giraffe_fake", "label_giraffe", 1.1)
	spots.append_array([Vector3(-23.5, 0, 2.6), Vector3(-29.0, 0, 2.2)])
	# алтарь Стремления
	_altar(Vector3(-30.8, 0, 0), -PI / 2)
	_note(Vector3(-31.7, 1.5, 0), -PI / 2, "note_order", "Приказ №0 (обрывок)", "«…считать Образец №0 недостающим звеном.\nДо определения — не кормить, не пугать, не называть по имени.\nПечати происхождения — по одной в крыло.\nОтветственный: ____»\n\n(ниже, красным, чужим почерком: «ответственный уже стоит в витрине»)")
	# печать №1
	_seal(Vector3(-26.0, 0, 3.4), "seal_west")

# ---------------------------------------------------------------- кабинет
func _cabinet() -> void:
	floor_box(Vector2(13.0, 4.1), Vector2(6.0, 5.0), mats["linoleum"])
	wall_x(6.6, 10.0, 16.0)
	wall_z(10.0, 1.6, 6.6)
	wall_z(16.0, 1.6, 6.6)
	ceiling_box(Vector2(13.0, 4.1), Vector2(6.0, 5.0), 3.0)
	omni(Vector3(13, 2.6, 4.8), Color(1.0, 0.75, 0.5), 0.4)
	bulb(Vector3(13, 2.65, 4.8), mats["lamp"])
	# дверь с замком (заперта; ключ — в восточном крыле)
	cabinet_door = solid_box(Vector3(12.1, 1.15, 1.6), Vector3(1.4, 2.3, 0.16), mats["wood_door"])
	cabinet_door.add_to_group("door_cabinet")
	_interactable(Vector3(12.1, 1.2, 1.25), "door_key", "[E] Кабинет хранителя — заперто")
	# стол: журнал смены
	_desk(Vector3(13.5, 0, 5.6), PI)
	_note(Vector3(13.5, 1.06, 5.6), PI, "note_journal", "Журнал смены (последняя запись)", "«Смена 3/3. Пересчёт образцов по форме 6.\nВсего образцов: 214.\nВсего было утром: 213.\nЯ не добавлял.\n\nХранителю на смену 1: если вы это читаете — не считайте.\nОни узнают, что их считают, и приходят пополнить список.\n\n(другой рукой) Образец 214 стоит у западной витрины. Он вас видит.»")
	# печать №3 на полке
	_seal(Vector3(15.3, 0, 3.4), "seal_cabinet", 1.0)
	# панель громкой связи
	_interactable(Vector3(10.35, 1.5, 4.0), "pa_panel", "[E] Панель громкой связи")

# ---------------------------------------------------------------- вестибюль
func _vestibule() -> void:
	## тёмный тамбур за дверью Зала Происхождения
	floor_box(Vector2(0, 10.5), Vector2(4.4, 5.0), mats["concrete"])
	wall_x(13.0, -2.2, 2.2)
	wall_z(2.2, 8.0, 13.0)
	wall_z(-2.2, 8.0, 13.0)
	ceiling_box(Vector2(0, 10.5), Vector2(4.4, 5.0), 3.2)
	_interactable(Vector3(0, 1.0, 10.0), "end", "[E] Спуститься")

# ================================================================ витрины
func add_exhibit(pos: Vector3, rot_y: float, variant: String, label_key: String, scale_v := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.scale = Vector3.ONE * scale_v
	add_child(root)
	# пьедестал
	var ped := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.0, 1.0, 1.0)
	ped.mesh = pm
	ped.material_override = mats["velvet"]
	ped.position = Vector3(0, 0.5, 0)
	root.add_child(ped)
	_collide(ped, Vector3(1.0, 1.0, 1.0))
	# стеклянный колпак
	var case_m := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.95, 1.3, 0.95)
	case_m.mesh = cm
	case_m.material_override = mats["glass"]
	case_m.position = Vector3(0, 1.65, 0)
	root.add_child(case_m)
	# экспонат
	_specimen(root, variant)
	# этикетка
	_label(root, label_key)
	return root

func _specimen(root: Node3D, variant: String) -> void:
	match variant:
		"wolf":
			var body := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.26; sm.height = 0.52
			body.mesh = sm; body.material_override = mats["fur"]
			body.scale = Vector3(1.5, 0.8, 1.0); body.position = Vector3(0, 1.25, 0)
			root.add_child(body)
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new(); hb.size = Vector3(0.16, 0.14, 0.3)
			head.mesh = hb; head.material_override = mats["fur"]
			head.position = Vector3(0, 1.32, -0.36)
			root.add_child(head)
		"owl":
			var b := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.32
			b.mesh = sm; b.material_override = mats["fur"]
			b.position = Vector3(0, 1.3, 0)
			root.add_child(b)
			var beak := MeshInstance3D.new()
			var pr := PrismMesh.new(); pr.size = Vector3(0.07, 0.14, 0.07)
			beak.mesh = pr; beak.material_override = mats["brass"]
			beak.rotation.x = -PI / 2; beak.position = Vector3(0, 1.28, -0.2)
			root.add_child(beak)
			for ex in [-0.06, 0.06]:
				var eye := MeshInstance3D.new()
				var em := SphereMesh.new(); em.radius = 0.025; em.height = 0.05
				eye.mesh = em; eye.material_override = mats["moon"]
				eye.position = Vector3(ex, 1.34, -0.13)
				root.add_child(eye)
		"fish":
			var f := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.18; sm.height = 0.36
			f.mesh = sm; f.material_override = mats["metal"]
			f.scale = Vector3(0.5, 0.9, 1.4); f.position = Vector3(0, 1.25, 0)
			root.add_child(f)
		"mole":
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.14; sm.height = 0.28
			m.mesh = sm; m.material_override = mats["fur"]
			m.scale = Vector3(1.0, 0.8, 1.4); m.position = Vector3(0, 1.2, 0)
			root.add_child(m)
		"giraffe_fake":
			var neck := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05; cm.bottom_radius = 0.09; cm.height = 1.9
			neck.mesh = cm; neck.material_override = mats["skin"]
			neck.position = Vector3(0, 2.2, 0)
			root.add_child(neck)
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new(); hb.size = Vector3(0.12, 0.15, 0.26)
			head.mesh = hb; head.material_override = mats["skin"]
			head.position = Vector3(0, 3.22, -0.08)
			root.add_child(head)
		"empty_zero":
			# пустая витрина — только силуэт на дне (зеркальная тьма)
			var silhouette := MeshInstance3D.new()
			var cap := CapsuleMesh.new(); cap.radius = 0.22; cap.height = 1.0
			silhouette.mesh = cap
			silhouette.material_override = _plain(Color(0.02, 0.02, 0.03), 1.0)
			silhouette.position = Vector3(0, 1.1, 0)
			root.add_child(silhouette)
			_label(root, "label_missing")

func _label(root: Node3D, key: String) -> void:
	var mi := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = Vector2(0.52, 0.325)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	var tex := load("res://assets/textures/labels/%s.png" % key)
	if tex: m.albedo_texture = tex
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.5, 0.47, 0.4)
	m.emission_energy_multiplier = 0.12
	mi.material_override = m
	mi.position = Vector3(0, 1.08, -0.52)
	mi.rotation.y = PI
	root.add_child(mi)

# ================================================================ мебель/интерактив
func _desk(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	solid_box_local(root, Vector3(0, 0.78, 0), Vector3(1.8, 0.08, 0.9), mats["wood_door"])
	solid_box_local(root, Vector3(0, 0.4, 0.2), Vector3(1.7, 0.6, 0.8), mats["wood_door"])

func solid_box_local(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	mi.add_child(sb)
	return mi

func _altar(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	solid_box_local(root, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 0.8), mats["concrete"])
	# свечи-фитили
	for cx in [-0.4, 0.0, 0.4]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.035; cm.height = 0.3
		c.mesh = cm
		c.material_override = _emis(Color(1.0, 0.55, 0.2), 2.2)
		c.position = Vector3(cx, 1.25, 0)
		root.add_child(c)
	omni(pos + Vector3(0, 1.6, 0), Color(1.0, 0.5, 0.2), 0.7)
	var a = _interactable(pos + Vector3(0, 1.0, -0.9).rotated(Vector3.UP, rot_y), "altar", "[E] Алтарь Стремления — оно что-то предлагает")
	a.set_meta("altar_id", "troglodyte")

func _interactable(pos: Vector3, kind: String, prompt: String, note_title := "", note_text := "") -> Area3D:
	var a = Area3D.new()
	a.position = pos
	a.set_script(load("res://scripts/interactables.gd"))
	add_child(a)
	a.kind = kind
	a.prompt_text = prompt
	a.note_title = note_title
	a.note_text = note_text
	return a

func _note(pos: Vector3, rot_y: float, id: String, title: String, text: String) -> void:
	var a := _interactable(pos, "note", "[E] Прочесть: " + title, title, text)
	a.set_meta("note_id", id)

func _seal(pos: Vector3, id: String, y := 1.05) -> void:
	# печать на подставке
	solid_box(Vector3(pos.x, y / 2.0, pos.z), Vector3(0.6, y, 0.6), mats["velvet"])
	var seal_mesh := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.12; sm.bottom_radius = 0.14; sm.height = 0.06
	seal_mesh.mesh = sm
	seal_mesh.material_override = mats["brass"]
	seal_mesh.position = Vector3(pos.x, y + 0.03, pos.z)
	add_child(seal_mesh)
	var a := _interactable(Vector3(pos.x, y + 0.1, pos.z), "seal", "[E] Печать происхождения")
	a.set_meta("seal_id", id)

func _key(pos: Vector3) -> void:
	var k := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.16, 0.03)
	k.mesh = bm
	k.material_override = mats["brass"]
	k.position = pos
	add_child(k)
	var a := _interactable(pos, "key", "[E] Ключ хранителя")
