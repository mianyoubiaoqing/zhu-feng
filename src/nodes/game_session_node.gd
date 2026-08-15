class_name GameSessionNode
extends Node

signal state_changed
signal preview_changed(solution: WindSolution)
signal result_ready(result: SimulationResult)

@export_category("Configuration")
@export var level_definition: LevelDefinition
@export var use_demo_level_when_empty := true

@export_category("Runtime Debug (read only)")
@export var debug_level_id := ""
@export var debug_phase := "UNINITIALIZED"
@export var debug_spent_budget := 0
@export var debug_remaining_budget := 0
@export var debug_device_count := 0
@export var debug_wind_cell_count := 0
@export var debug_peak_wind_strength := 0
@export var debug_conflict_count := 0
@export var debug_loop_cell_count := 0
@export var debug_powered_turbines := PackedStringArray()
@export_multiline var debug_last_error := ""
@export_multiline var debug_last_result := ""

var current_wind: WindSolution
var current_result: SimulationResult
var _session := GameSession.new()
var _initialized := false


func _ready() -> void:
	initialize()


func initialize() -> bool:
	if level_definition == null and use_demo_level_when_empty:
		var game_flow := get_node_or_null("/root/GameFlow")
		level_definition = game_flow.call("selected_level") if game_flow != null else DemoLevels.build_vertical_slice()
	if level_definition == null:
		debug_last_error = "未配置 LevelDefinition"
		return false
	_initialized = _session.load_level(level_definition)
	if not _initialized:
		debug_last_error = _session.last_error()
		return false
	refresh_preview()
	return true


func place_device(kind: int, cell: Vector2i, orientation: int = GameRules.Direction.UP) -> bool:
	return _finish_build_action(_session.place_device(kind, cell, orientation))


func rotate_at(cell: Vector2i) -> bool:
	return _finish_build_action(_session.rotate_at(cell))


func remove_device(cell: Vector2i) -> bool:
	return _finish_build_action(_session.remove_device(cell))


func undo_action() -> bool:
	return _finish_build_action(_session.undo())


func refresh_preview() -> WindSolution:
	current_wind = _session.preview()
	current_result = null
	_update_debug()
	preview_changed.emit(current_wind)
	state_changed.emit()
	return current_wind


func start_test() -> SimulationResult:
	current_wind = _session.preview()
	current_result = _session.start_test()
	_update_debug()
	preview_changed.emit(current_wind)
	result_ready.emit(current_result)
	state_changed.emit()
	return current_result


func return_to_build() -> void:
	_session.return_to_build()
	current_result = null
	_update_debug()
	state_changed.emit()


func is_initialized() -> bool:
	return _initialized


func level() -> LevelDefinition:
	return _session.level()


func phase() -> int:
	return _session.phase()


func spent_budget() -> int:
	return _session.spent_budget()


func remaining_budget() -> int:
	return _session.remaining_budget()


func fan_direction(cell: Vector2i) -> int:
	return _session.fan_direction(cell)


func device_at(cell: Vector2i) -> PlacedDevice:
	return _session.device_at(cell)


func devices() -> Array[PlacedDevice]:
	return _session.devices()


func can_place_device(kind: int, cell: Vector2i) -> bool:
	return _session.can_place_device(kind, cell)


func last_error() -> String:
	return _session.last_error()


func _finish_build_action(succeeded: bool) -> bool:
	debug_last_error = "" if succeeded else _session.last_error()
	if succeeded:
		refresh_preview()
	else:
		_update_debug()
	return succeeded


func _update_debug() -> void:
	if not _initialized:
		return
	debug_level_id = String(level_definition.level_id)
	debug_phase = "BUILD" if _session.phase() == GameRules.Phase.BUILD else "RESULT"
	debug_spent_budget = _session.spent_budget()
	debug_remaining_budget = _session.remaining_budget()
	debug_device_count = _session.devices().size()
	debug_wind_cell_count = current_wind.cells().size() if current_wind != null else 0
	debug_peak_wind_strength = 0
	if current_wind != null:
		for cell in current_wind.cells():
			debug_peak_wind_strength = maxi(debug_peak_wind_strength, current_wind.strength_at(cell))
	debug_conflict_count = current_wind.conflict_cells.size() if current_wind != null else 0
	debug_loop_cell_count = current_wind.loop_cells.size() if current_wind != null else 0
	debug_powered_turbines.clear()
	if current_wind != null:
		for turbine_id in current_wind.powered_turbine_ids:
			debug_powered_turbines.append(String(turbine_id))
	if current_result == null:
		debug_last_result = ""
	elif current_result.succeeded:
		debug_last_result = "SUCCESS | %s | route=%d | efficient=%s | turbines=%s | fans_rotated=%d | device_kinds=%d" % [
			current_result.route_style_label(),
			current_result.route.size(),
			current_result.efficient,
			current_result.all_turbines_powered,
			current_result.rotated_fan_count,
			current_result.device_kind_count,
		]
	else:
		debug_last_result = "FAIL | %s | cell=%s | route=%d" % [current_result.failure_label(), current_result.failure_cell, current_result.route.size()]
