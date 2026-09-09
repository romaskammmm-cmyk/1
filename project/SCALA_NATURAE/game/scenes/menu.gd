extends Control
## Главное меню «SCALA NATURAE»
## Служебные аргументы: --direct (сразу в игру), --zone <id> (тест конкретной главы)

var _f: Font = null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--zone"):
		var zi := args.find("--zone")
		if zi >= 0 and zi + 1 < args.size():
			Game.chapter = args[zi + 1]
			Game.flags.clear()
			Game.counters.clear()
			Game.diary.clear()
			Game.start_game()
			return
	if args.has("--direct"):
		Game.reset_run()
		Game.start_game()
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# фон
	var bg := ColorRect.new()
	bg.color = Color(0.016, 0.018, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# туманная вуаль
	var fog := ColorRect.new()
	fog.color = Color(0.05, 0.055, 0.05, 0.25)
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fog)
	# заголовок
	_set_fonts()
	var title := Label.new()
	title.text = "SCALA\nNATURAE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", Color(0.78, 0.68, 0.5))
	title.add_theme_font_override("font", _f)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 90)
	title.custom_minimum_size = Vector2(0, 190)
	add_child(title)
	var sub := Label.new()
	sub.text = "музей естественной истории · ночная смена"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.44, 0.4))
	sub.add_theme_font_override("font", _f)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(0, 280)
	add_child(sub)
	var warn := Label.new()
	warn.text = "хоррор · шёпот · никакой крови\nсвет и порядок не всегда спасают"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 13)
	warn.add_theme_color_override("font_color", Color(0.3, 0.32, 0.3))
	warn.add_theme_font_override("font", _f)
	warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn.position = Vector2(0, 560)
	add_child(warn)
	# кнопки
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-80, 70)
	box.custom_minimum_size = Vector2(160, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_add_btn(box, "Новая смена", func():
		Game.reset_run()
		Game.start_game())
	var cont := _add_btn(box, "Продолжить", func():
		Game.start_game())
	cont.disabled = not Game.has_save()
	_add_btn(box, "Выход", func():
		get_tree().quit())
	AudioMgr.start_ambient()

func _add_btn(box: VBoxContainer, text: String, cb: Callable) -> Button:
	_set_fonts()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 38)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_font_override("font", _f)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	box.add_child(b)
	return b

func _set_fonts() -> void:
	if _f == null:
		var path := "res://assets/fonts/DejaVuSerif.ttf"
		_f = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	modulate.a = 0.9 + 0.1 * sin(t * 0.4)
