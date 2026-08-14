extends Node2D

@onready var session: GameSessionNode = $Session
@onready var build_controller: BuildControllerNode = $BuildController
@onready var board_view: BoardView = $BoardView
@onready var cargo_view: CargoView = $CargoView
@onready var audio_director: AudioDirector = $AudioDirector
@onready var budget_label: Label = $HUD/Sidebar/Budget
@onready var message_label: Label = $HUD/Message
@onready var runtime_label: Label = $HUD/RuntimeStats


func _ready() -> void:
	build_controller.interaction_message.connect(_set_message)
	build_controller.action_performed.connect(audio_director.play_build_action)
	session.state_changed.connect(_refresh_hud)
	cargo_view.animation_finished.connect(_on_cargo_animation_finished)
	$HUD/Sidebar/Bend.pressed.connect(_select_device.bind(GameRules.DeviceKind.BEND))
	$HUD/Sidebar/Blocker.pressed.connect(_select_device.bind(GameRules.DeviceKind.BLOCKER))
	$HUD/Sidebar/Valve.pressed.connect(_select_device.bind(GameRules.DeviceKind.ONE_WAY_VALVE))
	$HUD/Sidebar/Undo.pressed.connect(_on_undo)
	$HUD/Sidebar/Start.pressed.connect(_on_start)
	$HUD/Sidebar/Build.pressed.connect(_on_return_to_build)
	$HUD/Sidebar/Retry.pressed.connect(_on_start)
	$HUD/Sidebar/Menu.pressed.connect(_on_return_to_menu)
	if not session.is_initialized():
		_set_message(session.debug_last_error)
		return
	cargo_view.reset_to(session.level().start)
	_select_device(GameRules.DeviceKind.BEND)
	_refresh_hud()


func _process(_delta: float) -> void:
	if not session.is_initialized():
		return
	runtime_label.text = "Remote Inspector：Session / BuildController / BoardView / CargoView / AudioDirector\n风格 %d · 冲突 %d · 闭环 %d · 路线步 %d · 美术 %d/35 · 音频 %d/15" % [
		session.debug_wind_cell_count,
		session.debug_conflict_count,
		session.debug_loop_cell_count,
		cargo_view.debug_route_index,
		board_view.debug_loaded_art_assets + 1,
		audio_director.debug_loaded_audio_assets,
	]


func _select_device(kind: int) -> void:
	build_controller.select_device(kind)
	audio_director.play_ui_confirm()
	_refresh_hud()


func _on_undo() -> void:
	var succeeded := session.undo_action()
	audio_director.play_undo(succeeded)
	if succeeded:
		_set_message("已撤销。剩余预算：%d" % session.remaining_budget())
	else:
		_set_message("没有可撤销的施工操作。")


func _on_start() -> void:
	if not session.is_initialized():
		return
	board_view.clear_result()
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
	_set_message("已返回建造，布局与风机朝向保持不变。")


func _on_return_to_menu() -> void:
	audio_director.stop_all_audio()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _on_cargo_animation_finished(result: SimulationResult) -> void:
	board_view.show_result(result)
	audio_director.play_result(result)
	if result.succeeded:
		_set_message("通关%s" % ("（精简设计）" if result.efficient else ""))
	else:
		_set_message(result.failure_label())


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
	$HUD/Sidebar/Undo.disabled = not in_build
	$HUD/Sidebar/Build.disabled = in_build


func _set_message(message: String) -> void:
	message_label.text = message
