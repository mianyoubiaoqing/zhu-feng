extends Node2D

const BOARD_AREA := Rect2(390, 135, 1100, 700)
const MIN_CELL_SIZE := 88.0
const MAX_CELL_SIZE := 140.0

@onready var session: GameSessionNode = $Session
@onready var build_controller: BuildControllerNode = $BuildController
@onready var board_view: BoardView = $BoardView
@onready var cargo_view: CargoView = $CargoView
@onready var audio_director: AudioDirector = $AudioDirector
@onready var sidebar: Panel = $HUD/Sidebar
@onready var budget_label: Label = $HUD/Sidebar/Budget
@onready var message_label: Label = $HUD/Message
@onready var runtime_label: Label = $HUD/RuntimeStats
@onready var level_title_label: Label = $HUD/Title
@onready var level_subtitle_label: Label = $HUD/Subtitle
@onready var next_button: Button = $HUD/Next
@onready var bend_button: Button = $HUD/Sidebar/Bend
@onready var blocker_button: Button = $HUD/Sidebar/Blocker
@onready var valve_button: Button = $HUD/Sidebar/Valve
@onready var status_banner: Panel = $HUD/StatusBanner
@onready var status_label: Label = $HUD/StatusBanner/Label
@onready var result_panel: Panel = $HUD/ResultPanel
@onready var result_title: Label = $HUD/ResultPanel/Title
@onready var result_body: Label = $HUD/ResultPanel/Body
@onready var cost_pop: Label = $HUD/CostPop
@onready var _game_flow: Node = get_node("/root/GameFlow")
var _level_completed := false
var _last_spent_budget := 0
var _status_tween: Tween
var _result_tween: Tween
var _cost_tween: Tween
var _sidebar_tween: Tween


func _ready() -> void:
	build_controller.interaction_message.connect(_set_message)
	build_controller.action_performed.connect(audio_director.play_build_action)
	build_controller.action_performed.connect(_on_build_action_feedback)
	session.state_changed.connect(_refresh_hud)
	cargo_view.animation_finished.connect(_on_cargo_animation_finished)
	$HUD/Sidebar/Bend.pressed.connect(_select_device.bind(GameRules.DeviceKind.BEND))
	$HUD/Sidebar/Blocker.pressed.connect(_select_device.bind(GameRules.DeviceKind.BLOCKER))
	$HUD/Sidebar/Valve.pressed.connect(_select_device.bind(GameRules.DeviceKind.ONE_WAY_VALVE))
	$HUD/Sidebar/Undo.pressed.connect(_on_undo)
	$HUD/Sidebar/Start.pressed.connect(_on_start)
	$HUD/Sidebar/Build.pressed.connect(_on_return_to_build)
	$HUD/Sidebar/Retry.pressed.connect(_on_start)
	$HUD/LevelSelect.pressed.connect(_on_return_to_level_select)
	next_button.pressed.connect(_on_next_level)
	if not session.is_initialized():
		_set_message(session.debug_last_error)
		return
	_configure_board_geometry()
	_last_spent_budget = session.spent_budget()
	cargo_view.reset_to(session.level().start)
	level_title_label.text = "筑风 · 第%02d关｜%s" % [_game_flow.get("selected_level_index") + 1, session.level().display_name]
	level_subtitle_label.text = "%s\n提示：%s" % [session.level().objective, session.level().teaching_tip]
	_select_device(GameRules.DeviceKind.BEND)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		runtime_label.visible = not runtime_label.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not session.is_initialized() or not runtime_label.visible:
		return
	runtime_label.text = "Remote Inspector：Session / BuildController / BoardView / CargoView / AudioDirector\n风格 %d · 冲突 %d · 闭环 %d · 路线步 %d · 美术 %d/41 · 音频 %d/15" % [
		session.debug_wind_cell_count,
		session.debug_conflict_count,
		session.debug_loop_cell_count,
		cargo_view.debug_route_index,
		board_view.debug_loaded_art_assets + 7,
		audio_director.debug_loaded_audio_assets,
	]


func _select_device(kind: int) -> void:
	build_controller.select_device(kind)
	audio_director.play_ui_confirm()
	bend_button.button_pressed = kind == GameRules.DeviceKind.BEND
	blocker_button.button_pressed = kind == GameRules.DeviceKind.BLOCKER
	valve_button.button_pressed = kind == GameRules.DeviceKind.ONE_WAY_VALVE
	_refresh_hud()


func _on_build_action_feedback(action: StringName, succeeded: bool) -> void:
	board_view.flash_action(build_controller.debug_last_clicked_cell, succeeded, action)
	var current_spent := session.spent_budget()
	var delta := current_spent - _last_spent_budget
	_last_spent_budget = current_spent
	if succeeded and delta != 0:
		_animate_cost_delta(delta)
	elif not succeeded:
		_show_status("施工受阻", Color("e45e52"), 0.65)


func _on_undo() -> void:
	var spent_before := session.spent_budget()
	var succeeded := session.undo_action()
	audio_director.play_undo(succeeded)
	if succeeded:
		var delta := session.spent_budget() - spent_before
		_last_spent_budget = session.spent_budget()
		if delta != 0:
			_animate_cost_delta(delta)
		_show_status("已撤销", Color("36a6a6"), 0.55)
		_set_message("已撤销。剩余预算：%d" % session.remaining_budget())
	else:
		_show_status("没有可撤销操作", Color("e45e52"), 0.65)
		_set_message("没有可撤销的施工操作。")


func _on_start() -> void:
	if not session.is_initialized():
		return
	_hide_result_panel()
	board_view.clear_result()
	_level_completed = false
	_show_status("风路启动", Color("36a6a6"), 0.85)
	_set_sidebar_active(false)
	var result := session.start_test()
	audio_director.start_test(result.powered_turbine_ids.size())
	cargo_view.play_result(result)
	_set_message("正在测试风路……")


func _on_return_to_build() -> void:
	if not session.is_initialized():
		return
	session.return_to_build()
	audio_director.stop_wind()
	audio_director.play_ui_confirm()
	cargo_view.reset_to(session.level().start)
	board_view.clear_result()
	_hide_result_panel()
	_set_sidebar_active(true)
	_show_status("返回施工", Color("795238"), 0.65)
	_set_message("已返回建造，布局与风机朝向保持不变。")


func _on_return_to_level_select() -> void:
	audio_director.stop_all_audio()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_next_level() -> void:
	if not _level_completed:
		return
	audio_director.stop_all_audio()
	if _game_flow.call("select_next_level") as bool:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_cargo_animation_finished(result: SimulationResult) -> void:
	board_view.show_result(result)
	audio_director.play_result(result)
	if result.succeeded:
		_level_completed = true
		_game_flow.call("mark_selected_completed")
		_set_message("通关%s" % ("（精简设计）" if result.efficient else ""))
		_show_status("风种抵达终点", Color("d89f2b"), 1.1)
	else:
		_set_message(result.failure_label())
		_show_status("风路中断", Color("e45e52"), 1.0)
		_shake_world()
	_show_result_panel(result)
	_set_sidebar_active(true)
	_refresh_hud()


func _refresh_hud() -> void:
	if not session.is_initialized():
		return
	budget_label.text = "施工 %d / %d\n精简目标 ≤ %d\n当前装置：%s" % [
		session.spent_budget(),
		session.level().budget,
		session.level().efficient_budget,
		build_controller.debug_selected_device,
	]
	var in_build := session.phase() == GameRules.Phase.BUILD
	build_controller.input_enabled = in_build
	for button in [bend_button, blocker_button, valve_button, $HUD/Sidebar/Start]:
		button.disabled = not in_build
	$HUD/Sidebar/Undo.disabled = not in_build
	$HUD/Sidebar/Build.disabled = in_build
	$HUD/Sidebar/Retry.disabled = in_build
	next_button.disabled = not _level_completed
	next_button.text = "完成委托" if _game_flow.get("selected_level_index") >= DemoLevels.LEVEL_COUNT - 1 else "下一关"


func _set_message(message: String) -> void:
	message_label.text = message


func _configure_board_geometry() -> void:
	var level_size := Vector2(session.level().size)
	var size := floorf(minf(BOARD_AREA.size.x / level_size.x, BOARD_AREA.size.y / level_size.y))
	size = clampf(size, MIN_CELL_SIZE, MAX_CELL_SIZE)
	var board_pixel_size := level_size * size
	var origin := BOARD_AREA.position + (BOARD_AREA.size - board_pixel_size) * 0.5
	origin = origin.round()
	board_view.configure_geometry(origin, size)
	cargo_view.configure_geometry(origin, size)
	build_controller.configure_geometry(origin, size)


func _animate_cost_delta(delta: int) -> void:
	if _cost_tween != null and _cost_tween.is_valid():
		_cost_tween.kill()
	cost_pop.text = ("- %d" if delta > 0 else "+ %d") % absi(delta)
	cost_pop.add_theme_color_override("font_color", Color("e45e52") if delta > 0 else Color("299083"))
	cost_pop.position = Vector2(106, 418)
	cost_pop.modulate = Color.WHITE
	cost_pop.visible = true
	_cost_tween = create_tween()
	_cost_tween.set_parallel(true)
	_cost_tween.tween_property(cost_pop, "position:y", 374.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cost_tween.tween_property(cost_pop, "modulate:a", 0.0, 0.55).set_delay(0.12)
	_cost_tween.chain().tween_callback(cost_pop.hide)


func _show_status(text: String, color: Color, duration: float) -> void:
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	status_banner.modulate = Color(1, 1, 1, 0)
	status_banner.visible = true
	_status_tween = create_tween()
	_status_tween.tween_property(status_banner, "modulate:a", 1.0, 0.16)
	_status_tween.tween_interval(duration)
	_status_tween.tween_property(status_banner, "modulate:a", 0.0, 0.22)
	_status_tween.tween_callback(status_banner.hide)


func _show_result_panel(result: SimulationResult) -> void:
	if _result_tween != null and _result_tween.is_valid():
		_result_tween.kill()
	result_title.text = "施工完成" if result.succeeded else "风路未接通"
	if result.succeeded:
		result_title.add_theme_color_override("font_color", Color("299083"))
		result_body.text = "本次施工：%d / %d\n精简目标：≤ %d\n%s" % [
			session.spent_budget(),
			session.level().budget,
			session.level().efficient_budget,
			"已达成精简方案" if result.efficient else "仍可返回施工压缩预算",
		]
	else:
		result_title.add_theme_color_override("font_color", Color("e45e52"))
		result_body.text = "%s\n红色脉冲已标出中断位置。\n返回施工后可保留当前布局继续调整。" % result.failure_label()
	result_panel.visible = true
	result_panel.pivot_offset = result_panel.size * 0.5
	result_panel.scale = Vector2(0.92, 0.92)
	result_panel.modulate = Color(1, 1, 1, 0)
	_result_tween = create_tween()
	_result_tween.set_parallel(true)
	_result_tween.tween_property(result_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_result_tween.tween_property(result_panel, "modulate:a", 1.0, 0.18)


func _hide_result_panel() -> void:
	if _result_tween != null and _result_tween.is_valid():
		_result_tween.kill()
	result_panel.visible = false


func _set_sidebar_active(active: bool) -> void:
	if _sidebar_tween != null and _sidebar_tween.is_valid():
		_sidebar_tween.kill()
	_sidebar_tween = create_tween()
	_sidebar_tween.tween_property(sidebar, "modulate", Color.WHITE if active else Color(0.72, 0.72, 0.72, 0.82), 0.22)


func _shake_world() -> void:
	var tween := create_tween()
	for offset in [Vector2(-8, 0), Vector2(8, -3), Vector2(-5, 3), Vector2(4, 0), Vector2.ZERO]:
		tween.tween_property(board_view, "position", offset, 0.045)
		tween.parallel().tween_property(cargo_view, "position", cargo_view.position + offset, 0.045)
