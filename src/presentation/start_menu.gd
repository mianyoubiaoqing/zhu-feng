class_name StartMenu
extends Control

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/level_select.tscn"
@export_range(0.05, 1.0, 0.05) var transition_duration := 0.22

@export_category("Runtime Debug (read only)")
@export var debug_title_texture_ready := false
@export var debug_transition_locked := false
@export_multiline var debug_last_action := ""

@onready var _title: TextureRect = $MenuPanel/Title
@onready var _start_button: Button = $MenuPanel/Start
@onready var _exit_button: Button = $MenuPanel/Exit
@onready var _fade: ColorRect = $Fade
@onready var _confirm: AudioStreamPlayer = $Confirm
@onready var _left_blades: TextureRect = $LeftFanBlades
@onready var _right_blades: TextureRect = $RightFanBlades


func _ready() -> void:
	debug_title_texture_ready = _title.texture != null
	_start_button.pressed.connect(_on_start_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_start_button.grab_focus()


func _process(delta: float) -> void:
	_left_blades.rotation += delta * 0.8
	_right_blades.rotation -= delta * 0.65


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not debug_transition_locked:
		_on_exit_pressed()


func _on_start_pressed() -> void:
	if debug_transition_locked:
		return
	if not ResourceLoader.exists(gameplay_scene_path):
		debug_last_action = "ERROR | 找不到游戏场景：%s" % gameplay_scene_path
		return
	debug_transition_locked = true
	debug_last_action = "START | %s" % gameplay_scene_path
	_start_button.disabled = true
	_exit_button.disabled = true
	if DisplayServer.get_name() != "headless":
		_confirm.play()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, transition_duration)
	await tween.finished
	var error := get_tree().change_scene_to_file(gameplay_scene_path)
	if error != OK:
		debug_last_action = "ERROR | 场景切换失败：%d" % error
		debug_transition_locked = false
		_start_button.disabled = false
		_exit_button.disabled = false


func _on_exit_pressed() -> void:
	if debug_transition_locked:
		return
	debug_transition_locked = true
	debug_last_action = "EXIT"
	get_tree().quit()
