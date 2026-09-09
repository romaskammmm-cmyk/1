extends CharacterBody3D
## ЖИРАФА — Образец №007 [code-05 + lev-03]
## «Та, что доставала до верхних полок.»
## POSING: стоит среди чучел. STALK: идёт, когда луч фонаря не на ней.
## CHASE: в темноте ближе 6 м. Поимка — смерть.

enum State {POSING, STALK, WINDUP, CHASE}

const STALK_SPEED := 1.55
const CHASE_SPEED := 4.4
const CATCH_DIST := 1.15
const KILL_SWITCH := true  # qa-08: урон включён

var state := State.POSING
var spots: Array[Vector3] = []
var target_spot := Vector3.ZERO
var player: CharacterBody3D
var creak_timer := 0.0
var windup_t := 0.0
var sting_played := false
var dread := 0.0
var frozen := false

var creak: AudioStreamPlayer3D
var neck: Node3D

func _ready() -> void:
	add_to_group("specimen")
	_build_body()
	rotation.y = randf_range(0, TAU)

func setup(p_player: CharacterBody3D, p_spots: Array[Vector3]) -> void:
	player = p_player
	spots = p_spots
	_pick_spot()

func _build_body() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = load("res://assets/textures/giraffe_skin.png")
	skin.roughness = 1.0
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.70, 0.68, 0.62)
	coat.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05)
	# ноги — длинные, тонкие
	for leg_x in [-0.16, 0.16]:
		for leg_z in [-0.12, 0.12]:
			var leg := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = 0.055; m.bottom_radius = 0.04; m.height = 1.9
			leg.mesh = m
			leg.material_override = skin
			leg.position = Vector3(leg_x, 0.95, leg_z)
			add_child(leg)
	# халат (грязно-белый бокс)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.52, 0.85, 0.3)
	body.mesh = bm
	body.material_override = coat
	body.position = Vector3(0, 2.35, 0)
	add_child(body)
	# шея — узкий вытянутый цилиндр
	neck = Node3D.new()
	neck.position = Vector3(0, 2.75, 0)
	add_child(neck)
	var neck_m := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.07; nm.bottom_radius = 0.13; nm.height = 1.65
	neck_m.mesh = nm
	neck_m.material_override = skin
	neck_m.position = Vector3(0, 0.82, 0)
	neck.add_child(neck_m)
	# голова
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.16, 0.22, 0.34)
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 1.72, -0.12)
	neck.add_child(head)
	for ex in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.022; em.height = 0.044
		eye.mesh = em
		eye.material_override = dark
		eye.position = Vector3(ex, 1.76, -0.26)
		neck.add_child(eye)
	# капсула коллизии
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42; cap.height = 3.6
	shape.shape = cap
	shape.position = Vector3(0, 1.8, 0)
	add_child(shape)
	# позиционный звук скрипов
	creak = AudioStreamPlayer3D.new()
	creak.name = "CreakPlayer"
	creak.max_distance = 26.0
	creak.unit_size = 7.0
	add_child(creak)

func _physics_process(delta: float) -> void:
	if frozen or player == null or not is_instance_valid(player):
		return
	var to_player: Vector3 = player.global_position - global_position
	var dist := to_player.length()
	var focus: Vector3 = player.global_position + Vector3.UP * 1.6
	var lit: bool = player.lit_sees(global_position + Vector3.UP * 2.6, 0.55)
	dread = clamp(1.0 - dist / 16.0, 0.0, 1.0)

	match state:
		State.POSING:
			_sway(delta)
			if dist < 26.0 and not lit:
				state = State.STALK
		State.STALK:
			if lit:
				state = State.POSING
				_pick_spot_near_player()
			else:
				_walk_towards(player.global_position, STALK_SPEED, delta)
				creak_timer -= delta
				if creak_timer <= 0.0:
					creak_timer = randf_range(1.6, 3.4)
					Game.play_rand_at(self, "res://assets/audio/creak_%d.wav", 4, -8.0, 26.0)
				if dist < 2.6:
					state = State.WINDUP
					windup_t = 1.1
				elif dist < 7.0 and not player.flashlight_on:
					state = State.CHASE
					sting_played = false
		State.WINDUP:
			# нависает: замерев, вытягивает шею
			neck.scale.y = lerpf(neck.scale.y, 1.25, 4 * delta)
			windup_t -= delta
			if randf() < 0.12:
				Game.play_rand_at(self, "res://assets/audio/creak_%d.wav", 4, -4.0, 26.0)
			if lit:
				state = State.STALK
				neck.scale.y = 1.0
			elif windup_t <= 0.0:
				state = State.CHASE
				sting_played = false
		State.CHASE:
			neck.scale.y = lerpf(neck.scale.y, 1.0, 3 * delta)
			if not sting_played:
				sting_played = true
				Game.play_ui("res://assets/audio/scare_sting.wav", -6.0)
			_walk_towards(player.global_position, CHASE_SPEED, delta)
			if lit and dist > 4.0:
				state = State.STALK
			if dist < CATCH_DIST and KILL_SWITCH:
				_catch()
	# сердцебиение игрока громче, когда она рядом
	player.set_heartbeat(dread)

func _sway(delta: float) -> void:
	rotation.y += sin(Time.get_ticks_msec() / 3400.0) * 0.15 * delta

func _walk_towards(target: Vector3, speed: float, delta: float) -> void:
	var dir := (target - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	# объезд препятствий: три коротких щупа
	var forward := -global_transform.basis.z
	if dir.dot(forward) < 0.98:
		rotate_y(sign(dir.cross(forward).y) * clamp(3.2 * delta, 0, 0.12))
	velocity = forward * speed
	if not is_on_floor(): velocity.y = -4.0
	move_and_slide()

func _pick_spot() -> void:
	if spots.is_empty(): return
	target_spot = spots[randi() % spots.size()]
	if global_position.distance_to(target_spot) > 0.6:
		look_at(target_spot, Vector3.UP)

func _pick_spot_near_player() -> void:
	if spots.is_empty() or player == null: return
	var best := spots[0]
	var best_d := 1e9
	for s in spots:
		var d: float = s.distance_to(player.global_position)
		if d < best_d and s.distance_to(global_position) > 2.0:
			best_d = d; best = s
	target_spot = best
	if global_position.distance_to(best) > 0.6:
		look_at(best, Vector3.UP)

func _catch() -> void:
	frozen = true
	player.frozen = true
	Game.died.emit()

func respawn_after_death() -> void:
	## qa-08: после смерти игрока уходит в дальний конец музея
	frozen = false
	state = State.POSING
	neck.scale.y = 1.0
	var far := global_position
	var best_d := -1.0
	if player:
		for s in spots:
			var d: float = s.distance_to(player.global_position)
			if d > best_d:
				best_d = d; far = s
	global_position = far + Vector3(0, 0.1, 0)
	_pick_spot()
