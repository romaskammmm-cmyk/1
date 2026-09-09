class_name LampFlicker
extends Node
## Мерцание газовых ламп (лёгкое, «живое»)

var light_node: OmniLight3D = null
var base_energy := 1.0
var phase := 0.0
var t := 0.0

func _ready() -> void:
	if light_node:
		base_energy = light_node.light_energy
	phase = randf() * 20.0
	t = phase
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	if light_node == null:
		return
	t += delta
	var n := sin(t * 6.3 + phase) * 0.02 + sin(t * 23.0 + phase * 2.0) * 0.014
	var drop := 0.0
	# редкие «провалы» пламени
	if sin(t * 0.7 + phase) > 0.985:
		drop = 0.35 * sin(t * 0.7 + phase)
	light_node.light_energy = base_energy * (1.0 + n - drop)
