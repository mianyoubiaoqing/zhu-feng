class_name CargoView
extends Node2D

signal animation_finished(result: SimulationResult)

@export_category("Presentation")
@export var board_origin := Vector2(390, 210)
@export var cell_size := 96.0
@export_range(0.05, 1.0, 0.05) var step_duration := 0.30
@export var cargo_radius := 18.0

@export_category("Runtime Debug (read only)")
@export var debug_animating := false
@export var debug_route_length := 0
@export var debug_route_index := 0
@export var debug_step_progress := 0.0
@export var debug_logical_cell := Vector2i(-1, -1)
@export_multiline var debug_outcome := ""

var _result: SimulationResult
var _route_time := 0.0


func _ready() -> void:
	queue_redraw()


func play_result(result: SimulationResult) -> void:
	_result = result
	debug_route_length = result.route.size()
	debug_route_index = 0
	debug_step_progress = 0.0
	_route_time = 0.0
	debug_animating = result.route.size() > 1
	debug_logical_cell = result.route[0] if not result.route.is_empty() else Vector2i(-1, -1)
	position = cell_center(debug_logical_cell)
	debug_outcome = "PENDING"
	if not debug_animating:
		_finish_animation.call_deferred()
	queue_redraw()


func reset_to(cell: Vector2i) -> void:
	_result = null
	debug_animating = false
	debug_route_length = 0
	debug_route_index = 0
	debug_step_progress = 0.0
	debug_logical_cell = cell
	debug_outcome = ""
	position = cell_center(cell)
	queue_redraw()


func is_animating() -> bool:
	return debug_animating


func cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _process(delta: float) -> void:
	if not debug_animating or _result == null:
		return
	_route_time += delta
	debug_step_progress = minf(_route_time / step_duration, 1.0)
	position = cell_center(_result.route[debug_route_index]).lerp(
		cell_center(_result.route[debug_route_index + 1]),
		debug_step_progress
	)
	if debug_step_progress >= 1.0:
		debug_route_index += 1
		debug_logical_cell = _result.route[debug_route_index]
		_route_time = 0.0
		debug_step_progress = 0.0
		if debug_route_index >= _result.route.size() - 1:
			_finish_animation()


func _finish_animation() -> void:
	if _result == null:
		return
	debug_animating = false
	debug_outcome = "SUCCESS" if _result.succeeded else _result.failure_label()
	animation_finished.emit(_result)


func _draw() -> void:
	draw_circle(Vector2.ZERO, cargo_radius, Color("f6a33b"))
	draw_circle(Vector2.ZERO, cargo_radius, Color("8f5a20"), false, 2.0)
