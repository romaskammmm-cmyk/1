extends CanvasLayer
## Пауза — «полевая карточка коллекционера» [ux-07]

signal resume_requested
signal restart_requested
signal menu_requested

var root: Control

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var black := ColorRect.new()
	black.color = Color(0.01, 0.01, 0.015, 0.88)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	# карточка вида
	var card := PanelContainer.new()
	card.position = Vector2(120, 90)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.05, 0.95)
	st.border_color = Color(0.4, 0.38, 0.3)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.content_margin_left = 34; st.content_margin_right = 34
	st.content_margin_top = 26; st.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	var h := Label.new()
	h.text = "КАРТОЧКА ВИДА"
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.55, 0.52, 0.4))
	var latin := Label.new()
	latin.text = Game.species_name()
	latin.add_theme_font_size_override("font_size", 40)
	latin.add_theme_color_override("font_color", Color(0.88, 0.85, 0.7))
	var det1 := Label.new()
	det1.text = "колл. Линник В.К. · СТРЕЛЕЦК-14 · 1971"
	det1.add_theme_font_size_override("font_size", 16)
	det1.add_theme_color_override("font_color", Color(0.6, 0.58, 0.48))
	var det2 := Label.new()
	det2.text = _notes_line()
	det2.add_theme_font_size_override("font_size", 16)
	det2.add_theme_color_override("font_color", Color(0.6, 0.58, 0.48))
	var note := Label.new()
	note.text = "ПРИМЕЧАНИЕ: " + _remark()
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.62, 0.3, 0.22))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(460, 60)
	vb.add_child(h); vb.add_child(latin); vb.add_child(det1); vb.add_child(det2); vb.add_child(note)
	card.add_child(vb)
	root.add_child(card)
	# статистика
	var stats := Label.new()
	stats.position = Vector2(660, 130)
	stats.text = _stats()
	stats.add_theme_font_size_override("font_size", 17)
	stats.add_theme_color_override("font_color", Color(0.65, 0.63, 0.55))
	root.add_child(stats)
	# слайдеры
	_slider("ЧУВСТВИТЕЛЬНОСТЬ", Vector2(660, 300), 0.4, 2.0, func(v): Game.mouse_sens = 0.0022 * v, Game.mouse_sens / 0.0022)
	_slider("ГРОМКОСТЬ", Vector2(660, 372), 0.0, 1.3, func(v): AudioServer.set_bus_volume_db(0, linear_to_db(clamp(v, 0.001, 1.3))), db_to_linear(AudioServer.get_bus_volume_db(0)))
	# кнопки
	var y := 520
	for entry: Dictionary in [
		{"t": "ПРОДОЛЖИТЬ", "fn": func(): toggle(); resume_requested.emit()},
		{"t": "НАЧАТЬ ГЛАВУ ЗАНОВО", "fn": func(): get_tree().paused = false; restart_requested.emit()},
		{"t": "В ГЛАВНОЕ МЕНЮ", "fn": func(): get_tree().paused = false; menu_requested.emit()},
	]:
		var b := Button.new()
		b.text = entry.t
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(660, y)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(entry.fn)
		root.add_child(b)
		y += 54

func _slider(label_text: String, pos: Vector2, mn: float, mx: float, setter: Callable, initial: float) -> void:
	var l := Label.new()
	l.text = label_text
	l.position = pos
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.48))
	root.add_child(l)
	var s := HSlider.new()
	s.position = Vector2(pos.x, pos.y + 28)
	s.size = Vector2(340, 20)
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = clamp(initial, mn, mx)
	s.value_changed.connect(setter)
	root.add_child(s)

func _notes_line() -> String:
	return "записок прочитано: %d / 4 · печатей: %d / 3 · смертей: %d" % [Game.state.notes.size(), Game.state.seals, Game.state.deaths]

func _remark() -> String:
	if Game.state.mutations.is_empty():
		return "вид не изменён. пока."
	var parts: Array[String] = []
	for m in Game.state.mutations:
		if Game.MUT_DEFS.has(m):
			parts.append(Game.MUT_DEFS[m].desc)
	return " ".join(parts)

func _stats() -> String:
	var mins := int(Game.elapsed()) / 60
	var secs := int(Game.elapsed()) % 60
	return "ВРЕМЯ СМЕНЫ: %02d:%02d\nГЛАВА 1 «ЭКСПОЗИЦИЯ»\nВЕРТИКАЛЬНЫЙ СРЕЗ · СБОРКА %s" % [mins, secs, OS.get_environment("ZVENO_BUILD") if OS.get_environment("ZVENO_BUILD") != "" else "dev"]
