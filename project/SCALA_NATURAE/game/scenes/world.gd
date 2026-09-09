extends Node3D
## Мир: окружение + игрок + UI + текущая глава-зона. Собирается полностью кодом.

const ZONE_SCRIPTS := {
	"c1_museum": "res://zones/c1_museum.gd",
	"c2_vault": "res://zones/c2_vault.gd",
	"c3_swamp": "res://zones/c3_swamp.gd",
	"c4_herbarium": "res://zones/c4_herbarium.gd",
	"c5_finale": "res://zones/c5_finale.gd",
}

var player: Player = null
var zone: Node3D = null
var diary_open := false
var note_open := false
var ui_layer: CanvasLayer
var prompt_label: Label
var sub_label: Label
var diary_panel: PanelContainer
var diary_text: RichTextLabel
var note_panel: PanelContainer
var note_title: Label
var note_body: RichTextLabel
var fade_rect: ColorRect
var hints: Label
var _prompt_timer := 0.0
var _fading := false

const WHO_COLOR := {
	"self": "#b8b4a6", "water": "#9fc4b4", "director": "#c9b28a", "other": "#a8a89f",
}

func _ready() -> void:
	_build_env()
	_build_ui()
	player = preload("res://player/player.tscn").instantiate()
	add_child(player)
	_load_zone(Game.chapter if Game.chapter != "" else "c1_museum")
	AudioMgr.start_ambient()
	Game.prompt_hidden.emit()
	if OS.get_cmdline_user_args().has("shots"):
		var qa: Node = preload("res://scenes/qa_shots.gd").new()
		add_child(qa)

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.004, 0.005, 0.005)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.10, 0.095, 0.085)
	e.ambient_light_energy = 0.7
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.10, 0.07)
	e.fog_light_energy = 0.9
	e.fog_density = 0.02
	e.fog_sky_affect = 0.0
	e.volumetric_fog_enabled = false
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_bloom = 0.02
	e.glow_levels = 3
	e.ssao_enabled = true
	e.ssao_intensity = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.adjustment_enabled = false
	env.environment = e
	add_child(env)

# ---------------- UI ----------------
func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	# виньетка
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(vig)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){vec2 p=UV-0.5;float d=length(p);COLOR=vec4(0.0,0.0,0.0,smoothstep(0.62,0.95,d)*0.85);}"
	vig.material = ShaderMaterial.new()
	vig.material.shader = sh
	# подсказка взаимодействия
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(0, -120)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size = Vector2(900, 0)
	prompt_label.add_theme_font_size_override("font_size", 15)
	prompt_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.text = ""
	ui_layer.add_child(prompt_label)
	# fade
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade_rect)
	# дневник
	diary_panel = _paper_panel()
	diary_panel.visible = false
	diary_text = RichTextLabel.new()
	diary_text.bbcode_enabled = true
	diary_text.scroll_following = true
	diary_text.add_theme_font_size_override("normal_font_size", 16)
	diary_text.add_theme_font_size_override("bold_font_size", 17)
	diary_text.custom_minimum_size = Vector2(640, 420)
	diary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diary_panel.add_child(diary_text)
	# записка
	note_panel = _paper_panel()
	note_panel.visible = false
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 440)
	note_panel.add_child(vb)
	note_title = Label.new()
	note_title.add_theme_font_size_override("font_size", 21)
	note_title.add_theme_color_override("font_color", Color(0.16, 0.13, 0.09))
	vb.add_child(note_title)
	note_body = RichTextLabel.new()
	note_body.bbcode_enabled = true
	note_body.add_theme_font_size_override("normal_font_size", 16)
	note_body.add_theme_color_override("default_color", Color(0.15, 0.12, 0.09))
	note_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(note_body)
	Game.prompt_shown.connect(_on_prompt)
	Game.fade_requested.connect(_on_fade_req)

func _paper_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.86, 0.82, 0.72, 0.97)
	st.border_color = Color(0.35, 0.3, 0.22)
	st.set_border_width_all(3)
	st.set_corner_radius_all(4)
	st.content_margin_left = 36
	st.content_margin_right = 36
	st.content_margin_top = 28
	st.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", st)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui_layer.add_child(p)
	return p

func _process(delta: float) -> void:
	_update_prompts(delta)
	# кнопки дневника/паузы
	if Input.is_action_just_pressed("diary") and not note_open:
		diary_open = not diary_open
		diary_panel.visible = diary_open
		_input_mode()
		if diary_open:
			_refresh_diary()
	if Input.is_action_just_pressed("pause"):
		if diary_open:
			diary_open = false
			diary_panel.visible = false
			_input_mode()
		elif note_open:
			close_note()
	if diary_open:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			diary_open = false
			diary_panel.visible = false
			_input_mode()

func _nothing() -> void:
	pass

func _input_mode() -> void:
	if diary_open or note_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		player.ui_open = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player.ui_open = false

# ---------------- промпты ----------------
func _update_prompts(delta: float) -> void:
	if diary_open or note_open or _fading:
		return
	var obj: Node = player.look_prompt() if player else null
	if obj and obj.has_method("get_prompt"):
		var txt: String = obj.get_prompt()
		if txt != "":
			prompt_label.text = txt
			return
	if _prompt_timer > 0.0:
		_prompt_timer -= delta
		return
	prompt_label.text = ""

func _on_prompt(text: String) -> void:
	prompt_label.text = text
	_prompt_timer = 2.4

# ---------------- зоны ----------------
func _load_zone(id: String) -> void:
	if zone != null:
		zone.queue_free()
	var path: String = ZONE_SCRIPTS.get(id, ZONE_SCRIPTS["c1_museum"])
	var script: Script = load(path)
	zone = Node3D.new()
	zone.name = "Zone"
	zone.set_script(script)
	add_child(zone)
	Game.load_chapter(id)
	zone.call("build", self)
	Game.zone_ready(zone)
	if zone.has_method("player_spawn"):
		var sp: Dictionary = zone.call("player_spawn")
		relocate_player(sp.get("pos", Vector3.ZERO), float(sp.get("yaw", 0.0)))
	_refresh_diary()

func goto_chapter(id: String) -> void:
	if _fading: return
	_fading = true
	_on_fade_req("to_black")
	await get_tree().create_timer(1.2).timeout
	var keep := {}
	for k in ["lantern_on"]:
		keep[k] = player.get(k)
	_load_zone(id)
	player.ui_open = false
	_on_fade_req("to_clear")
	_fading = false

func relocate_player(pos: Vector3, yaw_deg := 0.0) -> void:
	player.global_position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	player.velocity = Vector3.ZERO

func _on_fade_req(kind: String) -> void:
	var tw := create_tween()
	if kind == "to_black":
		tw.tween_property(fade_rect, "color:a", 1.0, 0.9)
	else:
		tw.tween_property(fade_rect, "color:a", 0.0, 1.4)

func do_grab_effect(entry_pos: Vector3, entry_yaw: float, diary_who: String, diary_line: String) -> void:
	## «Перестановка»: экспонат переставил вас.
	if _fading: return
	_fading = true
	_on_fade_req("to_black")
	await get_tree().create_timer(1.4).timeout
	relocate_player(entry_pos, entry_yaw)
	if diary_line != "":
		Game.diary_add(diary_who, diary_line)
	_on_fade_req("to_clear")
	await get_tree().create_timer(1.2).timeout
	_fading = false

# ---------------- записки и дневник ----------------
func open_note(note_id: String) -> void:
	var data := Game.get_note(note_id)
	if data.is_empty():
		return
	note_open = true
	note_title.text = data.get("title", "")
	var body: String = data.get("body", "")
	note_body.text = body
	note_panel.visible = true
	_input_mode()

func close_note() -> void:
	note_open = false
	note_panel.visible = false
	_input_mode()

func _refresh_diary() -> void:
	var txt := "[color=#6a6254]— журнал смотрителя —[/color]\n"
	for e in Game.diary:
		var who: String = e.get("who", "self")
		var color: String = WHO_COLOR.get(who, "#b8b4a6")
		txt += "[color=%s]» %s[/color]\n" % [color, e.get("text", "")]
	diary_text.text = txt + "\n"
