class_name BuildControllerNode
extends Node

signal interaction_message(message: String)
signal action_performed(action: StringName, succeeded: bool)

@export_category("Node Wiring")
@export_node_path("GameSessionNode") var session_node_path: NodePath = ^"../Session"

@export_category("Board Geometry")
@export var board_origin := Vector2(390, 210)
@export var cell_size := 96.0

@export_category("Build State")
@export_enum("Bend", "Blocker", "One-way Valve") var selected_kind: int = GameRules.DeviceKind.BEND
@export var input_enabled := true

@export_category("Runtime Debug (read only)")
@export var debug_hovered_cell := Vector2i(-1, -1)
@export var debug_last_clicked_cell := Vector2i(-1, -1)
@export var debug_selected_device := "导风板"
@export_multiline var debug_last_interaction := ""

@onready var _session: GameSessionNode = get_node(session_node_path)


func configure_geometry(origin: Vector2, size: float) -> void:
	board_origin = origin
	cell_size = size


func _process(_delta: float) -> void:
	debug_hovered_cell = mouse_to_cell(get_viewport().get_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not event is InputEventMouseButton or not event.pressed:
		return
	if not _session.is_initialized() or _session.phase() != GameRules.Phase.BUILD:
		return
	var mouse_event := event as InputEventMouseButton
	var cell := mouse_to_cell(mouse_event.position)
	if not _session.level().contains(cell):
		return
	debug_last_clicked_cell = cell

	var succeeded := false
	var action := &"place"
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		action = &"remove"
		succeeded = _session.remove_device(cell)
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if _session.level().fan_at(cell) != null or _session.device_at(cell) != null:
			action = &"rotate"
			succeeded = _session.rotate_at(cell)
		else:
			succeeded = _session.place_device(selected_kind, cell)
	else:
		return

	debug_last_interaction = "cell=%s | %s" % [cell, "OK" if succeeded else _session.last_error()]
	interaction_message.emit("剩余预算：%d" % _session.remaining_budget() if succeeded else _session.last_error())
	action_performed.emit(action, succeeded)
	get_viewport().set_input_as_handled()


func select_device(kind: int) -> void:
	selected_kind = kind
	debug_selected_device = device_name(kind)
	debug_last_interaction = "选择装置：%s" % debug_selected_device
	interaction_message.emit(debug_last_interaction)


func mouse_to_cell(mouse: Vector2) -> Vector2i:
	return Vector2i(
		floori((mouse.x - board_origin.x) / cell_size),
		floori((mouse.y - board_origin.y) / cell_size)
	)


static func device_name(kind: int) -> String:
	match kind:
		GameRules.DeviceKind.BEND:
			return "导风板"
		GameRules.DeviceKind.BLOCKER:
			return "挡风板"
		GameRules.DeviceKind.ONE_WAY_VALVE:
			return "单向风阀"
	return "未知装置"
