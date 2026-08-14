class_name LevelDefinition
extends Resource

@export var level_id: StringName = &"unnamed"
@export var display_name := "未命名关卡"
@export_multiline var objective := "让风种抵达终点"
@export_multiline var teaching_tip := "观察风向，再开始施工。"
@export var size: Vector2i = Vector2i(8, 6)
@export var budget := 8
@export var efficient_budget := 6
@export var start: Vector2i = Vector2i.ZERO
@export var goal: Vector2i = Vector2i(7, 5)
@export var walls: Array[Vector2i] = []
@export var pits: Array[Vector2i] = []
@export var fans: Array[FanDefinition] = []
@export var turbines: Array[TurbineDefinition] = []
@export var doors: Array[DoorDefinition] = []
@export var required_turbine_ids: Array[StringName] = []


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_wall(cell: Vector2i) -> bool:
	return cell in walls


func is_pit(cell: Vector2i) -> bool:
	return cell in pits


func fan_at(cell: Vector2i) -> FanDefinition:
	for fan in fans:
		if fan.cell == cell:
			return fan
	return null


func turbine_at(cell: Vector2i) -> TurbineDefinition:
	for turbine in turbines:
		if turbine.cell == cell:
			return turbine
	return null


func door_at(cell: Vector2i) -> DoorDefinition:
	for door in doors:
		if door.cell == cell:
			return door
	return null


func is_fixed_object(cell: Vector2i) -> bool:
	return cell == start or cell == goal or fan_at(cell) != null or turbine_at(cell) != null or door_at(cell) != null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if size.x <= 0 or size.y <= 0:
		errors.append("关卡尺寸必须为正数")
	if not contains(start):
		errors.append("风种起点超出地图")
	if not contains(goal):
		errors.append("终点超出地图")
	if budget < 0 or efficient_budget < 0 or efficient_budget > budget:
		errors.append("预算必须满足 0 <= 精简预算 <= 施工预算")
	for cell in walls + pits:
		if not contains(cell):
			errors.append("地形格超出地图: %s" % cell)
	for fan in fans:
		if not contains(fan.cell):
			errors.append("风机超出地图: %s" % fan.cell)
	for turbine in turbines:
		if not contains(turbine.cell):
			errors.append("涡轮超出地图: %s" % turbine.cell)
	for door in doors:
		if not contains(door.cell):
			errors.append("门超出地图: %s" % door.cell)
		if not _has_turbine_id(door.turbine_id):
			errors.append("门引用了不存在的涡轮: %s" % door.turbine_id)
	for required_id in required_turbine_ids:
		if not _has_turbine_id(required_id):
			errors.append("通关条件引用了不存在的涡轮: %s" % required_id)
	return errors


func _has_turbine_id(turbine_id: StringName) -> bool:
	for turbine in turbines:
		if turbine.id == turbine_id:
			return true
	return false
