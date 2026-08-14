class_name LevelEditor
extends Control

enum Tool { FLOOR, WALL, PIT, START, GOAL, FAN, TURBINE, DOOR, ERASE }

const SAVE_PATH := "user://zhu_feng_editor_level.json"
const GAMEPLAY_SCENE := "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

@export_category("Runtime Debug (read only)")
@export var debug_selected_tool := "WALL"
@export var debug_last_cell := Vector2i(-1, -1)
@export_multiline var debug_last_action := ""
@export_multiline var debug_validation := ""

@onready var _board: LevelEditorBoard = $EditorBoard
@onready var _board_input: Control = $BoardInput
@onready var _name_edit: LineEdit = $RightPanel/NameEdit
@onready var _objective_edit: LineEdit = $RightPanel/ObjectiveEdit
@onready var _tip_edit: LineEdit = $RightPanel/TipEdit
@onready var _width_spin: SpinBox = $RightPanel/WidthSpin
@onready var _height_spin: SpinBox = $RightPanel/HeightSpin
@onready var _budget_spin: SpinBox = $RightPanel/BudgetSpin
@onready var _efficient_spin: SpinBox = $RightPanel/EfficientSpin
@onready var _direction_option: OptionButton = $RightPanel/DirectionOption
@onready var _link_edit: LineEdit = $RightPanel/LinkEdit
@onready var _required_toggle: CheckBox = $RightPanel/RequiredToggle
@onready var _status: Label = $Status
@onready var _tool_hint: Label = $LeftPanel/ToolHint
@onready var _game_flow: Node = get_node("/root/GameFlow")

var _level: LevelDefinition
var _selected_tool := Tool.WALL
var _tool_buttons: Dictionary = {}


func _ready() -> void:
	_tool_buttons = {
		Tool.FLOOR: $LeftPanel/Floor,
		Tool.WALL: $LeftPanel/Wall,
		Tool.PIT: $LeftPanel/Pit,
		Tool.START: $LeftPanel/Start,
		Tool.GOAL: $LeftPanel/Goal,
		Tool.FAN: $LeftPanel/Fan,
		Tool.TURBINE: $LeftPanel/Turbine,
		Tool.DOOR: $LeftPanel/Door,
		Tool.ERASE: $LeftPanel/Erase,
	}
	for tool in _tool_buttons:
		(_tool_buttons[tool] as Button).pressed.connect(select_tool.bind(tool))
	_direction_option.clear()
	for label in ["上", "右", "下", "左"]:
		_direction_option.add_item(label)
	_board.cell_clicked.connect(_on_board_cell_clicked)
	_board_input.gui_input.connect(_on_board_gui_input)
	$RightPanel/ApplySize.pressed.connect(_on_apply_size)
	$RightPanel/New.pressed.connect(_on_new)
	$RightPanel/Save.pressed.connect(_on_save)
	$RightPanel/Load.pressed.connect(_on_load)
	$RightPanel/Copy.pressed.connect(_on_copy)
	$RightPanel/Paste.pressed.connect(_on_paste)
	$RightPanel/Validate.pressed.connect(_on_validate)
	$RightPanel/Test.pressed.connect(_on_test)
	$Back.pressed.connect(_on_back)
	var retained := _game_flow.call("custom_level") as LevelDefinition
	_level = retained if retained != null else _make_default_level()
	_sync_ui_from_level()
	select_tool(Tool.WALL)
	_show_status("左键绘制 · 右键擦除 · 完成后点击“一键试玩”", false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func level_definition() -> LevelDefinition:
	_sync_metadata_to_level()
	return _level


func select_tool(tool: int) -> void:
	_selected_tool = clampi(tool, Tool.FLOOR, Tool.ERASE)
	debug_selected_tool = Tool.keys()[_selected_tool]
	for candidate in _tool_buttons:
		(_tool_buttons[candidate] as Button).button_pressed = candidate == _selected_tool
	var hints := {
		Tool.FLOOR: "地面：清除墙或坑，保留机关",
		Tool.WALL: "墙体：阻断风路与风种",
		Tool.PIT: "深坑：风种经过会失败",
		Tool.START: "起点：每关恰好一个",
		Tool.GOAL: "终点：每关恰好一个",
		Tool.FAN: "风机：方向取右侧选项",
		Tool.TURBINE: "涡轮：填写联动 ID 后放置",
		Tool.DOOR: "门：填写它监听的涡轮 ID",
		Tool.ERASE: "擦除：移除地形或机关",
	}
	_tool_hint.text = hints[_selected_tool]


func apply_tool_at(cell: Vector2i, mouse_button: int = MOUSE_BUTTON_LEFT) -> bool:
	if _level == null or not _level.contains(cell):
		return false
	debug_last_cell = cell
	var tool := Tool.ERASE if mouse_button == MOUSE_BUTTON_RIGHT else _selected_tool
	var succeeded := false
	match tool:
		Tool.FLOOR:
			_level.walls.erase(cell)
			_level.pits.erase(cell)
			succeeded = true
		Tool.WALL:
			succeeded = _place_terrain(cell, true)
		Tool.PIT:
			succeeded = _place_terrain(cell, false)
		Tool.START:
			succeeded = _place_marker(cell, true)
		Tool.GOAL:
			succeeded = _place_marker(cell, false)
		Tool.FAN:
			succeeded = _place_fan(cell)
		Tool.TURBINE:
			succeeded = _place_turbine(cell)
		Tool.DOOR:
			succeeded = _place_door(cell)
		Tool.ERASE:
			succeeded = _erase_cell(cell)
	if succeeded:
		debug_last_action = "%s @ %s" % [Tool.keys()[tool], cell]
		_board.set_level(_level)
		_show_status("已更新格子 %s" % cell, false)
	return succeeded


func _on_board_cell_clicked(cell: Vector2i, mouse_button: int) -> void:
	apply_tool_at(cell, mouse_button)


func _on_board_gui_input(event: InputEvent) -> void:
	var screen_position := _board_input.position
	if event is InputEventMouseMotion:
		screen_position += event.position
		_board.update_hover_at(screen_position)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		screen_position += event.position
		var cell := _board.cell_at(screen_position)
		if cell.x >= 0:
			apply_tool_at(cell, event.button_index)
			_board_input.accept_event()


func _place_terrain(cell: Vector2i, wall: bool) -> bool:
	if cell == _level.start or cell == _level.goal:
		_show_status("起点与终点不能变成地形；请先移动标记。", true)
		return false
	_clear_objects_at(cell)
	_level.walls.erase(cell)
	_level.pits.erase(cell)
	(_level.walls if wall else _level.pits).append(cell)
	return true


func _place_marker(cell: Vector2i, is_start: bool) -> bool:
	if (is_start and cell == _level.goal) or (not is_start and cell == _level.start):
		_show_status("起点与终点不能位于同一格。", true)
		return false
	_clear_everything_at(cell)
	if is_start:
		_level.start = cell
	else:
		_level.goal = cell
	return true


func _place_fan(cell: Vector2i) -> bool:
	if not _can_place_object(cell):
		return false
	_clear_everything_at(cell)
	_level.fans.append(FanDefinition.create(cell, _direction_option.selected))
	return true


func _place_turbine(cell: Vector2i) -> bool:
	if not _can_place_object(cell):
		return false
	var link_id := _normalized_link_id()
	if link_id.is_empty():
		return false
	for turbine in _level.turbines:
		if turbine.id == StringName(link_id) and turbine.cell != cell:
			_show_status("涡轮 ID “%s” 已被使用。" % link_id, true)
			return false
	_clear_everything_at(cell)
	var id := StringName(link_id)
	_level.turbines.append(TurbineDefinition.create(id, cell))
	if _required_toggle.button_pressed and id not in _level.required_turbine_ids:
		_level.required_turbine_ids.append(id)
	elif not _required_toggle.button_pressed:
		_level.required_turbine_ids.erase(id)
	return true


func _place_door(cell: Vector2i) -> bool:
	if not _can_place_object(cell):
		return false
	var link_id := _normalized_link_id()
	if link_id.is_empty():
		return false
	_clear_everything_at(cell)
	_level.doors.append(DoorDefinition.create(cell, StringName(link_id)))
	return true


func _can_place_object(cell: Vector2i) -> bool:
	if cell == _level.start or cell == _level.goal:
		_show_status("这里是起点或终点；请先移动标记。", true)
		return false
	return true


func _erase_cell(cell: Vector2i) -> bool:
	if cell == _level.start or cell == _level.goal:
		_show_status("起点与终点只能移动，不能删除。", true)
		return false
	_clear_everything_at(cell)
	return true


func _clear_everything_at(cell: Vector2i) -> void:
	_level.walls.erase(cell)
	_level.pits.erase(cell)
	_clear_objects_at(cell)


func _clear_objects_at(cell: Vector2i) -> void:
	for index in range(_level.fans.size() - 1, -1, -1):
		if _level.fans[index].cell == cell:
			_level.fans.remove_at(index)
	for index in range(_level.doors.size() - 1, -1, -1):
		if _level.doors[index].cell == cell:
			_level.doors.remove_at(index)
	for index in range(_level.turbines.size() - 1, -1, -1):
		if _level.turbines[index].cell == cell:
			var removed_id := _level.turbines[index].id
			_level.turbines.remove_at(index)
			_level.required_turbine_ids.erase(removed_id)


func _normalized_link_id() -> String:
	var link_id := _link_edit.text.strip_edges().to_lower().replace(" ", "_")
	if link_id.is_empty():
		_show_status("放置涡轮或门之前，请填写联动 ID。", true)
		return ""
	_link_edit.text = link_id
	return link_id


func _on_apply_size() -> void:
	_sync_metadata_to_level()
	var new_size := Vector2i(int(_width_spin.value), int(_height_spin.value))
	_level.size = new_size
	_level.start = _clamp_cell(_level.start, new_size)
	_level.goal = _clamp_cell(_level.goal, new_size)
	if _level.start == _level.goal:
		_level.goal = Vector2i(maxi(0, new_size.x - 2), _level.start.y)
	_filter_out_of_bounds()
	_board.set_level(_level)
	_show_status("画布已调整为 %d × %d。" % [new_size.x, new_size.y], false)


func _on_new() -> void:
	_level = _make_default_level()
	_game_flow.call("clear_custom_level")
	_sync_ui_from_level()
	_show_status("已新建 10 × 6 空白关卡。", false)


func _on_save() -> void:
	_sync_metadata_to_level()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_show_status("保存失败：无法写入 %s" % SAVE_PATH, true)
		return
	file.store_string(LevelCodec.to_json(_level))
	_show_status("已保存到 %s" % ProjectSettings.globalize_path(SAVE_PATH), false)


func _on_load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_show_status("尚无存档：%s" % ProjectSettings.globalize_path(SAVE_PATH), true)
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var loaded := LevelCodec.from_json(file.get_as_text()) if file != null else null
	if loaded == null:
		_show_status("读取失败：JSON 格式不正确。", true)
		return
	_level = loaded
	_sync_ui_from_level()
	_show_status("已读取本地关卡。", false)


func _on_copy() -> void:
	_sync_metadata_to_level()
	DisplayServer.clipboard_set(LevelCodec.to_json(_level))
	_show_status("关卡 JSON 已复制到剪贴板。", false)


func _on_paste() -> void:
	var loaded := LevelCodec.from_json(DisplayServer.clipboard_get())
	if loaded == null:
		_show_status("剪贴板中没有可识别的关卡 JSON。", true)
		return
	_level = loaded
	_sync_ui_from_level()
	_show_status("已从剪贴板导入关卡。", false)


func _on_validate() -> void:
	var errors := _validation_errors()
	if errors.is_empty():
		_show_status("校验通过：可以进入试玩。", false)
	else:
		_show_status("校验发现 %d 项：%s" % [errors.size(), "；".join(errors)], true)


func _on_test() -> void:
	var errors := _validation_errors()
	if not errors.is_empty():
		_show_status("暂不能试玩：%s" % "；".join(errors), true)
		return
	if not (_game_flow.call("set_custom_level", _level) as bool):
		_show_status("关卡未能交给试玩流程。", true)
		return
	debug_last_action = "TEST | %s" % _level.level_id
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_back() -> void:
	_game_flow.call("clear_custom_level")
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _validation_errors() -> PackedStringArray:
	_sync_metadata_to_level()
	var errors := _level.validate()
	if _level.start == _level.goal:
		errors.append("起点与终点重叠")
	if _level.start in _level.walls or _level.start in _level.pits:
		errors.append("起点被地形占用")
	if _level.goal in _level.walls or _level.goal in _level.pits:
		errors.append("终点被地形占用")
	var occupied: Dictionary = {}
	for cell in _level.walls + _level.pits:
		if occupied.has(cell):
			errors.append("格子 %s 存在重叠地形" % cell)
		occupied[cell] = true
	for fan in _level.fans:
		if occupied.has(fan.cell):
			errors.append("格子 %s 存在重叠对象" % fan.cell)
		occupied[fan.cell] = true
	var turbine_ids: Dictionary = {}
	for turbine in _level.turbines:
		if occupied.has(turbine.cell):
			errors.append("格子 %s 存在重叠对象" % turbine.cell)
		occupied[turbine.cell] = true
		if turbine_ids.has(turbine.id):
			errors.append("涡轮 ID 重复：%s" % turbine.id)
		turbine_ids[turbine.id] = true
	for door in _level.doors:
		if occupied.has(door.cell):
			errors.append("格子 %s 存在重叠对象" % door.cell)
		occupied[door.cell] = true
	debug_validation = "OK" if errors.is_empty() else "\n".join(errors)
	return errors


func _sync_ui_from_level() -> void:
	_name_edit.text = _level.display_name
	_objective_edit.text = _level.objective
	_tip_edit.text = _level.teaching_tip
	_width_spin.value = _level.size.x
	_height_spin.value = _level.size.y
	_budget_spin.value = _level.budget
	_efficient_spin.value = _level.efficient_budget
	_board.set_level(_level)


func _sync_metadata_to_level() -> void:
	if _level == null:
		return
	_level.level_id = &"custom_workshop"
	_level.display_name = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "我的风路"
	_level.objective = _objective_edit.text.strip_edges() if not _objective_edit.text.strip_edges().is_empty() else "让风种抵达终点。"
	_level.teaching_tip = _tip_edit.text.strip_edges() if not _tip_edit.text.strip_edges().is_empty() else "观察风向，再开始施工。"
	_level.budget = int(_budget_spin.value)
	_level.efficient_budget = int(_efficient_spin.value)


func _filter_out_of_bounds() -> void:
	_level.walls.assign(_level.walls.filter(func(cell: Vector2i) -> bool: return _level.contains(cell)))
	_level.pits.assign(_level.pits.filter(func(cell: Vector2i) -> bool: return _level.contains(cell)))
	_level.fans.assign(_level.fans.filter(func(fan: FanDefinition) -> bool: return _level.contains(fan.cell)))
	_level.turbines.assign(_level.turbines.filter(func(turbine: TurbineDefinition) -> bool: return _level.contains(turbine.cell)))
	_level.doors.assign(_level.doors.filter(func(door: DoorDefinition) -> bool: return _level.contains(door.cell)))
	var existing_ids: Array[StringName] = []
	for turbine in _level.turbines:
		existing_ids.append(turbine.id)
	_level.required_turbine_ids.assign(_level.required_turbine_ids.filter(func(id: StringName) -> bool: return id in existing_ids))


func _clamp_cell(cell: Vector2i, size: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))


func _make_default_level() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_id = &"custom_workshop"
	level.display_name = "我的风路"
	level.objective = "让风种抵达终点。"
	level.teaching_tip = "观察风向，再开始施工。"
	level.size = Vector2i(10, 6)
	level.budget = 8
	level.efficient_budget = 6
	level.start = Vector2i(1, 3)
	level.goal = Vector2i(8, 3)
	level.fans = [FanDefinition.create(Vector2i(0, 3), GameRules.Direction.RIGHT)]
	return level


func _show_status(message: String, is_error: bool) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", Color("e45e52") if is_error else Color("20343b"))
