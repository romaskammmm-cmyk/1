extends Node
## QA: авто-скриншоты. Запуск: godot --path . -- --direct --shots  (или --shots:c2)

var world: Node = null
var idx := 0
var waiting := 0
var done := false

var points_c1 := [
	{"name": "01_spawn", "pos": Vector3(0, 0.1, 10.0), "yaw": 0.0, "pitch": -0.06},
	{"name": "02_ladder", "pos": Vector3(4.2, 0.1, -1.0), "yaw": -55.0, "pitch": -0.04},
	{"name": "03_gallery", "pos": Vector3(3.0, 6.1, 2.0), "yaw": -100.0, "pitch": -0.08},
	{"name": "04_birds", "pos": Vector3(-2.4, 0.1, -25.4), "yaw": 130.0, "pitch": -0.06},
	{"name": "05_skeleton", "pos": Vector3(-3.4, 0.1, -30.6), "yaw": 175.0, "pitch": -0.05},
	{"name": "06_hall4", "pos": Vector3(2.4, 0.1, -21.2), "yaw": 0.0, "pitch": -0.04},
]
var points_c2 := [
	{"name": "c2_01_enter", "pos": Vector3(0, 0.1, 10.0), "yaw": 0.0, "pitch": -0.05},
	{"name": "c2_02_cross", "pos": Vector3(0, 0.1, 0.0), "yaw": -40.0, "pitch": -0.03},
	{"name": "c2_03_labs", "pos": Vector3(-11.0, 0.1, -0.5), "yaw": 90.0, "pitch": -0.04},
	{"name": "c2_04_water", "pos": Vector3(-10.5, 0.1, -3.0), "yaw": 95.0, "pitch": -0.03},
	{"name": "c2_05_mirror", "pos": Vector3(8.6, 0.1, 10.0), "yaw": -60.0, "pitch": -0.04},
	{"name": "c2_06_swampdoor", "pos": Vector3(11.5, 0.1, 4.5), "yaw": 90.0, "pitch": -0.03},
]

func _ready() -> void:
	print("QA_SHOTS: ready entered world")
	world = get_parent()
	world.player.freeze = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DirAccess.make_dir_recursive_absolute("/home/user/scala-naturae/shots")
	_take_next()

func _take_next() -> void:
	print("QA_SHOTS: take_next ", idx)
	var pts: Array = points_c1
	if OS.get_cmdline_user_args().has("--shots:c2"):
		pts = points_c2
	if idx >= pts.size():
		done = true
		print("QA_SHOTS: all done, quitting")
		get_tree().quit()
		return
	var pt: Dictionary = pts[idx]
	world.relocate_player(pt.pos, float(pt.yaw))
	world.player.cam.rotation.x = float(pt.get("pitch", 0.0))
	world.player.can_move = false
	world.player.freeze = true
	waiting = 6
	print("QA_SHOTS: point ", idx, " ", pt.name)

func _process(_delta: float) -> void:
	if done:
		return
	if waiting > 0:
		waiting -= 1
		return
	var pts: Array = points_c1
	var tag := ""
	if OS.get_cmdline_user_args().has("--shots:c2"):
		pts = points_c2
		tag = "_c2"
	var pt: Dictionary = pts[idx]
	var img := get_viewport().get_texture().get_image()
	var path := "/home/user/scala-naturae/shots/%s%s.png" % [pt.name, tag]
	img.save_png(path)
	print("QA_SHOTS: saved ", path)
	idx += 1
	_take_next()
