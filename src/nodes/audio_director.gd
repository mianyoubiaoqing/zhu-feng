class_name AudioDirector
extends Node

@export_category("UI Cues")
@export var confirm_01: AudioStream
@export var confirm_02: AudioStream

@export_category("Build Cues")
@export var place_valid: AudioStream
@export var place_invalid: AudioStream
@export var rotate: AudioStream
@export var remove_refund: AudioStream

@export_category("Simulation Cues")
@export var wind_loop: AudioStream
@export var turbine_start: AudioStream
@export var door_open: AudioStream

@export_category("Result Cues")
@export var failure_collision: AudioStream
@export var failure_stall: AudioStream
@export var failure_fall: AudioStream
@export var success_normal: AudioStream
@export var success_efficient: AudioStream
@export var finale_material: AudioStream

@export_category("Runtime Debug (read only)")
@export var debug_loaded_audio_assets := 0
@export var debug_playback_suppressed := false
@export var debug_wind_requested := false
@export var debug_wind_playing := false
@export_multiline var debug_last_cue := ""
@export_multiline var debug_pipeline_note := "AUD-010 已导入为尾声素材，当前不自动混音播放。"

@onready var _ui_player: AudioStreamPlayer = $UI
@onready var _sfx_player: AudioStreamPlayer = $SFX
@onready var _mechanics_player: AudioStreamPlayer = $Mechanics
@onready var _wind_player: AudioStreamPlayer = $Wind
@onready var _ui_stop_timer: Timer = $UIStopTimer
@onready var _sfx_stop_timer: Timer = $SFXStopTimer
@onready var _mechanics_stop_timer: Timer = $MechanicsStopTimer
@onready var _door_delay_timer: Timer = $DoorDelayTimer
var _confirm_variant := false


func _ready() -> void:
	debug_loaded_audio_assets = _count_loaded_audio_assets()
	debug_playback_suppressed = DisplayServer.get_name() == "headless"
	_wind_player.finished.connect(_on_wind_finished)
	_ui_stop_timer.timeout.connect(_ui_player.stop)
	_sfx_stop_timer.timeout.connect(_sfx_player.stop)
	_mechanics_stop_timer.timeout.connect(_mechanics_player.stop)
	_door_delay_timer.timeout.connect(_on_door_delay_timeout)


func _process(_delta: float) -> void:
	debug_wind_playing = _wind_player.playing


func _exit_tree() -> void:
	stop_all_audio()


func stop_all_audio() -> void:
	for timer in [_ui_stop_timer, _sfx_stop_timer, _mechanics_stop_timer, _door_delay_timer]:
		timer.stop()
	for player in [_ui_player, _sfx_player, _mechanics_player, _wind_player]:
		player.stop()
		player.stream = null


func play_ui_confirm() -> void:
	_confirm_variant = not _confirm_variant
	_play_capped(_ui_player, confirm_02 if _confirm_variant else confirm_01, 0.0, "ui_confirm")


func play_build_action(action: StringName, succeeded: bool) -> void:
	if not succeeded:
		_play_capped(_sfx_player, place_invalid, 0.9, "build_invalid")
		return
	match action:
		&"place":
			_play_capped(_sfx_player, place_valid, 0.0, "place_valid")
		&"rotate":
			_play_capped(_sfx_player, rotate, 1.1, "rotate")
		&"remove":
			_play_capped(_sfx_player, remove_refund, 1.2, "remove_refund")


func play_undo(succeeded: bool) -> void:
	_play_capped(
		_sfx_player,
		remove_refund if succeeded else place_invalid,
		1.0,
		"undo" if succeeded else "undo_invalid"
	)


func start_test(powered_turbines: int) -> void:
	start_wind()
	if powered_turbines > 0:
		_play_capped(_mechanics_player, turbine_start, 2.5, "turbine_start")
		_door_delay_timer.start(0.55)


func start_wind() -> void:
	debug_wind_requested = true
	if wind_loop == null:
		debug_last_cue = "wind_loop_missing"
		return
	if debug_playback_suppressed:
		debug_last_cue = "wind_loop_headless"
		return
	if not _wind_player.playing:
		_wind_player.stream = wind_loop
		_wind_player.play()
	debug_last_cue = "wind_loop"


func stop_wind() -> void:
	debug_wind_requested = false
	_door_delay_timer.stop()
	_wind_player.stop()
	debug_wind_playing = false


func play_result(result: SimulationResult) -> void:
	stop_wind()
	if result.succeeded:
		_play_capped(
			_sfx_player,
			success_efficient if result.efficient else success_normal,
			0.0,
			"success_efficient" if result.efficient else "success_normal"
		)
		return
	var stream := failure_stall
	var cue := "failure_stall"
	match result.failure_reason:
		GameRules.FailureReason.COLLISION, GameRules.FailureReason.CONFLICT:
			stream = failure_collision
			cue = "failure_collision"
		GameRules.FailureReason.PIT:
			stream = failure_fall
			cue = "failure_fall"
	_play_capped(_sfx_player, stream, 1.8, cue)


func play_finale_material() -> void:
	_play_capped(_sfx_player, finale_material, 2.5, "finale_material_preview")


func _play_capped(player: AudioStreamPlayer, stream: AudioStream, max_seconds: float, cue: String) -> void:
	debug_last_cue = cue
	if stream == null:
		debug_last_cue += "_missing"
		return
	if debug_playback_suppressed:
		debug_last_cue += "_headless"
		return
	var stop_timer := _stop_timer_for(player)
	if stop_timer != null:
		stop_timer.stop()
	player.stream = stream
	player.play()
	if max_seconds > 0.0 and stop_timer != null:
		stop_timer.start(max_seconds)


func _on_door_delay_timeout() -> void:
	if debug_wind_requested:
		_play_capped(_sfx_player, door_open, 1.4, "door_open")


func _on_wind_finished() -> void:
	if debug_wind_requested and wind_loop != null:
		_wind_player.play()


func _stop_timer_for(player: AudioStreamPlayer) -> Timer:
	if player == _ui_player:
		return _ui_stop_timer
	if player == _sfx_player:
		return _sfx_stop_timer
	if player == _mechanics_player:
		return _mechanics_stop_timer
	return null


func _count_loaded_audio_assets() -> int:
	var assets: Array[AudioStream] = [
		confirm_01, confirm_02, place_valid, place_invalid, rotate, remove_refund,
		wind_loop, turbine_start, door_open,
		failure_collision, failure_stall, failure_fall,
		success_normal, success_efficient, finale_material,
	]
	var count := 0
	for asset in assets:
		if asset != null:
			count += 1
	return count
