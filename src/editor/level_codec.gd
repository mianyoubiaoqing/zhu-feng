class_name LevelCodec
extends RefCounted


static func to_dictionary(level: LevelDefinition) -> Dictionary:
	var fans: Array[Dictionary] = []
	for fan in level.fans:
		fans.append({"cell": _cell_to_array(fan.cell), "direction": fan.direction})
	var turbines: Array[Dictionary] = []
	for turbine in level.turbines:
		turbines.append({"id": String(turbine.id), "cell": _cell_to_array(turbine.cell)})
	var doors: Array[Dictionary] = []
	for door in level.doors:
		doors.append({"cell": _cell_to_array(door.cell), "turbine_id": String(door.turbine_id)})
	return {
		"format_version": 1,
		"level_id": String(level.level_id),
		"display_name": level.display_name,
		"objective": level.objective,
		"teaching_tip": level.teaching_tip,
		"size": _cell_to_array(level.size),
		"budget": level.budget,
		"efficient_budget": level.efficient_budget,
		"start": _cell_to_array(level.start),
		"goal": _cell_to_array(level.goal),
		"walls": _cells_to_array(level.walls),
		"pits": _cells_to_array(level.pits),
		"fans": fans,
		"turbines": turbines,
		"doors": doors,
		"required_turbine_ids": level.required_turbine_ids.map(func(id: StringName) -> String: return String(id)),
	}


static func from_dictionary(data: Dictionary) -> LevelDefinition:
	if not data.has("size") or not data.has("start") or not data.has("goal"):
		return null
	var level := LevelDefinition.new()
	level.level_id = StringName(str(data.get("level_id", "custom_workshop")))
	level.display_name = str(data.get("display_name", "我的风路"))
	level.objective = str(data.get("objective", "让风种抵达终点。"))
	level.teaching_tip = str(data.get("teaching_tip", "先观察风向，再开始施工。"))
	level.size = _array_to_cell(data.get("size"), Vector2i(10, 6))
	level.budget = int(data.get("budget", 8))
	level.efficient_budget = int(data.get("efficient_budget", min(level.budget, 6)))
	level.start = _array_to_cell(data.get("start"), Vector2i(1, 3))
	level.goal = _array_to_cell(data.get("goal"), Vector2i(8, 3))
	level.walls = _array_to_cells(data.get("walls", []))
	level.pits = _array_to_cells(data.get("pits", []))
	var fans: Array[FanDefinition] = []
	for entry in _dictionary_array(data.get("fans", [])):
		fans.append(FanDefinition.create(
			_array_to_cell(entry.get("cell"), Vector2i.ZERO),
			wrapi(int(entry.get("direction", GameRules.Direction.RIGHT)), 0, 4)
		))
	level.fans = fans
	var turbines: Array[TurbineDefinition] = []
	for entry in _dictionary_array(data.get("turbines", [])):
		turbines.append(TurbineDefinition.create(
			StringName(str(entry.get("id", "wind_1"))),
			_array_to_cell(entry.get("cell"), Vector2i.ZERO)
		))
	level.turbines = turbines
	var doors: Array[DoorDefinition] = []
	for entry in _dictionary_array(data.get("doors", [])):
		doors.append(DoorDefinition.create(
			_array_to_cell(entry.get("cell"), Vector2i.ZERO),
			StringName(str(entry.get("turbine_id", "wind_1")))
		))
	level.doors = doors
	var required_ids: Array[StringName] = []
	var raw_required: Variant = data.get("required_turbine_ids", [])
	if raw_required is Array:
		for id in raw_required:
			required_ids.append(StringName(str(id)))
	level.required_turbine_ids = required_ids
	return level


static func to_json(level: LevelDefinition) -> String:
	return JSON.stringify(to_dictionary(level), "\t", false)


static func from_json(text: String) -> LevelDefinition:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		return null
	return from_dictionary(parsed)


static func _cell_to_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


static func _cells_to_array(cells: Array[Vector2i]) -> Array[Array]:
	var result: Array[Array] = []
	for cell in cells:
		result.append(_cell_to_array(cell))
	return result


static func _array_to_cell(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func _array_to_cells(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for entry in value:
			if entry is Array and entry.size() >= 2:
				result.append(_array_to_cell(entry, Vector2i.ZERO))
	return result


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry)
	return result
