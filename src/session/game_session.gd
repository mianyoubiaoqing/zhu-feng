class_name GameSession
extends RefCounted

var _level: LevelDefinition
var _placements: Dictionary = {}
var _fan_directions: Dictionary = {}
var _undo_stack: Array = []
var _spent_budget := 0
var _phase: int = GameRules.Phase.BUILD
var _last_error := ""


func load_level(level: LevelDefinition) -> bool:
	var errors := level.validate()
	if not errors.is_empty():
		_last_error = "；".join(errors)
		return false
	_level = level
	_placements.clear()
	_fan_directions.clear()
	_undo_stack.clear()
	_spent_budget = 0
	_phase = GameRules.Phase.BUILD
	for fan in level.fans:
		_fan_directions[fan.cell] = fan.direction
	_last_error = ""
	return true


func place_device(kind: int, cell: Vector2i, orientation: int = GameRules.Direction.UP) -> bool:
	if not _ensure_build_phase():
		return false
	if not GameRules.DEVICE_COSTS.has(kind):
		return _reject("未知装置")
	if not _can_occupy(cell):
		return _reject("该格不能放置装置")
	var cost := GameRules.cost(kind)
	if _spent_budget + cost > _level.budget:
		return _reject("施工预算不足")
	_push_undo()
	_placements[cell] = PlacedDevice.new(kind, cell, orientation)
	_spent_budget += cost
	_last_error = ""
	return true


func rotate_at(cell: Vector2i) -> bool:
	if not _ensure_build_phase():
		return false
	if _fan_directions.has(cell):
		_push_undo()
		_fan_directions[cell] = GameRules.clockwise(_fan_directions[cell])
		return true
	var device: PlacedDevice = _placements.get(cell)
	if device == null:
		return _reject("该格没有可旋转对象")
	if device.kind == GameRules.DeviceKind.BLOCKER:
		return _reject("挡风板不可旋转")
	_push_undo()
	device.orientation = GameRules.clockwise(device.orientation)
	return true


func remove_device(cell: Vector2i) -> bool:
	if not _ensure_build_phase():
		return false
	var device: PlacedDevice = _placements.get(cell)
	if device == null:
		return _reject("该格没有玩家装置")
	_push_undo()
	_spent_budget -= GameRules.cost(device.kind)
	_placements.erase(cell)
	return true


func undo() -> bool:
	if not _ensure_build_phase() or _undo_stack.is_empty():
		return false
	var snapshot: Dictionary = _undo_stack.pop_back()
	_placements = snapshot.placements
	_fan_directions = snapshot.fan_directions
	_spent_budget = snapshot.spent_budget
	return true


func preview() -> WindSolution:
	return WindSolver.solve(_level, _placements, _fan_directions)


func start_test() -> SimulationResult:
	var wind := preview()
	_phase = GameRules.Phase.RESULT
	var result := CargoSimulator.simulate(_level, wind, _spent_budget)
	_decorate_result(result, wind)
	return result


func return_to_build() -> void:
	_phase = GameRules.Phase.BUILD


func level() -> LevelDefinition:
	return _level


func phase() -> int:
	return _phase


func spent_budget() -> int:
	return _spent_budget


func remaining_budget() -> int:
	return _level.budget - _spent_budget


func last_error() -> String:
	return _last_error


func fan_direction(cell: Vector2i) -> int:
	return _fan_directions.get(cell, -1)


func device_at(cell: Vector2i) -> PlacedDevice:
	var device: PlacedDevice = _placements.get(cell)
	return device.copy() if device != null else null


func devices() -> Array[PlacedDevice]:
	var copies: Array[PlacedDevice] = []
	for device: PlacedDevice in _placements.values():
		copies.append(device.copy())
	return copies


func can_place_device(kind: int, cell: Vector2i) -> bool:
	return (
		_phase == GameRules.Phase.BUILD
		and GameRules.DEVICE_COSTS.has(kind)
		and _can_occupy(cell)
		and _spent_budget + GameRules.cost(kind) <= _level.budget
	)


func _can_occupy(cell: Vector2i) -> bool:
	return _level.contains(cell) and not _level.is_wall(cell) and not _level.is_pit(cell) and not _level.is_fixed_object(cell) and not _placements.has(cell)


func _ensure_build_phase() -> bool:
	if _phase != GameRules.Phase.BUILD:
		return _reject("运行结果阶段不能编辑地图")
	return true


func _reject(message: String) -> bool:
	_last_error = message
	return false


func _push_undo() -> void:
	var copied_placements: Dictionary = {}
	for cell in _placements:
		copied_placements[cell] = _placements[cell].copy()
	_undo_stack.append({
		"placements": copied_placements,
		"fan_directions": _fan_directions.duplicate(),
		"spent_budget": _spent_budget,
	})
	if _undo_stack.size() > 64:
		_undo_stack.pop_front()


func _decorate_result(result: SimulationResult, wind: WindSolution) -> void:
	result.all_turbines_powered = true
	for turbine in _level.turbines:
		if not wind.is_turbine_powered(turbine.id):
			result.all_turbines_powered = false
			break
	for fan in _level.fans:
		if _fan_directions.get(fan.cell, fan.direction) != fan.direction:
			result.rotated_fan_count += 1
	var used_kinds: Dictionary = {}
	for device: PlacedDevice in _placements.values():
		used_kinds[device.kind] = true
	result.device_kind_count = used_kinds.size()
	for door in _level.doors:
		if door.cell in result.route:
			result.traversed_door_count += 1
		else:
			result.bypassed_door_count += 1
