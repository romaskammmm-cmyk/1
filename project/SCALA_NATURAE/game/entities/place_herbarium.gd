class_name PlaceHerbarium
extends StaticBody3D
## Место на пьедестале Homo: сюда кладут гербарий Голубя (ключевой акт главы I).

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func get_prompt() -> String:
	if Game.has("placed_herbarium"):
		return ""
	if Game.has("herbarium_pigeon"):
		return "[E] — положить гербарий на пьедестал"
	return "[E] — осмотреть пьедестал"

func activate(player) -> void:
	if not Game.has("herbarium_pigeon"):
		Game.prompt_shown.emit("На пьедестале выгравировано: «HOMO — SPECIMEN EXPECTATUR». Ждёт чего-то, чего в каталоге нет.")
		return
	if Game.has("placed_herbarium"):
		return
	Game.setf("placed_herbarium")
	Game.diary_add("self", Game.get_diary_line("placed_herb"))
	AudioMgr.play("bell", 0.0, 0.92)
	AudioMgr.play("whoosh", -8.0, 0.8)
	var zone: Node = get_tree().get_first_node_in_group("zone_c1")
	if zone and zone.has_method("on_herbarium_placed"):
		zone.call("on_herbarium_placed")
	queue_free()
