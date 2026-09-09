extends Node3D
## Фото-сессия для визуального QA [qa-08]
## Запуск: xvfb-run -a /opt/godot/godot --path . --rendering-driver opengl3 res://scenes/photo_mode.tscn

const Chapter := preload("res://scenes/chapter1.tscn")

var ch
var cam: Camera3D

const SHOTS := [
	{"name": "01_rotunda_moon", "pos": Vector3(0, 1.7, -6.6), "look": Vector3(0, 1.1, 0)},
	{"name": "02_center_case", "pos": Vector3(2.8, 1.7, 2.6), "look": Vector3(0, 1.2, 0)},
	{"name": "03_west_hall", "pos": Vector3(-21.5, 1.7, 1.2), "look": Vector3(-28, 1.2, 2.0)},
	{"name": "04_giraffe_fakes", "pos": Vector3(-25.5, 1.7, 0.8), "look": Vector3(-24.2, 2.4, 3.6)},
	{"name": "05_altar", "pos": Vector3(-29.4, 1.6, 0.9), "look": Vector3(-30.8, 1.3, 0)},
	{"name": "06_east_desk", "pos": Vector3(24.5, 1.7, 4.2), "look": Vector3(27, 1.0, 3.6)},
	{"name": "07_cabinet", "pos": Vector3(11.2, 1.7, 2.6), "look": Vector3(14, 1.0, 5.2)},
	{"name": "08_giraffe_close", "pos": Vector3(-22.6, 1.7, 2.2), "look": Vector3(-23.5, 2.6, 4.0), "pose_giraffe": Vector3(-23.5, 0.2, 4.0)},
	{"name": "09_player_torch_rotunda", "pos": Vector3(0, 1.62, -5.2), "look": Vector3(0, 1.4, 0)},
	{"name": "10_player_torch_giraffe", "pos": Vector3(-23.2, 1.62, 0.9), "look": Vector3(-23.5, 2.4, 4.0), "pose_giraffe": Vector3(-23.5, 0.2, 4.0)},
]

func _ready() -> void:
	Game.photo_mode = true
	ch = Chapter.instantiate()
	add_child(ch)
	for i in range(30):
		await get_tree().process_frame
	cam = Camera3D.new()
	cam.fov = 74.0
	add_child(cam)
	cam.current = true
	for s: Dictionary in SHOTS:
		if s.has("pose_giraffe"):
			ch.giraffe.global_position = s.pose_giraffe
			ch.giraffe.look_at(Vector3(s.pos.x, 0.2, s.pos.z), Vector3.UP)
		cam.global_position = s.pos
		cam.look_at(s.look, Vector3.UP)
		for i in range(12):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "res://tests/shots/%s.png" % s.name
		img.save_png(path)
		print("[photo] ", path)
	get_tree().quit()
