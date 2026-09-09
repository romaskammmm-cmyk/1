class_name SeedPickup
extends Pickup
## Семя-возражение из банки лаборатории: отдельная логика активации.

var spec_key := ""
var pick_diary := ""

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func setup_key(key: String, pos: Vector3, prompt_text: String, d_line: String) -> void:
	spec_key = key
	flag = "specimen_taken_" + key
	prompt = prompt_text
	pick_diary = d_line
	position = pos
	# семечко: маленькая светящаяся сфера в банке
	var glow_m := StandardMaterial3D.new()
	glow_m.albedo_color = Color(0.25, 0.8, 0.45)
	glow_m.emission_enabled = true
	glow_m.emission = Color(0.3, 1.0, 0.55)
	glow_m.emission_energy_multiplier = 0.9
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05; sm.height = 0.1
	m.mesh = sm
	m.material_override = glow_m
	add_child(m)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.14, 0.14, 0.14)
	cs.shape = sh
	add_child(cs)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.6)
	l.light_energy = 0.8
	l.omni_range = 1.8
	add_child(l)

func activate(player) -> void:
	if Game.has(flag):
		return
	Game.setf(flag)
	Game.counters["seeds"] = Game.counters.get("seeds", 0) + 1
	if pick_diary != "":
		Game.diary_add_cond(flag, "water", pick_diary)
	AudioMgr.play("water", -2.0, 0.9)
	AudioMgr.whisper_random(true)
	var zone: Node = get_tree().get_first_node_in_group("zone_c2")
	if zone and zone.has_method("on_seed_taken"):
		zone.call("on_seed_taken", spec_key)
	queue_free()
