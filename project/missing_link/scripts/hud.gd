extends CanvasLayer
## HUD главы 1: карточка вида, печати, субтитры, PA, оверлеи [ux-07]
## Слои: 10. Обрабатывает свой ввод (окна читаются при паузе).

signal note_closed
signal altar_answered(accepted: bool)
signal death_finished
signal death_dismissed
signal menu_requested

var prompt_label: Label
var species_label: Label
var seal_label: Label
var sub_label: Label
var pa_label: Label
var vignette: TextureRect
var flash_label: Label
var note_layer: Control
var altar_layer: Control
var death_layer: Control
var end_layer: Control
var grain: ColorRect

var note_open := false
var altar_open := false
var death_on := false
var death_ready := false
var sub_queue: Array = []
var sub_t := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.subtitle_requested.connect(_on_subtitle)
	Game.mutation_added.connect(_on_mutation)
	Game.seal_added.connect(func(n): seal_label.text = "ПЕЧАТИ ПРОИСХОЖДЕНИЯ: %d / 3" % n)
	species_label.text = Game.species_name()

func _build() -> void:
	# зерно плёнки (верхний слой)
	grain = ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 0.2) = 0.05;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 px = UV * vec2(1280.0, 720.0);
	float n = hash(px + vec2(fract(TIME * 17.0) * 1000.0));
	COLOR = vec4(vec3(n * 0.9), amount * (1.0 - abs(n - 0.5) * 2.0));
}
"""
	grain.material = ShaderMaterial.new()
	(grain.material as ShaderMaterial).shader = sh
	add_child(grain)
	# виньетка
	vignette = TextureRect.new()
	vignette.texture = load("res://assets/textures/vignette.png")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate = Color(1, 1, 1, 0.35)
	add_child(vignette)
	# карточка вида
	var card := PanelContainer.new()
	card.position = Vector2(18, 596)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.82)
	style.border_color = Color(0.35, 0.33, 0.27)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 8; style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	var head := Label.new()
	head.text = "КАРТОЧКА ВИДА · ИЭТ"
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.55, 0.55, 0.45))
	species_label = Label.new()
	species_label.add_theme_font_size_override("font_size", 21)
	species_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.7))
	seal_label = Label.new()
	seal_label.add_theme_font_size_override("font_size", 14)
	seal_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.48))
	seal_label.text = "ПЕЧАТИ ПРОИСХОЖДЕНИЯ: 0 / 3"
	vb.add_child(head); vb.add_child(species_label); vb.add_child(seal_label)
	card.add_child(vb)
	add_child(card)
	# подсказка взаимодействия
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(640, 620)
	prompt_label.size = Vector2(0, 0)
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	add_child(prompt_label)
	# субтитры
	sub_label = Label.new()
	sub_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_label.position = Vector2(640, 566)
	sub_label.add_theme_font_size_override("font_size", 19)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.72))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_label)
	# PA
	pa_label = Label.new()
	pa_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pa_label.position = Vector2(640, 40)
	pa_label.add_theme_font_size_override("font_size", 20)
	pa_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	pa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pa_label.modulate.a = 0.0
	add_child(pa_label)
	# всплывающие сообщения
	flash_label = Label.new()
	flash_label.position = Vector2(640, 120)
	flash_label.add_theme_font_size_override("font_size", 16)
	flash_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.6))
	flash_label.modulate.a = 0.0
	add_child(flash_label)

# ---------------------------------------------------------------- каждый кадр
func _process(delta: float) -> void:
	if sub_t > 0.0:
		sub_t -= delta
		if sub_t <= 0.0:
			sub_label.modulate.a = 0.0
			_next_sub()
	set_dread(_dread)

var _dread := 0.0
func set_dread(v: float) -> void:
	_dread = v
	vignette.modulate = Color(1, 1, 1, 0.35 + v * 0.45)
	vignette.modulate.r = 1.0 + v * 0.25

func set_prompt(text: String) -> void:
	prompt_label.text = text

func flash(text: String) -> void:
	flash_label.text = text
	flash_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(flash_label, "modulate:a", 0.0, 2.6).set_delay(1.2)

# ---------------------------------------------------------------- субтитры
func _on_subtitle(text: String, kind: String, dur: float) -> void:
	sub_queue.append([text, kind, dur])
	_next_sub()

func _next_sub() -> void:
	if sub_t > 0.0 or sub_queue.is_empty(): return
	var item = sub_queue.pop_front()
	var text: String = item[0]; var kind: String = item[1]; var dur: float = item[2]
	if kind == "pa":
		pa_label.text = "[ ГРОМКАЯ СВЯЗЬ ]  " + text
		pa_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(pa_label, "modulate:a", 0.0, 1.4).set_delay(dur)
	else:
		sub_label.text = text
		sub_label.modulate.a = 1.0
	sub_t = dur

# ---------------------------------------------------------------- мутация
func _on_mutation(m: Dictionary) -> void:
	species_label.text = Game.species_name()
	flash("СТРЕМЛЕНИЕ ПРИНЯТО: " + m.name)

# ---------------------------------------------------------------- записка
func show_note(title: String, text: String) -> void:
	if note_open or altar_open or death_on: return
	note_open = true
	get_tree().paused = true
	note_layer = Control.new()
	note_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	note_layer.add_child(dim)
	var paper := TextureRect.new()
	paper.texture = load("res://assets/textures/paper.png")
	paper.position = Vector2(340, 60)
	paper.size = Vector2(600, 600)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	var t := Label.new()
	t.text = title
	t.position = Vector2(380, 96)
	t.size = Vector2(520, 40)
	t.add_theme_font_size_override("font_size", 23)
	t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08))
	var body := Label.new()
	body.text = text
	body.position = Vector2(380, 160)
	body.size = Vector2(520, 440)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.18, 0.15, 0.1))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := Label.new()
	hint.text = "[E] убрать"
	hint.position = Vector2(560, 664)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5))
	note_layer.add_child(paper); note_layer.add_child(t); note_layer.add_child(body); note_layer.add_child(hint)
	add_child(note_layer)
	Game.play_ui("res://assets/audio/paper.wav", -6.0)

func _close_note() -> void:
	note_open = false
	note_layer.queue_free()
	note_layer = null
	get_tree().paused = false
	note_closed.emit()

# ---------------------------------------------------------------- алтарь
func show_altar(offer: String, mut_name: String) -> void:
	if note_open or altar_open or death_on: return
	altar_open = true
	get_tree().paused = true
	altar_layer = Control.new()
	altar_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	altar_layer.add_child(dim)
	var box := PanelContainer.new()
	box.position = Vector2(320, 210)
	box.size = Vector2(640, 280)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.03, 0.02, 0.95)
	st.border_color = Color(0.5, 0.15, 0.1)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.content_margin_left = 30; st.content_margin_right = 30
	st.content_margin_top = 22; st.content_margin_bottom = 22
	box.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	var h := Label.new()
	h.text = "СТРЕМЛЕНИЕ ПРЕДЛАГАЕТ: " + mut_name
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", Color(0.95, 0.4, 0.25))
	var body := Label.new()
	body.text = offer
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.85, 0.75, 0.65))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 120)
	var f := Label.new()
	f.text = "[E] Принять    [ESC] Отказаться"
	f.add_theme_font_size_override("font_size", 18)
	f.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	vb.add_child(h); vb.add_child(body); vb.add_child(f)
	box.add_child(vb)
	altar_layer.add_child(box)
	add_child(altar_layer)
	Game.play_ui("res://assets/audio/whisper.wav", -8.0)

func _close_altar(accepted: bool) -> void:
	altar_open = false
	altar_layer.queue_free()
	altar_layer = null
	get_tree().paused = false
	altar_answered.emit(accepted)

# ---------------------------------------------------------------- смерть
func play_death() -> void:
	if death_on: return
	death_on = true
	Game.play_ui("res://assets/audio/scare_sting.wav", -3.0)
	death_layer = Control.new()
	death_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var face := TextureRect.new()
	var tex := load("res://art/scare_face.png")
	if tex:
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		face.texture = load("res://assets/textures/giraffe_skin.png")
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_layer.add_child(face)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_layer.add_child(black)
	var txt := Label.new()
	txt.text = "ОБРАЗЕЦ №0 ПОВРЕЖДЁН.\nВОССТАНОВЛЕНИЕ ЭКСПОНАТА…\n\n[E]"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.set_anchors_preset(Control.PRESET_FULL_RECT)
	txt.add_theme_font_size_override("font_size", 26)
	txt.add_theme_color_override("font_color", Color(0.8, 0.2, 0.12))
	txt.modulate.a = 0.0
	death_layer.add_child(txt)
	add_child(death_layer)
	var tw := create_tween()
	tw.tween_property(face, "modulate", Color(1, 0.7, 0.7), 0.06)
	tw.tween_property(face, "modulate", Color(0, 0, 0), 0.7).set_delay(0.45)
	tw.parallel().tween_property(black, "color", Color(0, 0, 0, 1), 0.7).set_delay(0.4)
	tw.tween_property(txt, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tw.tween_callback(func():
		death_ready = true
		death_finished.emit())

func _finish_death() -> void:
	death_on = false
	death_ready = false
	death_layer.queue_free()
	death_layer = null
	death_dismissed.emit()

# ---------------------------------------------------------------- конец среза
func show_slice_end(stats: String) -> void:
	get_tree().paused = true
	end_layer = Control.new()
	end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0.92)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(black)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var h1 := Label.new()
	h1.text = "КОНЕЦ ПЕРВОЙ ГЛАВЫ\n«ЭКСПОЗИЦИЯ»"
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h1.add_theme_font_size_override("font_size", 44)
	h1.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	var st := Label.new()
	st.text = stats
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 18)
	st.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	var h2 := Label.new()
	h2.text = "ПРОДОЛЖЕНИЕ СЛЕДУЕТ"
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h2.add_theme_font_size_override("font_size", 20)
	h2.add_theme_color_override("font_color", Color(0.7, 0.2, 0.12))
	var btn := Button.new()
	btn.text = "В ГЛАВНОЕ МЕНЮ"
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): get_tree().paused = false; menu_requested.emit())
	vb.add_child(h1); vb.add_child(st); vb.add_child(h2); vb.add_child(btn)
	end_layer.add_child(vb)
	add_child(end_layer)

# ---------------------------------------------------------------- ввод оверлеев
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if note_open:
			_close_note()
			get_viewport().set_input_as_handled()
		elif altar_open:
			_close_altar(true)
			get_viewport().set_input_as_handled()
		elif death_on and death_ready:
			_finish_death()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and altar_open:
		_close_altar(false)
		get_viewport().set_input_as_handled()
