class_name Kit
## SCALA NATURAE — конструктор мира. Материалы из процедурных текстур + примитивы.
## Статический инструментарий: без инстансов, только фабрики.

const TEX_DIR := "res://assets/textures/"

static var _tex := {}
static var _mat := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := TEX_DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]

static func texn(name: String) -> Texture2D:  # normal map
	return tex(name + "_n")

static func mat(key: String, albedo := Color(1, 1, 1), rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var id := "%s|%s|%.2f|%.2f" % [key, albedo.to_html(), rough, metal]
	if _mat.has(id):
		return _mat[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	var t: Texture2D = tex(key)
	if t:
		m.albedo_texture = t
		var tn: Texture2D = texn(key)
		if tn:
			m.normal_enabled = true
			m.normal_texture = tn
	_mat[id] = m
	return m

static func mat_emit(key: String, energy := 0.6, color := Color(1, 1, 1)) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(key).duplicate()
	m.emission_enabled = true
	m.emission_energy_multiplier = energy
	m.emission = color
	return m

static func mat_alpha(key: String, rough := 0.6) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(key, Color(1, 1, 1), rough).duplicate()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ---------- готовые материалы (ярлыки) ----------
static func M(key: String) -> StandardMaterial3D:
	match key:
		"parquet": return mat("parquet_dark", Color(0.9, 0.86, 0.8), 0.62, 0.0)
		"marble": return mat("marble_white", Color(0.95, 0.95, 0.93), 0.22, 0.05)
		"brass": return mat("brass", Color(1, 0.95, 0.85), 0.38, 0.92)
		"brass_dark": return mat("brass", Color(0.55, 0.48, 0.38), 0.45, 0.85)
		"velvet": return mat("velvet_red", Color(1.4, 0.85, 0.85), 0.95, 0.0)
		"plaster": return mat("plaster", Color(0.85, 0.84, 0.8), 0.9, 0.0)
		"wallpaper": return mat("wallpaper_green", Color(0.9, 1.05, 0.95), 0.8, 0.0)
		"mud": return mat("mud_swamp", Color(0.8, 0.9, 0.8), 0.96, 0.0)
		"stone": return mat("stone_moss", Color(0.9, 0.92, 0.9), 0.9, 0.0)
		"peat": return mat("peat_root", Color(0.8, 0.7, 0.55), 0.85, 0.0)
		"black": return mat("", Color(0.012, 0.013, 0.015), 0.92, 0.0)
		"glass": return mat_alpha("glass_grime", 0.08)
		"paper": return mat("paper", Color(1, 1, 1), 0.8, 0.0)
	return mat("", Color.WHITE, 0.8, 0.0)

# ---------- геометрия ----------
static func mesh(parent: Node3D, m: Material, kind: String = "box", size := Vector3.ONE, \
		pos := Vector3.ZERO, rot := Vector3.ZERO, collide := true, group := "") -> MeshInstance3D:
	if m == null:
		push_error("KIT: null material kind=" + kind)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(1, 0, 1)
		m = fm
	var mi := MeshInstance3D.new()
	parent.add_child(mi)
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x; cm.bottom_radius = size.x
			cm.height = size.y
			cm.radial_segments = 16
			mi.mesh = cm
		"cone":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.001; cm.bottom_radius = size.x
			cm.height = size.y
			cm.radial_segments = 14
			mi.mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x; sm.height = size.y
			mi.mesh = sm
		"quad":
			var qm := QuadMesh.new()
			qm.size = Vector2(size.x, size.y)
			mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if group != "":
		mi.add_to_group(group)
	if collide:
		body(mi, kind, size)
	return mi

## физическое тело под меш: StaticBody3D + Box/Cylinder shape
static func body(under_mesh: MeshInstance3D, kind: String, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	under_mesh.add_child(sb)
	var cs := CollisionShape3D.new()
	sb.add_child(cs)
	var sh: Shape3D
	if kind == "cyl" or kind == "cone":
		var c := CylinderShape3D.new()
		c.radius = size.x; c.height = size.y
		sh = c
	elif kind == "sphere":
		var s := SphereShape3D.new()
		s.radius = size.x
		sh = s
	else:
		var b := BoxShape3D.new()
		b.size = size
		sh = b
	cs.shape = sh
	cs.position = Vector3.ZERO
	return sb

# ---------- архитектурные детали ----------
## комната: стены из сегментов с проёмами. openings: {0:[[t0,t1]...], 1:..., 2:..., 3:...} (доли стены)
static func room(parent: Node3D, cx: float, cz: float, sx: float, sz: float, h: float, \
		mat_wall: Material, mat_floor: Material, mat_ceil: Material, \
		openings := {}, floor_group := "surf_wood", opts := {}) -> void:
	var floor_y: float = opts.get("floor_y", 0.0)
	mesh(parent, mat_floor, "box", Vector3(sx, 0.12, sz), Vector3(cx, floor_y - 0.06, cz), Vector3.ZERO, true, floor_group)
	mesh(parent, mat_ceil, "box", Vector3(sx, 0.12, sz), Vector3(cx, h + 0.06, cz))
	_wall(parent, mat_wall, Vector3(cx - sx / 2, 0, cz), Vector2(sx, sz), h, 0.24, 0, openings.get(0, []), floor_y)
	_wall(parent, mat_wall, Vector3(cx + sx / 2, 0, cz), Vector2(sx, sz), h, 0.24, 0, openings.get(1, []), floor_y)
	_wall(parent, mat_wall, Vector3(cx, 0, cz - sz / 2), Vector2(sx, sz), h, 0.24, 1, openings.get(2, []), floor_y)
	_wall(parent, mat_wall, Vector3(cx, 0, cz + sz / 2), Vector2(sx, sz), h, 0.24, 1, openings.get(3, []), floor_y)

static func _wall(parent: Node3D, m: Material, center: Vector3, room_size: Vector2, h: float, \
		thick: float, axis: int, gaps: Array, floor_y: float) -> void:
	var len := room_size.y if axis == 0 else room_size.x   # длина вдоль стены
	var half := len / 2.0
	var spans := []
	if gaps.is_empty():
		spans = [[-half, half]]
	else:
		var cuts: Array = []
		for g in gaps:
			cuts.append([-half + g[0] * len, -half + g[1] * len])
		cuts.sort_custom(func(a, b): return a[0] < b[0])
		var cur := -half
		for c in cuts:
			if c[0] > cur + 0.02:
				spans.append([cur, c[0]])
			cur = maxf(cur, c[1])
		if cur < half - 0.02:
			spans.append([cur, half])
	var wall_h := h + 0.1
	for s in spans:
		var mid: float = (s[0] + s[1]) / 2.0
		var l: float = s[1] - s[0]
		var p := Vector3(center.x, wall_h / 2 + floor_y, center.z)
		if axis == 0:
			p.z += mid
			mesh(parent, m, "box", Vector3(thick, wall_h, l), p, Vector3.ZERO, true)
		else:
			p.x += mid
			mesh(parent, m, "box", Vector3(l, wall_h, thick), p, Vector3.ZERO, true)

## дверной косяк + наличники
static func door_frame(parent: Node3D, pos: Vector3, w: float, h: float, thick := 0.22, mat: Material = null) -> void:
	var m: Material = mat if mat != null else M("black")
	var t := 0.14
	var top := 0.18
	mesh(parent, m, "box", Vector3(w + t * 2, top, thick * 1.6), pos + Vector3(0, h + top / 2 - 0.05, 0), Vector3.ZERO, false)
	mesh(parent, m, "box", Vector3(t, h, thick * 1.6), pos + Vector3(-w / 2 - t / 2, h / 2, 0), Vector3.ZERO, true)
	mesh(parent, m, "box", Vector3(t, h, thick * 1.6), pos + Vector3(w / 2 + t / 2, h / 2, 0), Vector3.ZERO, true)

## пилястр-колонна: база/ствол/капитель
static func column(parent: Node3D, pos: Vector3, h: float, rad := 0.22, marble: bool = true) -> void:
	var st := M("marble") if marble else M("plaster")
	var dark := M("brass_dark")
	mesh(parent, dark, "box", Vector3(rad * 2.4, 0.14, rad * 2.4), pos + Vector3(0, 0.07, 0))
	mesh(parent, st, "cyl", Vector3(rad, h - 0.5, 0), pos + Vector3(0, h / 2 + 0.07, 0))
	mesh(parent, dark, "box", Vector3(rad * 2.6, 0.12, rad * 2.6), pos + Vector3(0, h - 0.13, 0))
	mesh(parent, dark, "box", Vector3(rad * 1.9, 0.2, rad * 1.9), pos + Vector3(0, h + 0.02, 0))

## пьедестал экспоната
static func pedestal(parent: Node3D, pos: Vector3, w: float, h: float, d: float, label: String = "", marble := false) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var body: Material = M("marble") if marble else mat("parquet_dark", Color(0.55, 0.5, 0.42), 0.7)
	var dark := M("brass_dark")
	mesh(holder, body, "box", Vector3(w + 0.06, 0.1, d + 0.06), Vector3(0, 0.05, 0))
	mesh(holder, body, "box", Vector3(w, h, d), Vector3(0, h / 2 + 0.1, 0))
	mesh(holder, body, "box", Vector3(w + 0.12, 0.14, d + 0.12), Vector3(0, h + 0.17, 0))
	mesh(holder, dark, "box", Vector3(w * 1.25, 0.04, d * 1.25), Vector3(0, -0.02, 0))
	if label != "":
		plate(holder, label, Vector3(0, h * 0.55, d / 2 + 0.011), 0.5)
	return holder

## латунная табличка (текст рендерится в SubViewport, кэш по тексту)
static var _plate_host: Node = null
static var _plate_cache := {}
static var _label_font: Font = null
static func label_font() -> Font:
	if _label_font == null:
		_label_font = load("res://assets/fonts/DejaVuSerif.ttf") if ResourceLoader.exists("res://assets/fonts/DejaVuSerif.ttf") else ThemeDB.fallback_font
	return _label_font
static func plate(parent: Node3D, text: String, pos: Vector3, w := 0.5, emissive := true, rot_y := 0.0) -> MeshInstance3D:
	var vp: SubViewport = _plate_cache.get(text)
	if vp == null:
		if _label_font == null:
			_label_font = label_font()
		vp = SubViewport.new()
		vp.size = Vector2i(512, 128)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new()
		bg.color = Color(0.63, 0.56, 0.44)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.add_child(bg)
		var l := Label.new()
		l.text = text
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", _label_font)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.16, 0.13, 0.10))
		vp.add_child(l)
		_plate_cache[text] = vp
	if _plate_host == null:
		_plate_host = Node.new()
		_plate_host.name = "PlateHost"
		var root := Engine.get_main_loop() as SceneTree
		if root and root.current_scene:
			root.current_scene.add_child(_plate_host)
		elif root:
			root.root.add_child.call_deferred(_plate_host)
	if _plate_host.get_parent() == null and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree.current_scene:
			tree.current_scene.add_child.call_deferred(_plate_host)
	if vp.get_parent() == null:
		_plate_host.add_child(vp)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, w * 0.25)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.roughness = 0.45
	m.metallic = 0.85
	m.albedo_texture = vp.get_texture()
	if emissive:
		m.emission_enabled = true
		m.emission_energy_multiplier = 0.55
		m.emission_texture = vp.get_texture()
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

## картина/гравюра в раме (texture — Texture2D или путь)
static func picture(parent: Node3D, tex_src, pos: Vector3, w: float, h: float, rot_y := 0.0, frame := true) -> void:
	var t: Texture2D = tex_src if tex_src is Texture2D else (load(tex_src) if typeof(tex_src) == TYPE_STRING and ResourceLoader.exists(tex_src) else null)
	if t == null:
		return
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission = Color(0.25, 0.24, 0.21)
	m.emission_texture = t
	m.emission_energy_multiplier = 0.8
	mesh(holder, m, "quad", Vector3(w, h, 1), Vector3(0, h / 2, 0.02))
	if frame:
		var fm := M("brass_dark")
		var t2 := 0.06
		mesh(holder, fm, "box", Vector3(w + t2 * 2, t2, 0.05), Vector3(0, h + t2 / 2, 0.02))
		mesh(holder, fm, "box", Vector3(w + t2 * 2, t2, 0.05), Vector3(0, -t2 / 2, 0.02))
		mesh(holder, fm, "box", Vector3(t2, h, 0.05), Vector3(-w / 2 - t2 / 2, h / 2, 0.02))
		mesh(holder, fm, "box", Vector3(t2, h, 0.05), Vector3(w / 2 + t2 / 2, h / 2, 0.02))

## фонарь-лампа настенная (возвращает OmniLight3D для мерцания)
static func wall_lamp(parent: Node3D, pos: Vector3, warm := 1.0) -> OmniLight3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	mesh(holder, M("brass_dark"), "box", Vector3(0.16, 0.05, 0.3), Vector3(0, 0.02, 0))
	var shade := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06; cm.bottom_radius = 0.11; cm.height = 0.22
	shade.mesh = cm
	shade.material_override = M("brass")
	shade.position = Vector3(0, 0.16, 0)
	holder.add_child(shade)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0.14, 0)
	l.light_color = Color(1.0, 0.72, 0.42) * warm
	l.light_energy = 2.2
	l.omni_range = 11.0
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	holder.add_child(l)
	var fl := LampFlicker.new()
	fl.light_node = l
	fl.phase = randf() * 10.0
	holder.add_child(fl)
	return l

## люстра/центральная лампа
static func chandelier(parent: Node3D, pos: Vector3) -> OmniLight3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	mesh(holder, M("brass_dark"), "box", Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.5)
	l.light_energy = 3.0
	l.omni_range = 16.0
	l.shadow_enabled = true
	holder.add_child(l)
	var fl := LampFlicker.new()
	fl.light_node = l
	holder.add_child(fl)
	return l

## витрина: цоколь + стекло (glass=null — пустая рама)
static func vitrine(parent: Node3D, pos: Vector3, w: float, h: float, d: float, content: Callable = Callable()) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var wood := mat("parquet_dark", Color(0.5, 0.45, 0.38), 0.6)
	var glass := M("glass")
	var leg := 0.9
	mesh(holder, wood, "box", Vector3(w + 0.1, leg, d + 0.1), Vector3(0, leg / 2 - 0.05, 0))
	mesh(holder, wood, "box", Vector3(w + 0.06, 0.08, d + 0.06), Vector3(0, leg + 0.04, 0))
	mesh(holder, wood, "box", Vector3(0.1, 0.1, d + 0.08), Vector3(0, h - 0.05, 0))
	mesh(holder, wood, "box", Vector3(w + 0.1, 0.1, 0.1), Vector3(0, h - 0.05, -d / 2 - 0.02))
	mesh(holder, wood, "box", Vector3(w + 0.1, 0.1, 0.1), Vector3(0, h - 0.05, d / 2 + 0.02))
	mesh(holder, glass, "box", Vector3(0.04, h - leg - 0.25, d), Vector3(w / 2 + 0.02, leg + (h - leg) / 2 - 0.05, 0), Vector3.ZERO, false)
	mesh(holder, glass, "box", Vector3(0.04, h - leg - 0.25, d), Vector3(-w / 2 - 0.02, leg + (h - leg) / 2 - 0.05, 0), Vector3.ZERO, false)
	mesh(holder, glass, "box", Vector3(w + 0.1, h - leg - 0.25, 0.04), Vector3(0, leg + (h - leg) / 2 - 0.05, d / 2 + 0.02), Vector3.ZERO, false)
	mesh(holder, glass, "box", Vector3(w + 0.1, h - leg - 0.25, 0.04), Vector3(0, leg + (h - leg) / 2 - 0.05, -d / 2 - 0.02), Vector3.ZERO, false)
	if content.is_valid():
		content.call(holder)

## ковровая дорожка
static func rug(parent: Node3D, pos: Vector3, w: float, d: float, rot_y := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("rug_red")
	m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, d)
	qm.orientation = 1
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.02, 0)
	mi.rotation.y = rot_y
	parent.add_child(mi)

## ступень спирали: длинная ось (w) — радиально, короткая (d) — по ходу
static func spiral_tread(parent: Node3D, mat: Material, ang: float, rad: float, y: float, w: float, d: float) -> void:
	mesh(parent, mat, "box", Vector3(w, 0.08, d), Vector3(cos(ang) * rad, y, sin(ang) * rad), Vector3(0, -ang, 0), true)

## простое мягкое свечение-сфера (для растений/глаз)
static func glow(parent: Node3D, pos: Vector3, rad: float, color: Color, energy := 3.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rad * 6.0
	parent.add_child(l)

static func pillar_light_shaft() -> void:
	pass
