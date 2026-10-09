class_name Sfx
extends Node
## Sound effects: plays assets/sfx/<name>.ogg, or a random one of
## <name>_1.ogg, <name>_2.ogg ...; a pool of players with a per-sound rate
## limit so a hundred kills in one frame don't become noise.

const DIR := "res://assets/sfx/"
const VOICES := 16
## Least seconds between two plays of the same sound (default 0.03).
const MIN_GAP := {coin_pickup = 0.05, hit_flesh = 0.04, enemy_die = 0.05, hero_shot = 0.0,
	coin_pay = 0.04, gate_hit = 0.35, frost_pulse = 0.25, arrow_shot = 0.04}
## Volume trims (dB) after listening on the device; frequent sounds lower.
const GAIN := {coin_pickup = -2.0, hit_flesh = -4.0, enemy_die = -6.0, arrow_shot = -3.0}

var muted := false
var _streams := {}  # name -> Array[AudioStream]
var _last := {}  # name -> time last played
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.push_back(p)
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		# Exported builds list the import remaps; strip back to the .ogg name.
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if not f.ends_with(".ogg"):
			continue
		var base := f.get_basename()
		var parts := base.rsplit("_", true, 1)
		var name := parts[0] if parts.size() == 2 and parts[1].is_valid_int() else base
		var stream: AudioStream = load(DIR + f)
		if stream:
			if not _streams.has(name):
				_streams[name] = []
			if not (_streams[name] as Array).has(stream):
				_streams[name].push_back(stream)


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted or not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < float(MIN_GAP.get(name, 0.03)):
		return
	_last[name] = now
	var list: Array = _streams[name]
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db + float(GAIN.get(name, 0.0))
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()
