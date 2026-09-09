extends Control
## Главное меню [ux-07 + audio-06]

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	var bg_tex := load("res://art/menu_bg.png")
	if bg_tex:
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		bg.texture = load("res://assets/textures/marble.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate = Color(0.25, 0.25, 0.3)
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "НЕДОСТАЮЩЕЕ\nЗВЕНО"
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", Color(0.87, 0.85, 0.78))
	title.add_theme_constant_override("line_spacing", 4)
	title.position = Vector2(90, 120)
	title.size = Vector2(600, 260)
	add_child(title)
	_flicker(title)

	var sub := Label.new()
	sub.text = "SPECIES INCOGNITA · ИЭТ · СТРЕЛЕЦК-14 · 1971"
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.5))
	sub.position = Vector2(94, 388)
	add_child(sub)

	var warn := Label.new()
	warn.text = "играть в наушниках · свет фонаря выдаёт вас"
	warn.add_theme_font_size_override("font_size", 15)
	warn.add_theme_color_override("font_color", Color(0.45, 0.3, 0.26))
	warn.position = Vector2(94, 424)
	add_child(warn)

	_buttons()

	var ver := Label.new()
	ver.text = "вертикальный срез · глава 1 «Экспозиция» · сборка %s" % _build_id()
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.4, 0.42, 0.38))
	ver.position = Vector2(16, 690)
	add_child(ver)

	Game.play_loop(_ambient_player(), "res://assets/audio/drone_menu.wav", -8.0)

func _ambient_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

func _buttons() -> void:
	var y := 480
	for entry: Dictionary in [
		{"t": "НОВАЯ СМЕНА", "fn": _on_new, "always": true},
		{"t": "ПРОДОЛЖИТЬ", "fn": _on_continue, "always": false},
		{"t": "ВЫХОД", "fn": _on_quit, "always": true},
	]:
		var b := Button.new()
		b.text = entry.t
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color(0.75, 0.73, 0.66))
		b.add_theme_color_override("font_hover_color", Color(0.9, 0.28, 0.2))
		b.add_theme_color_override("font_pressed_color", Color(0.55, 0.12, 0.08))
		b.position = Vector2(94, y)
		b.size = Vector2(400, 44)
		if not entry.always and not Game.has_save():
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.3)
		b.pressed.connect(entry.fn)
		add_child(b)
		y += 56

func _flicker(label: Label) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(label, "modulate:a", 0.72, 0.13).set_delay(randf_range(0.4, 1.6))
	tw.tween_property(label, "modulate:a", 1.0, 0.07)

func _build_id() -> String:
	var b := OS.get_environment("ZVENO_BUILD")
	return b if b != "" else "dev"

func _on_new() -> void:
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/chapter1.tscn")

func _on_continue() -> void:
	if Game.load_game():
		get_tree().change_scene_to_file("res://scenes/chapter1.tscn")

func _on_quit() -> void:
	get_tree().quit()
