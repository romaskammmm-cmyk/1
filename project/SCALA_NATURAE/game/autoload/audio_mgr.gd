extends Node
## AudioMgr (autoload) — процедурный звук. Файлы WAV генерируются tools/gen_audio.py.
## Все загрузки — с защитой: если файла нет, звук молча пропускается.

var _bus_master := 0
var _pool := []
var _ambient: AudioStreamPlayer = null
var _ambient2: AudioStreamPlayer = null
var _heart: AudioStreamPlayer = null
var _surfaces := {"wood": 0.0, "mud": 0.0, "stone": 0.0}
var _last_step := 0.0

const SND := {
	"step_wood": "res://assets/audio/step_wood.wav",
	"step_mud": "res://assets/audio/step_mud.wav",
	"step_stone": "res://assets/audio/step_stone.wav",
	"tick": "res://assets/audio/tick.wav",
	"page": "res://assets/audio/page.wav",
	"door": "res://assets/audio/door.wav",
	"creak": "res://assets/audio/creak.wav",
	"drone": "res://assets/audio/drone.wav",
	"whisper": "res://assets/audio/whisper0.wav",
	"heart": "res://assets/audio/heart.wav",
	"sting": "res://assets/audio/sting.wav",
	"bell": "res://assets/audio/bell.wav",
	"water": "res://assets/audio/water.wav",
	"whoosh": "res://assets/audio/whoosh.wav",
	"click": "res://assets/audio/click.wav",
}

func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_ambient2 = AudioStreamPlayer.new()
	_ambient2.volume_db = -22.0
	add_child(_ambient2)
	_heart = AudioStreamPlayer.new()
	_heart.volume_db = -14.0
	add_child(_heart)

func _stream(key: String) -> AudioStream:
	if not SND.has(key):
		return null
	var p: String = SND[key]
	if not ResourceLoader.exists(p):
		return null
	return load(p)

func play(key: String, vol := 0.0, pitch := 1.0) -> void:
	var s := _stream(key)
	if s == null: return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = -8.0 + vol
			p.pitch_scale = pitch
			p.play()
			return

func play_heart(intensity := 0.0) -> void:
	_heart.volume_db = -18.0 + intensity * 22.0

## Эмбиент-слои: drone — постоянно, layer2 — периодические шёпоты
func start_ambient() -> void:
	if _ambient.stream == null:
		var s := _stream("drone")
		if s == null: return
		_ambient.stream = s
	_ambient.play()
	_set_drone_pitch(1.0)

func _set_drone_pitch(p: float) -> void:
	if _ambient.playing:
		_ambient.pitch_scale = p

func set_tension(t: float) -> void:
	## 0..1 — приподнимает дрон и шёпот
	_set_drone_pitch(0.96 + t * 0.1)

func whisper_random() -> void:
	if randf() < 0.25:
		play("whisper", -6.0, randf_range(0.9, 1.15))

## шаги: surf: "wood"/"mud"/"stone", state: 0 walk / 1 run
func footstep(surf: String, state: int) -> void:
	var key := "step_wood"
	if surf == "mud": key = "step_mud"
	elif surf == "stone": key = "step_stone"
	play(key, -3.0 if state == 1 else -8.0, randf_range(0.92, 1.1))
