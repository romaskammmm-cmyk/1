class_name Player
extends CharacterBody3D
## Смотритель: FPS-контроллер. Никакого HUD — только мир, лампа и дневник.

const WALK := 2.4
const RUN := 4.0
const LOOK_DIST := 2.6
const GRAV := -10.0
const EYE := 1.62

@onready var cam: Camera3D = $Camera3D
@onready var lantern: SpotLight3D = $Camera3D/Lantern
@onready var lantern_glow: OmniLight3D = $Camera3D/LanternGlow

var mouse_sens := 0.0022
var bob_t := 0.0
var bob_amp := 0.0
var fov_base := 72.0
var fov_pulse := 0.0
var lantern_on := true
var ui_open := false          # блокирует ввод (дневник/пауза/чтение)
var look_close := false
var can_move := true
var surface := "wood"
var speed := WALK
var freeze := false

var _head_rest := Vector3.ZERO
var _lantern_noise := 0.0
var _step_timer := 0.0

func _ready() -> void:
	add_to_group("player_body")
	collision_layer = 4   # игрок: не задеваем ни интерактивные лучи (2), ни мир-лучи (1)
	collision_mask = 1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.fov = fov_base
	_head_rest = cam.position
	lantern.visible = lantern_on
	lantern_glow.visible = lantern_on

func _unhandled_input(event: InputEvent) -> void:
	if ui_open or freeze:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		cam.rotate_x(-event.relative.y * mouse_sens)
		cam.rotation.x = clampf(cam.rotation.x, deg_to_rad(-88), deg_to_rad(88))
	elif event.is_action_pressed("lantern"):
		lantern_on = not lantern_on
		lantern.visible = lantern_on
		lantern_glow.visible = lantern_on
		AudioMgr.play("click", -4.0, randf_range(0.8, 1.2))
	elif event.is_action_pressed("look_close"):
		look_close = not look_close
	elif event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(delta: float) -> void:
	if freeze:
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	speed = RUN if Input.is_action_pressed("run") and move.y < 0 else WALK
	velocity.x = 0.0
	velocity.z = 0.0
	if can_move and not ui_open:
		var dir := (transform.basis * Vector3(move.x, 0, move.y)).normalized() if move.length() > 0.01 else Vector3.ZERO
		velocity = dir * speed
	velocity.y += GRAV * delta
	move_and_slide()

	_pulse(delta)
	_step_sound(delta, move.length() > 0.01)
	_headbob(delta, move.length() > 0.01)
	_lantern_flicker(delta)
	_detect_surface()

func _pulse(delta: float) -> void:
	## медленный пульс FOV (дыхание мира): чуть живая камера
	var t := Time.get_ticks_msec() / 1000.0
	var base := fov_base
	if look_close: base = 38.0
	var breath := sin(t * 0.55) * 0.6
	fov_pulse = move_toward(fov_pulse, breath, delta * 0.8)
	cam.fov = base + fov_pulse

func _step_sound(delta: float, moving: bool) -> void:
	if not moving or not is_on_floor():
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.46 if speed > 3.0 else 0.58
		AudioMgr.footstep(surface, 1 if speed > 3.0 else 0)

func _headbob(delta: float, moving: bool) -> void:
	var target := 0.0
	if moving and is_on_floor():
		bob_t += delta * (7.5 if speed > 3.0 else 5.2)
		target = 0.05 if speed > 3.0 else 0.028
	bob_amp = lerpf(bob_amp, target, delta * 6.0)
	var off := Vector3.ZERO
	if bob_amp > 0.001:
		off.y = sin(bob_t * 2.0) * bob_amp
		off.x = cos(bob_t) * bob_amp * 0.55
	cam.position = _head_rest + off
	cam.rotation.z = -off.x * 2.4

func _lantern_flicker(delta: float) -> void:
	if not lantern_on: return
	_lantern_noise += delta * 14.0
	var f := 1.0 + (sin(_lantern_noise) * 0.05 + sin(_lantern_noise * 2.7) * 0.035)
	lantern.light_energy = 1.9 * f
	lantern_glow.light_energy = 0.85 * f

func _detect_surface() -> void:
	var from := global_position + Vector3(0, 0.3, 0)
	var rs := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(rs)
	if hit.is_empty():
		surface = "wood"
	else:
		var o: Object = hit.collider
		if o is Node and o.is_in_group("surf_mud"): surface = "mud"
		elif o is Node and o.is_in_group("surf_stone"): surface = "stone"
		else: surface = "wood"

## Шаги вызывает сама зона по таймеру движения (см. zone root) — просто сервис:
func on_step() -> void:
	AudioMgr.footstep(surface, 1 if speed > 3.0 else 0)

func _try_interact() -> void:
	if ui_open: return
	var from: Vector3 = cam.global_position
	var to: Vector3 = from + -cam.global_transform.basis.z * LOOK_DIST
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		Game.prompt_hidden.emit()
		return
	var obj := hit.collider as Node
	if obj.has_method("activate"):
		obj.activate(self)

func look_prompt() -> Node:
	var from: Vector3 = cam.global_position
	var to: Vector3 = from + -cam.global_transform.basis.z * LOOK_DIST
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return null
	return hit.collider as Node

func is_seeing(global_pos: Vector3, max_dist: float = 24.0, half_fov := 0.82) -> bool:
	## видит ли игрок точку: дистанция + конус камеры + луч без преград
	var to := global_pos - cam.global_position
	var d := to.length()
	if d > max_dist: return false
	var fwd := -cam.global_transform.basis.z
	if fwd.dot(to / (d + 0.0001)) < half_fov: return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, global_pos, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return true
	return (hit.position as Vector3).distance_to(global_pos) < 1.0

func fade_out() -> void:
	pass
