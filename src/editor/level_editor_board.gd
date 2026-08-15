class_name LevelEditorBoard
extends Node2D

signal cell_clicked(cell: Vector2i, mouse_button: int)

@export var board_area := Rect2(350, 138, 1090, 790)
@export_category("Art")
@export var wind_fan_body_texture: Texture2D
@export var wind_fan_blades_texture: Texture2D
@export var door_closed_texture: Texture2D
@export_category("Runtime Debug (read only)")
@export var debug_hovered_cell := Vector2i(-1, -1)
@export var debug_cell_size := 0.0
@export var debug_board_origin := Vector2.ZERO

var _level: LevelDefinition


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_level(level: LevelDefinition) -> void:
	_level = level
	_recalculate_geometry()
	queue_redraw()


func cell_at(screen_position: Vector2) -> Vector2i:
	if _level == null or debug_cell_size <= 0.0:
		return Vector2i(-1, -1)
	var local := screen_position - debug_board_origin
	var cell := Vector2i(floori(local.x / debug_cell_size), floori(local.y / debug_cell_size))
	return cell if _level.contains(cell) else Vector2i(-1, -1)


func update_hover_at(screen_position: Vector2) -> void:
	debug_hovered_cell = cell_at(screen_position)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		debug_hovered_cell = cell_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var cell := cell_at(event.position)
		if cell.x >= 0 and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			cell_clicked.emit(cell, event.button_index)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if _level == null:
		return
	var board_rect := Rect2(debug_board_origin, Vector2(_level.size) * debug_cell_size)
	draw_style_box(_panel_style(), board_rect.grow(18.0))
	for y in _level.size.y:
		for x in _level.size.x:
			_draw_cell(Vector2i(x, y))
	if _level.contains(debug_hovered_cell):
		var hover_rect := _cell_rect(debug_hovered_cell).grow(-3.0)
		draw_rect(hover_rect, Color(0.16, 0.56, 0.51, 0.18), true)
		draw_rect(hover_rect, Color("299083"), false, 3.0)


func _draw_cell(cell: Vector2i) -> void:
	var rect := _cell_rect(cell)
	var fill := Color("fff9e5") if (cell.x + cell.y) % 2 == 0 else Color("f6efd8")
	if cell in _level.pits:
		fill = Color("40545a")
	elif cell in _level.walls:
		fill = Color("8a7968")
	draw_rect(rect.grow(-1.0), fill, true)
	draw_rect(rect, Color(0.25, 0.33, 0.35, 0.32), false, 1.5)
	if cell in _level.walls:
		_draw_wall(rect)
	elif cell in _level.pits:
		_draw_pit(rect)
	if cell == _level.start:
		_draw_badge(rect, "起", Color("299083"))
	if cell == _level.goal:
		_draw_badge(rect, "终", Color("d89f2b"))
	var fan := _level.fan_at(cell)
	if fan != null:
		_draw_fan(rect, fan.direction, fan.strength)
	var turbine := _level.turbine_at(cell)
	if turbine != null:
		_draw_machine(rect, "涡", String(turbine.id), Color("36a6a6"))
	var door := _level.door_at(cell)
	if door != null:
		if door_closed_texture != null:
			_draw_door_asset(rect, String(door.turbine_id))
		else:
			_draw_machine(rect, "门", String(door.turbine_id), Color("795238"))


func _draw_wall(rect: Rect2) -> void:
	var inset := rect.grow(-rect.size.x * 0.12)
	draw_rect(inset, Color("9a8672"), true)
	for i in 3:
		var y := inset.position.y + inset.size.y * float(i + 1) / 4.0
		draw_line(Vector2(inset.position.x, y), Vector2(inset.end.x, y), Color(0.25, 0.19, 0.15, 0.45), 2.0)


func _draw_pit(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_circle(center, rect.size.x * 0.31, Color("20343b"))
	draw_arc(center, rect.size.x * 0.23, 0.0, TAU, 32, Color(0.73, 0.87, 0.82, 0.35), 2.0)


func _draw_badge(rect: Rect2, label: String, color: Color) -> void:
	var center := rect.get_center()
	draw_circle(center, rect.size.x * 0.27, Color("fff9e5"))
	draw_circle(center, rect.size.x * 0.27, color, false, 4.0)
	_draw_centered_text(rect, label, color, maxi(18, floori(rect.size.x * 0.27)))


func _draw_fan(rect: Rect2, direction: int, strength: int) -> void:
	var center := rect.get_center()
	if wind_fan_body_texture != null and wind_fan_blades_texture != null:
		_draw_texture_in_rect(wind_fan_body_texture, rect, 0.76)
		_draw_texture_in_rect(wind_fan_blades_texture, rect, 0.64)
		var vector := Vector2(GameRules.vector(direction))
		var from := center + vector * rect.size.x * 0.25
		var to := center + vector * rect.size.x * 0.43
		draw_line(from, to, Color("e45e52"), 4.0)
		var side := vector.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([to, to - vector * 9.0 + side * 6.0, to - vector * 9.0 - side * 6.0]), Color("e45e52"))
		_draw_corner_value(rect, strength)
		return
	draw_circle(center, rect.size.x * 0.27, Color("fff9e5"))
	draw_circle(center, rect.size.x * 0.27, Color("40545a"), false, 3.0)
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var point := center + Vector2.from_angle(angle) * rect.size.x * 0.18
		draw_circle(point, rect.size.x * 0.085, Color("36a6a6"))
	draw_circle(center, rect.size.x * 0.07, Color("d89f2b"))
	var vector := Vector2(GameRules.vector(direction))
	var from := center + vector * rect.size.x * 0.25
	var to := center + vector * rect.size.x * 0.43
	draw_line(from, to, Color("e45e52"), 4.0)
	var side := vector.rotated(PI * 0.5)
	draw_colored_polygon(PackedVector2Array([to, to - vector * 9.0 + side * 6.0, to - vector * 9.0 - side * 6.0]), Color("e45e52"))
	_draw_corner_value(rect, strength)


func _draw_corner_value(rect: Rect2, value: int) -> void:
	var radius := maxf(9.0, rect.size.x * 0.13)
	var center := rect.position + Vector2(rect.size.x - radius - 3.0, radius + 3.0)
	draw_circle(center, radius, Color(1.0, 0.98, 0.91, 0.96))
	draw_circle(center, radius, Color("299083"), false, 2.0)
	var value_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	_draw_centered_text(value_rect, str(value), Color("20343b"), maxi(11, floori(rect.size.x * 0.15)))


func _draw_machine(rect: Rect2, symbol: String, link_id: String, color: Color) -> void:
	var body := rect.grow(-rect.size.x * 0.16)
	draw_rect(body, Color("fff9e5"), true)
	draw_rect(body, color, false, 3.0)
	var top := Rect2(body.position, Vector2(body.size.x, body.size.y * 0.62))
	_draw_centered_text(top, symbol, color, maxi(17, floori(rect.size.x * 0.24)))
	var id_rect := Rect2(body.position.x + 2.0, body.position.y + body.size.y * 0.58, body.size.x - 4.0, body.size.y * 0.34)
	_draw_centered_text(id_rect, link_id.left(8), Color("20343b"), maxi(10, floori(rect.size.x * 0.12)))


func _draw_door_asset(rect: Rect2, link_id: String) -> void:
	_draw_texture_in_rect(door_closed_texture, rect, 0.68)
	var id_rect := Rect2(rect.position.x + rect.size.x * 0.16, rect.position.y + rect.size.y * 0.72, rect.size.x * 0.68, rect.size.y * 0.18)
	draw_rect(id_rect, Color(1.0, 0.98, 0.91, 0.88), true)
	_draw_centered_text(id_rect, link_id.left(8), Color("20343b"), maxi(9, floori(rect.size.x * 0.105)))


func _draw_texture_in_rect(texture: Texture2D, rect: Rect2, scale: float) -> void:
	var size := Vector2.ONE * minf(rect.size.x, rect.size.y) * scale
	draw_texture_rect(texture, Rect2(rect.get_center() - size * 0.5, size), false)


func _draw_centered_text(rect: Rect2, value: String, color: Color, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var baseline := rect.position.y + (rect.size.y + font.get_height(font_size)) * 0.5 - font.get_descent(font_size)
	draw_string(font, Vector2(rect.position.x, baseline), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(debug_board_origin + Vector2(cell) * debug_cell_size, Vector2.ONE * debug_cell_size)


func _recalculate_geometry() -> void:
	if _level == null or _level.size.x <= 0 or _level.size.y <= 0:
		return
	debug_cell_size = floorf(minf(board_area.size.x / _level.size.x, board_area.size.y / _level.size.y))
	debug_cell_size = clampf(debug_cell_size, 48.0, 118.0)
	var pixel_size := Vector2(_level.size) * debug_cell_size
	debug_board_origin = (board_area.position + (board_area.size - pixel_size) * 0.5).round()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1e6c7")
	style.border_color = Color("40545a")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.08, 0.12, 0.13, 0.18)
	style.shadow_size = 10
	return style
