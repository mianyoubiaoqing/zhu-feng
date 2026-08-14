class_name LevelSelect
extends Control

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/main.tscn"
@export_file("*.tscn") var menu_scene_path := "res://scenes/start_menu.tscn"
@export_file("*.tscn") var editor_scene_path := "res://scenes/level_editor.tscn"
@export_range(0.05, 1.0, 0.05) var transition_duration := 0.18

@export_category("Runtime Debug (read only)")
@export var debug_level_count := 0
@export var debug_selected_index := -1
@export var debug_transition_locked := false
@export_multiline var debug_last_action := ""

@onready var _grid: GridContainer = $LevelGrid
@onready var _hover_info: Label = $HoverInfo
@onready var _progress: Label = $Progress
@onready var _back: Button = $Back
@onready var _editor: Button = $Editor
@onready var _fade: ColorRect = $Fade
@onready var _confirm: AudioStreamPlayer = $Confirm
@onready var _game_flow: Node = get_node("/root/GameFlow")
var _level_buttons: Array[Button] = []


func _ready() -> void:
	_build_level_cards()
	_back.pressed.connect(_on_back_pressed)
	_editor.pressed.connect(_on_editor_pressed)
	_refresh_progress()
	if not _level_buttons.is_empty():
		_level_buttons[_game_flow.get("selected_level_index")].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not debug_transition_locked:
		_on_back_pressed()


func _build_level_cards() -> void:
	var levels := DemoLevels.all_levels()
	debug_level_count = levels.size()
	for index in levels.size():
		var level := levels[index]
		var completed := _game_flow.call("is_completed", index) as bool
		var button := Button.new()
		button.name = "Level%02d" % (index + 1)
		button.custom_minimum_size = Vector2(480, 220)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color("20343b"))
		button.add_theme_color_override("font_hover_color", Color("20343b"))
		button.add_theme_color_override("font_focus_color", Color("20343b"))
		button.add_theme_stylebox_override("normal", _card_style(Color("fff9e5"), Color("40545a"), 3))
		button.add_theme_stylebox_override("hover", _card_style(Color("fff0bd"), Color("299083"), 5))
		button.add_theme_stylebox_override("focus", _card_style(Color("fff0bd"), Color("299083"), 5))
		button.add_theme_stylebox_override("pressed", _card_style(Color("ead092"), Color("40545a"), 4))
		button.text = "%02d｜%s%s\n\n%s\n预算 %d · 精简目标 %d" % [
			index + 1,
			level.display_name,
			"  ✓" if completed else "",
			level.objective,
			level.budget,
			level.efficient_budget,
		]
		button.tooltip_text = level.teaching_tip
		button.pressed.connect(_on_level_pressed.bind(index))
		button.mouse_entered.connect(_on_level_hovered.bind(index))
		_grid.add_child(button)
		_level_buttons.append(button)


func _on_level_hovered(index: int) -> void:
	var level := DemoLevels.build_level(index)
	_hover_info.text = "施工提示：%s" % level.teaching_tip


func _on_level_pressed(index: int) -> void:
	if debug_transition_locked or not (_game_flow.call("select_level", index) as bool):
		return
	debug_selected_index = index
	debug_transition_locked = true
	debug_last_action = "LEVEL %02d | %s" % [index + 1, DemoLevels.build_level(index).level_id]
	_set_buttons_disabled(true)
	if DisplayServer.get_name() != "headless":
		_confirm.play()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, transition_duration)
	await tween.finished
	var error := get_tree().change_scene_to_file(gameplay_scene_path)
	if error != OK:
		debug_last_action = "ERROR | 场景切换失败：%d" % error
		debug_transition_locked = false
		_set_buttons_disabled(false)


func _on_back_pressed() -> void:
	if debug_transition_locked:
		return
	debug_transition_locked = true
	debug_last_action = "BACK"
	get_tree().change_scene_to_file(menu_scene_path)


func _on_editor_pressed() -> void:
	if debug_transition_locked:
		return
	debug_transition_locked = true
	debug_last_action = "EDITOR"
	var error := get_tree().change_scene_to_file(editor_scene_path)
	if error != OK:
		debug_last_action = "ERROR | 编辑器场景切换失败：%d" % error
		debug_transition_locked = false


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _level_buttons:
		button.disabled = disabled
	_back.disabled = disabled
	_editor.disabled = disabled


func _refresh_progress() -> void:
	_progress.text = "已完成 %d / %d · 所有关卡均可直接选择" % [_game_flow.call("completed_count"), DemoLevels.LEVEL_COUNT]


func _card_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	style.shadow_color = Color(0.08, 0.12, 0.13, 0.16)
	style.shadow_size = 8
	return style
