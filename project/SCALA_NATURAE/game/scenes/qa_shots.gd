extends Node
## QA: авто-скриншоты (режим --shots). Телепорт по точкам главы I + захват кадра.
## Запуск: godot --path . -- --shots

var world: Node = null
var idx := 0
var waiting := 0
var done := false

var points := [
	{"name": "01_spawn", "pos": Vector3(0, 0.1, 13.0), "yaw": 0.0, "pitch": -0.06},
	{"name": "02_ladder", "pos": Vector3(4.2, 0.1, -2.0), "yaw": -35.0, "pitch": 0.0},
	{"name": "03_homo", "pos": Vector3(2.4, 6.3, -5.0), "yaw": -50.0, "pitch": -0.05},
	{"name": "04_birds", "pos": Vector3(-1.6, 0.1, -25.6), "yaw": 110.0, "pitch": -0.05},
	{"name": "05_skeleton", "pos": Vector3(-2.6, 0.1, -30.4), "yaw": 175.0, "pitch": -0.04},
	{"name": "06_corridor", "pos": Vector3(-6.0, 0.1, -20.5), "yaw": 0.0, "pitch": -0.05},
	{"name": "07_office", "pos": Vector3(8.6, 0.1, -24.6), "yaw": 55.0, "pitch": -0.04},
	{"name": "08_gallery_n", "pos": Vector3(0, 6.3, -6.0), "yaw": -10.0, "pitch": -0.02},
	{"name": "09_hall4", "pos": Vector3(2.4, 0.1, -21.6), "yaw": 0.0, "pitch": -0.03},
]

func _ready() -> void:
	world = get_parent()
	world.player.freeze = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DirAccess.make_dir_recursive_absolute("/home/user/scala-naturae/shots")
	_take_next()

func _take_next() -> void:
	if idx >= points.size():
		done = true
		print("QA_SHOTS: all done, quitting")
		get_tree().quit()
		return
	var pt: Dictionary = points[idx]
	world.relocate_player(pt.pos, float(pt.yaw))
	world.player.cam.rotation.x = float(pt.get("pitch", 0.0))
	world.player.can_move = false
	waiting = 3
	print("QA_SHOTS: point ", idx, " ", pt.name)

func _process(_delta: float) -> void:
	if done:
		return
	if waiting > 0:
		waiting -= 1
		return
	var pt: Dictionary = points[idx]
	var img := get_viewport().get_texture().get_image()
	var path := "/home/user/scala-naturae/shots/%s.png" % pt.name
	img.save_png(path)
	print("QA_SHOTS: saved ", path)
	idx += 1
	_take_next()
