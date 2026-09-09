extends CharacterBody3D
## Игрок — хранитель фондов [code-05]
## Группы: "player"

const WALK := 3.1
const SPRINT := 5.3
const STAMINA_MAX := 6.0
const BOB_FREQ := 7.2
const BOB_AMP := 0.035

var stamina := STAMINA_MAX
var frozen := false
var flashlight_on := true
var bob_t := 0.0
var step_dist := 0.0

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var torch: SpotLight3D = $Head/Flashlight
@onready var beam: MeshInstance3D = $Head/Beam
@onready var ray: RayCast3D = $Head/InteractRay
@onready var step_player: AudioStreamPlayer = $StepPlayer
@onready var heart_player: AudioStreamPlayer = $HeartPlayer

func _ready() -> void:
	add_to_group("player")
	_build_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	heart_player.stream = Game.make_loop("res://assets/audio/heartbeat.wav")
	heart_player.volume_db = -60.0
	heart_player.play()

func _build_body() -> void:
	var col := get_node("Collision") as CollisionShape3D
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	torch.position = Vector3(0.14, -0.22, 0)
	ray.target_position = Vector3(0, 0, -2.6)
	ray.collision_mask = 8  # слой интерактаблов
	torch.light_energy = 3.2
	torch.shadow_enabled = true
	torch.distance_fade_enabled = true
	# мягкий аддитивный конус «объёма» света
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 1.9
	cone.height = 17.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.95, 0.82, 0.028)
	cone.material = mat
	beam.mesh = cone
	beam.position = Vector3(0, 0, -8.5)

func _unhandled_input(event: InputEvent) -> void:
	if frozen: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Game.mouse_sens)
		head.rotation.x = clamp(head.rotation.x - event.relative.y * Game.mouse_sens, -1.45, 1.45)
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		torch.visible = flashlight_on
		beam.visible = flashlight_on
		Game.play_at(self, "res://assets/audio/flashlight_click.wav", -14.0, 6.0)

func _physics_process(delta: float) -> void:
	if frozen:
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		move_and_slide()
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and stamina > 0.3 and dir != Vector3.ZERO
	if sprinting:
		stamina = max(0.0, stamina - delta)
	else:
		stamina = min(STAMINA_MAX, stamina + delta * 0.7)
	var speed := SPRINT if sprinting else WALK
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	move_and_slide()
	# покачивание головы + шаги
	var planar := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar > 0.4:
		bob_t += delta * BOB_FREQ * (planar / WALK)
		head.position.y = 1.62 + sin(bob_t) * BOB_AMP
		head.rotation.z = sin(bob_t * 0.5) * 0.006
		step_dist += planar * delta
		if step_dist > (0.95 if sprinting else 1.15):
			step_dist = 0.0
			Game.play_rand_at(self, "res://assets/audio/step_%d.wav", 4, -13.0, 7.0)
	else:
		head.position.y = lerpf(head.position.y, 1.62, 8 * delta)

func looking_at(target: Vector3, threshold := 0.6) -> bool:
	## видит ли игрок точку (без проверки стен)
	var to := (target - cam.global_position).normalized()
	return cam.global_transform.basis.z.dot(to) > threshold

func lit_sees(target: Vector3, threshold := 0.55) -> bool:
	## луч фонаря наведён на точку и она не за стеной
	if not flashlight_on: return false
	if not looking_at(target, threshold): return false
	var from := cam.global_position
	var to := target
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # слой 1 = геометрия
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return true
	return (hit.position - from).length() > (to - from).length() - 0.6

func current_interactable() -> Area3D:
	if ray.is_colliding():
		var col := ray.get_collider()
		if col is Area3D and col.is_in_group("interactable"):
			return col
	return null

func set_heartbeat(v: float) -> void:
	## dread 0..1 от близости образца
	heart_player.volume_db = lerpf(-60.0, 1.5, clamp(v, 0.0, 1.0))
	if clamp(v, 0.0, 1.0) > 0.25 and not heart_player.playing:
		heart_player.play()
