class_name BoardView
extends Node2D

@export_category("Node Wiring")
@export_node_path("GameSessionNode") var session_node_path: NodePath = ^"../Session"
@export_node_path("BuildControllerNode") var build_controller_node_path: NodePath = ^"../BuildController"

@export_category("Board Geometry")
@export var board_origin := Vector2(390, 210)
@export var cell_size := 96.0

@export_category("Terrain Art")
@export var ground_texture_1: Texture2D
@export var ground_texture_2: Texture2D
@export var abyss_texture: Texture2D
@export var wall_corner_texture: Texture2D
@export var wall_straight_texture: Texture2D

@export_category("Object Art")
@export var wind_origin_texture: Texture2D
@export var destination_texture: Texture2D
@export var destination_finish_texture: Texture2D
@export var wind_fan_body_texture: Texture2D
@export var wind_fan_blades_texture: Texture2D
@export var wind_fan_blades_blue_texture: Texture2D
@export var turbine_blades_texture: Texture2D
@export var turbine_unpowered_texture: Texture2D
@export var turbine_powered_base_texture: Texture2D
@export var turbine_powered_texture: Texture2D

@export_category("Wind Art")
@export var direction_up_texture: Texture2D
@export var direction_right_texture: Texture2D
@export var direction_down_texture: Texture2D
@export var direction_left_texture: Texture2D
@export var conflict_texture: Texture2D
@export var closed_loop_texture: Texture2D
@export var track_straight_texture: Texture2D
@export var track_bend_texture: Texture2D
@export var track_arrow_texture: Texture2D

@export_category("Device Art")
@export var guiding_up_texture: Texture2D
@export var guiding_right_texture: Texture2D
@export var guiding_down_texture: Texture2D
@export var guiding_left_texture: Texture2D
@export var valve_horizontal_texture: Texture2D
@export var valve_vertical_texture: Texture2D
@export var blocker_texture: Texture2D
@export var door_open_texture: Texture2D
@export var door_closed_texture: Texture2D

@export_category("Feedback Art")
@export var placement_legal_texture: Texture2D
@export var placement_illegal_texture: Texture2D
@export var failure_collision_texture: Texture2D
@export var failure_fall_texture: Texture2D
@export var failure_stop_texture: Texture2D

@export_category("Runtime Debug (read only)")
@export var debug_loaded_art_assets := 0
@export var debug_drawn_wind_cells := 0
@export var debug_preview_cell := Vector2i(-1, -1)
@export var debug_placement_legal := false
@export var debug_failure_marker_visible := false
@export var debug_failure_cell := Vector2i(-1, -1)
@export var debug_destination_finished := false

@onready var _session: GameSessionNode = get_node(session_node_path)
@onready var _build_controller: BuildControllerNode = get_node(build_controller_node_path)
var _result: SimulationResult
var _fan_spin := 0.0
var _wind_phase := 0.0
var _action_flash_time := 0.0
var _action_cell := Vector2i(-1, -1)
var _action_succeeded := false
var _action_kind := &""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	debug_loaded_art_assets = _count_loaded_art_assets()
	_session.state_changed.connect(queue_redraw)
	_session.preview_changed.connect(_on_preview_changed)
	queue_redraw()


func configure_geometry(origin: Vector2, size: float) -> void:
	board_origin = origin
	cell_size = size
	queue_redraw()


func flash_action(cell: Vector2i, succeeded: bool, action: StringName) -> void:
	_action_cell = cell
	_action_succeeded = succeeded
	_action_kind = action
	_action_flash_time = 0.42
	queue_redraw()


func _process(delta: float) -> void:
	_fan_spin = fmod(_fan_spin + delta * 2.4, TAU)
	var wind_speed := 1.7 if _session.phase() == GameRules.Phase.BUILD else 3.6
	_wind_phase = fmod(_wind_phase + delta * wind_speed, 1.0)
	_action_flash_time = maxf(_action_flash_time - delta, 0.0)
	_update_placement_preview()
	queue_redraw()


func show_result(result: SimulationResult) -> void:
	_result = result
	debug_failure_marker_visible = not result.succeeded
	debug_failure_cell = result.failure_cell if not result.succeeded else Vector2i(-1, -1)
	debug_destination_finished = result.succeeded
	queue_redraw()


func show_failure(result: SimulationResult) -> void:
	show_result(result)


func clear_result() -> void:
	_result = null
	debug_failure_marker_visible = false
	debug_failure_cell = Vector2i(-1, -1)
	debug_destination_finished = false
	queue_redraw()


func clear_failure() -> void:
	clear_result()


func cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _on_preview_changed(solution: WindSolution) -> void:
	debug_drawn_wind_cells = solution.cells().size()
	clear_result()


func _update_placement_preview() -> void:
	debug_preview_cell = Vector2i(-1, -1)
	debug_placement_legal = false
	if not _session.is_initialized() or _session.phase() != GameRules.Phase.BUILD:
		return
	var cell := _build_controller.debug_hovered_cell
	if not _session.level().contains(cell):
		return
	debug_preview_cell = cell
	var fan := _session.level().fan_at(cell)
	var device := _session.device_at(cell)
	if fan != null:
		debug_placement_legal = true
	elif device != null:
		debug_placement_legal = device.kind != GameRules.DeviceKind.BLOCKER
	else:
		debug_placement_legal = _session.can_place_device(_build_controller.selected_kind, cell)


func _draw() -> void:
	if not _session.is_initialized():
		return
	var level := _session.level()
	_draw_board_frame(level)
	for y in level.size.y:
		for x in level.size.x:
			var cell := Vector2i(x, y)
			_draw_terrain_cell(level, cell)

	var wind := _session.current_wind
	if wind != null:
		for cell in wind.cells():
			if wind.is_conflict(cell):
				var conflict_pulse := 0.68 + 0.18 * sin(_wind_phase * TAU * 2.0)
				_draw_cell_texture(conflict_texture, cell, 0.72 + conflict_pulse * 0.08, Color(1, 1, 1, conflict_pulse))
			elif wind.is_loop(cell):
				_draw_cell_texture(closed_loop_texture, cell, 0.72)
			else:
				_draw_wind_track(cell, wind.direction_at(cell))

	for fan in level.fans:
		_draw_fan(fan.cell, _session.fan_direction(fan.cell))
	for turbine in level.turbines:
		var powered := wind != null and wind.is_turbine_powered(turbine.id)
		_draw_turbine(turbine.cell, powered)
	for door in level.doors:
		var open := wind != null and wind.is_turbine_powered(door.turbine_id)
		_draw_door(door.cell, open)

	_draw_cell_texture(wind_origin_texture, level.start, 0.82)
	_draw_cell_texture(destination_finish_texture if debug_destination_finished else destination_texture, level.goal, 0.82)
	for device in _session.devices():
		_draw_device(device)
	_draw_placement_preview()
	_draw_failure_feedback()
	_draw_action_feedback()


func _draw_board_frame(level: LevelDefinition) -> void:
	var board_size := Vector2(level.size) * cell_size
	var shadow_rect := Rect2(board_origin + Vector2(12, 14), board_size).grow(14.0)
	draw_rect(shadow_rect, Color(0.22, 0.16, 0.10, 0.18), true)
	draw_rect(Rect2(board_origin, board_size).grow(10.0), Color("765238"), true)
	draw_rect(Rect2(board_origin, board_size).grow(4.0), Color("ead99f"), true)


func _draw_terrain_cell(level: LevelDefinition, cell: Vector2i) -> void:
	var rect := _cell_rect(cell)
	var ground := ground_texture_1 if (cell.x + cell.y) % 2 == 0 else ground_texture_2
	if ground != null:
		draw_texture_rect(ground, rect, false)
	else:
		draw_rect(rect, Color("f8faf9"), true)
	if level.is_pit(cell):
		if abyss_texture != null:
			draw_texture_rect(abyss_texture, rect, false)
		else:
			draw_rect(rect, Color("26343b"), true)
	elif level.is_wall(cell):
		_draw_wall(level, cell)
	draw_rect(rect, Color(0.38, 0.33, 0.24, 0.22), false, maxf(1.0, cell_size * 0.012))


func _draw_wall(level: LevelDefinition, cell: Vector2i) -> void:
	var up := level.is_wall(cell + Vector2i.UP)
	var right := level.is_wall(cell + Vector2i.RIGHT)
	var down := level.is_wall(cell + Vector2i.DOWN)
	var left := level.is_wall(cell + Vector2i.LEFT)
	var neighbors := int(up) + int(right) + int(down) + int(left)
	if neighbors >= 3:
		_draw_rotated_cell_texture(wall_straight_texture, cell, 0.0)
		_draw_rotated_cell_texture(wall_straight_texture, cell, PI / 2.0)
	elif neighbors == 2 and not ((up and down) or (left and right)):
		var rotation := 0.0
		if down and left:
			rotation = PI / 2.0
		elif left and up:
			rotation = PI
		elif up and right:
			rotation = -PI / 2.0
		_draw_rotated_cell_texture(wall_corner_texture, cell, rotation)
	else:
		var vertical := up or down
		_draw_rotated_cell_texture(wall_straight_texture, cell, PI / 2.0 if vertical else 0.0)
	if wall_corner_texture == null and wall_straight_texture == null:
		draw_rect(_cell_rect(cell), Color("607178"), true)


func _draw_fan(cell: Vector2i, direction: int) -> void:
	var blades := wind_fan_blades_blue_texture if wind_fan_blades_blue_texture != null else wind_fan_blades_texture
	if wind_fan_body_texture != null and blades != null:
		_draw_cell_texture(wind_fan_body_texture, cell, 0.86)
		_draw_rotated_cell_texture(blades, cell, _fan_spin, 0.72)
		_draw_cell_texture(_direction_texture(direction), cell, 0.46, Color(1, 1, 1, 0.82))
		return
	var center := cell_center(cell)
	draw_circle(center, 31.0, Color("d7ebe7"))
	draw_circle(center, 31.0, Color("2d7f78"), false, 3.0)
	_draw_arrow(center, direction, Color("20343b"), 27.0)


func _draw_turbine(cell: Vector2i, powered: bool) -> void:
	if powered and turbine_powered_base_texture != null and turbine_blades_texture != null:
		_draw_cell_texture(turbine_powered_base_texture, cell, 0.72)
		_draw_rotated_cell_texture(turbine_blades_texture, cell, -_fan_spin * 1.35, 0.72)
		return
	var texture := turbine_powered_texture if powered else turbine_unpowered_texture
	if texture != null:
		_draw_cell_texture(texture, cell, 0.72)
		return
	_draw_token(cell, "涡", Color("f2cf63") if powered else Color("cfbf86"))


func _draw_wind_track(cell: Vector2i, direction: int) -> void:
	var device := _session.device_at(cell)
	if device != null and device.kind == GameRules.DeviceKind.BEND and track_bend_texture != null:
		var bend_rotation := float(wrapi(device.orientation - GameRules.Direction.LEFT, 0, 4)) * PI / 2.0
		_draw_rotated_cell_texture(track_bend_texture, cell, bend_rotation)
	elif track_straight_texture != null:
		var straight_rotation := PI / 2.0 if direction in [GameRules.Direction.UP, GameRules.Direction.DOWN] else 0.0
		_draw_rotated_cell_texture(track_straight_texture, cell, straight_rotation)
	if track_arrow_texture != null:
		var arrow_rotation := float(direction - GameRules.Direction.RIGHT) * PI / 2.0
		var cell_offset := fposmod(float(cell.x * 7 + cell.y * 11) * 0.11, 1.0)
		var travel := fposmod(_wind_phase + cell_offset, 1.0) - 0.5
		var direction_vector := Vector2(GameRules.vector(direction))
		var alpha := 0.68 + 0.22 * sin((_wind_phase + cell_offset) * TAU)
		_draw_rotated_cell_texture_at(
			track_arrow_texture,
			cell_center(cell) + direction_vector * travel * cell_size * 0.24,
			arrow_rotation,
			0.52,
			Color(0.78, 1.0, 1.0, alpha)
		)
	elif track_straight_texture == null and track_bend_texture == null:
		_draw_cell_texture(_direction_texture(direction), cell, 0.62)


func _draw_device(device: PlacedDevice) -> void:
	var center := cell_center(device.cell)
	match device.kind:
		GameRules.DeviceKind.BLOCKER:
			_draw_blocker(device.cell)
		GameRules.DeviceKind.ONE_WAY_VALVE:
			var valve_texture := valve_vertical_texture if device.orientation in [GameRules.Direction.UP, GameRules.Direction.DOWN] else valve_horizontal_texture
			if valve_texture != null:
				_draw_cell_texture(valve_texture, device.cell, 0.76)
				if track_arrow_texture != null:
					var valve_arrow_rotation := float(device.orientation - GameRules.Direction.RIGHT) * PI / 2.0
					_draw_rotated_cell_texture(track_arrow_texture, device.cell, valve_arrow_rotation, 0.48)
			else:
				draw_circle(center, 29.0, Color("e3ddc5"))
				_draw_arrow(center, device.orientation, Color("665d3e"), 28.0)
		GameRules.DeviceKind.BEND:
			var guiding_texture := _guiding_texture(device.orientation)
			if guiding_texture != null:
				_draw_cell_texture(guiding_texture, device.cell, 0.92)
				if _session.current_wind != null and _session.current_wind.has_wind(device.cell):
					_draw_wind_track(device.cell, _session.current_wind.direction_at(device.cell))
			else:
				var port_a := GameRules.vector(device.orientation)
				var port_b := GameRules.vector(GameRules.clockwise(device.orientation))
				draw_line(center, center + Vector2(port_a) * 33.0, Color("3f7774"), 12.0)
				draw_line(center, center + Vector2(port_b) * 33.0, Color("3f7774"), 12.0)


func _draw_placement_preview() -> void:
	if debug_preview_cell == Vector2i(-1, -1):
		return
	var texture := placement_legal_texture if debug_placement_legal else placement_illegal_texture
	var pulse := 0.5 + 0.5 * sin(_wind_phase * TAU * 1.6)
	var alpha := 0.24 + pulse * 0.14 if debug_placement_legal else 0.52 + pulse * 0.18
	_draw_cell_texture(texture, debug_preview_cell, 0.88 + pulse * 0.06, Color(1, 1, 1, alpha))


func _draw_failure_feedback() -> void:
	if _result == null or _result.succeeded:
		return
	var texture: Texture2D = failure_stop_texture
	match _result.failure_reason:
		GameRules.FailureReason.COLLISION:
			texture = failure_collision_texture
		GameRules.FailureReason.PIT:
			texture = failure_fall_texture
		GameRules.FailureReason.CONFLICT:
			texture = conflict_texture
	var pulse := 0.5 + 0.5 * sin(_wind_phase * TAU * 2.0)
	_draw_cell_texture(texture, _result.failure_cell, 0.78 + pulse * 0.12, Color(1, 1, 1, 0.72 + pulse * 0.28))
	draw_arc(cell_center(_result.failure_cell), cell_size * (0.34 + pulse * 0.08), 0.0, TAU, 32, Color(0.89, 0.24, 0.20, 0.72), maxf(3.0, cell_size * 0.035), true)
	if texture == null:
		_draw_cross(cell_center(_result.failure_cell), Color("d95454"), 28.0)


func _draw_action_feedback() -> void:
	if _action_flash_time <= 0.0 or _action_cell == Vector2i(-1, -1):
		return
	var progress := 1.0 - _action_flash_time / 0.42
	var radius := cell_size * lerpf(0.24, 0.48, progress)
	var color := Color("ffd85e") if _action_succeeded else Color("e45e52")
	color.a = 1.0 - progress
	draw_arc(cell_center(_action_cell), radius, 0.0, TAU, 36, color, maxf(3.0, cell_size * 0.04), true)
	if _action_kind == &"remove" and _action_succeeded:
		draw_circle(cell_center(_action_cell), cell_size * 0.10 * (1.0 - progress), color)


func _draw_blocker(cell: Vector2i) -> void:
	if blocker_texture != null:
		_draw_cell_texture(blocker_texture, cell, 0.76)
		return
	var center := cell_center(cell)
	var scale_factor := cell_size / 96.0
	var plank_size := Vector2(64, 14) * scale_factor
	for index in 3:
		var plank_center := center + Vector2(0, (float(index) - 1.0) * 15.0 * scale_factor)
		var plank_rect := Rect2(plank_center - plank_size * 0.5, plank_size)
		draw_rect(plank_rect, Color("825a3b"), true)
		draw_rect(plank_rect, Color("4c3428"), false, maxf(2.0, 2.0 * scale_factor))
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			draw_circle(center + Vector2(x_sign * 23.0, y_sign * 15.0) * scale_factor, 3.2 * scale_factor, Color("e7c56f"))


func _draw_door(cell: Vector2i, open: bool) -> void:
	var texture := door_open_texture if open else door_closed_texture
	if texture != null:
		_draw_cell_texture(texture, cell, 0.78)
		return
	var center := cell_center(cell)
	var scale_factor := cell_size / 96.0
	var post_size := Vector2(11, 70) * scale_factor
	var left_post := Rect2(center + Vector2(-33, -35) * scale_factor, post_size)
	var right_post := Rect2(center + Vector2(22, -35) * scale_factor, post_size)
	draw_rect(left_post, Color("765238"), true)
	draw_rect(right_post, Color("765238"), true)
	draw_rect(left_post, Color("4c3428"), false, maxf(2.0, 2.0 * scale_factor))
	draw_rect(right_post, Color("4c3428"), false, maxf(2.0, 2.0 * scale_factor))
	if open:
		draw_line(center + Vector2(-19, -28) * scale_factor, center + Vector2(-19, 28) * scale_factor, Color(0.22, 0.78, 0.82, 0.65), 4.0 * scale_factor)
		draw_line(center + Vector2(19, -28) * scale_factor, center + Vector2(19, 28) * scale_factor, Color(0.22, 0.78, 0.82, 0.65), 4.0 * scale_factor)
		draw_circle(center, 7.0 * scale_factor, Color("ffd85e"))
	else:
		var gate_rect := Rect2(center + Vector2(-22, -29) * scale_factor, Vector2(44, 58) * scale_factor)
		draw_rect(gate_rect, Color("9b6544"), true)
		for index in 3:
			var y := center.y + (float(index) - 1.0) * 17.0 * scale_factor
			draw_line(Vector2(center.x - 20.0 * scale_factor, y), Vector2(center.x + 20.0 * scale_factor, y), Color("5a3c2e"), 4.0 * scale_factor)
		draw_circle(center, 6.0 * scale_factor, Color("e45e52"))


func _draw_token(cell: Vector2i, label: String, color: Color) -> void:
	var center := cell_center(cell)
	draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), color, true)
	draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), Color("40545a"), false, 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-13, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("20343b"))


func _draw_arrow(center: Vector2, direction: int, color: Color, length := 34.0) -> void:
	if direction < 0:
		return
	var direction_vector := Vector2(GameRules.vector(direction))
	var end := center + direction_vector * length
	draw_line(center - direction_vector * 8.0, end, color, 5.0)
	var side := direction_vector.rotated(PI * 0.75)
	draw_line(end, end + side * 13.0, color, 5.0)
	draw_line(end, end + side.rotated(PI / 2.0) * 13.0, color, 5.0)


func _draw_cross(center: Vector2, color: Color, radius := 20.0) -> void:
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, 7.0)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, 7.0)


func _draw_cell_texture(texture: Texture2D, cell: Vector2i, scale := 1.0, modulate := Color.WHITE) -> void:
	if texture == null:
		return
	var size := Vector2.ONE * cell_size * scale
	draw_texture_rect(texture, Rect2(cell_center(cell) - size * 0.5, size), false, modulate)


func _draw_rotated_cell_texture(texture: Texture2D, cell: Vector2i, rotation: float, scale := 1.0, modulate := Color.WHITE) -> void:
	_draw_rotated_cell_texture_at(texture, cell_center(cell), rotation, scale, modulate)


func _draw_rotated_cell_texture_at(texture: Texture2D, center: Vector2, rotation: float, scale := 1.0, modulate := Color.WHITE) -> void:
	if texture == null:
		return
	var size := Vector2.ONE * cell_size * scale
	draw_set_transform(center, rotation)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)


func _direction_texture(direction: int) -> Texture2D:
	match direction:
		GameRules.Direction.UP:
			return direction_up_texture
		GameRules.Direction.RIGHT:
			return direction_right_texture
		GameRules.Direction.DOWN:
			return direction_down_texture
		GameRules.Direction.LEFT:
			return direction_left_texture
	return null


func _guiding_texture(direction: int) -> Texture2D:
	match direction:
		GameRules.Direction.UP:
			return guiding_up_texture
		GameRules.Direction.RIGHT:
			return guiding_right_texture
		GameRules.Direction.DOWN:
			return guiding_down_texture
		GameRules.Direction.LEFT:
			return guiding_left_texture
	return null


func _count_loaded_art_assets() -> int:
	var assets: Array[Texture2D] = [
		ground_texture_1, ground_texture_2, abyss_texture, wall_corner_texture, wall_straight_texture,
		wind_origin_texture, destination_texture, destination_finish_texture,
		wind_fan_body_texture, wind_fan_blades_texture, wind_fan_blades_blue_texture,
		turbine_blades_texture, turbine_unpowered_texture, turbine_powered_base_texture, turbine_powered_texture,
		direction_up_texture, direction_right_texture, direction_down_texture, direction_left_texture,
		conflict_texture, closed_loop_texture, track_straight_texture, track_bend_texture, track_arrow_texture,
		guiding_up_texture, guiding_right_texture, guiding_down_texture, guiding_left_texture,
		valve_horizontal_texture, valve_vertical_texture, blocker_texture,
		door_open_texture, door_closed_texture,
		placement_legal_texture, placement_illegal_texture,
		failure_collision_texture, failure_fall_texture, failure_stop_texture,
	]
	var count := 0
	for asset in assets:
		if asset != null:
			count += 1
	return count
