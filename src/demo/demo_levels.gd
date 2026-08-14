class_name DemoLevels
extends RefCounted

const LEVEL_COUNT := 6


static func all_levels() -> Array[LevelDefinition]:
	return [
		build_fan_rotation(),
		build_first_bend(),
		build_pit_detour(),
		build_valve_isolation(),
		build_dual_supply(),
		build_full_workshop(),
	]


static func build_level(index: int) -> LevelDefinition:
	var levels := all_levels()
	return levels[clampi(index, 0, levels.size() - 1)]


static func build_fan_rotation() -> LevelDefinition:
	var level := _base(&"fan_rotation", "转动风机", "让唯一的风机吹向风种。", "点击风机会顺时针旋转；本关不需要放置装置。")
	level.size = Vector2i(7, 5)
	level.budget = 0
	level.efficient_budget = 0
	level.start = Vector2i(1, 2)
	level.goal = Vector2i(6, 2)
	level.fans = [FanDefinition.create(Vector2i(0, 2), GameRules.Direction.UP)]
	return level


static func build_first_bend() -> LevelDefinition:
	var level := _base(&"first_bend", "第一道弯", "用一块导风板把横向风转向上方终点。", "导风板连接相邻的两个方向；放置后可继续旋转。")
	level.size = Vector2i(7, 6)
	level.budget = 4
	level.efficient_budget = 2
	level.start = Vector2i(1, 4)
	level.goal = Vector2i(5, 1)
	level.fans = [FanDefinition.create(Vector2i(0, 4), GameRules.Direction.RIGHT)]
	level.walls = [Vector2i(6, 4)]
	return level


static func build_pit_detour() -> LevelDefinition:
	var level := _base(&"pit_detour", "绕开深渊", "用两次转弯绕过下方裂隙。", "直接前进会坠落；先决定绕行路线，再核算导风板费用。")
	level.size = Vector2i(9, 6)
	level.budget = 6
	level.efficient_budget = 4
	level.start = Vector2i(1, 4)
	level.goal = Vector2i(8, 1)
	level.fans = [FanDefinition.create(Vector2i(0, 4), GameRules.Direction.RIGHT)]
	level.pits = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]
	return level


static func build_valve_isolation() -> LevelDefinition:
	var level := _base(&"valve_isolation", "风阀分流", "保留横向运输风，同时让下方风机为涡轮供能。", "在两路风的交叉格放置单向风阀；旋走下方风机会导致涡轮失去供能。")
	level.size = Vector2i(9, 6)
	level.budget = 4
	level.efficient_budget = 2
	level.start = Vector2i(1, 2)
	level.goal = Vector2i(8, 2)
	level.fans = [
		FanDefinition.create(Vector2i(0, 2), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(4, 5), GameRules.Direction.UP),
	]
	level.turbines = [TurbineDefinition.create(&"mint", Vector2i(4, 4))]
	level.required_turbine_ids = [&"mint"]
	return level


static func build_dual_supply() -> LevelDefinition:
	var level := _base(&"dual_supply", "双路供能", "一条风路运送风种，另一条风路开启终点前的门。", "上方风机只负责供能；下方风机需要一块导风板把风种送向门。")
	level.size = Vector2i(9, 6)
	level.budget = 4
	level.efficient_budget = 2
	level.start = Vector2i(1, 4)
	level.goal = Vector2i(7, 1)
	level.fans = [
		FanDefinition.create(Vector2i(0, 4), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(0, 0), GameRules.Direction.UP),
	]
	level.turbines = [TurbineDefinition.create(&"amber", Vector2i(4, 0))]
	level.doors = [DoorDefinition.create(Vector2i(7, 2), &"amber")]
	level.required_turbine_ids = [&"amber"]
	level.walls = [Vector2i(6, 0)]
	return level


static func build_full_workshop() -> LevelDefinition:
	var level := _base(&"full_workshop", "风路工坊", "让风种抵达终点；供能开门或绕开门都算完成。", "门只封锁所在格。可保留供能路线，也可旋转风机，从终点上方或下方进入。")
	level.size = Vector2i(11, 6)
	level.budget = 9
	level.efficient_budget = 7
	level.start = Vector2i(1, 2)
	level.goal = Vector2i(8, 4)
	level.fans = [
		FanDefinition.create(Vector2i(0, 2), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(3, 5), GameRules.Direction.UP),
		FanDefinition.create(Vector2i(10, 4), GameRules.Direction.LEFT),
	]
	level.pits = [Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2)]
	level.turbines = [TurbineDefinition.create(&"core", Vector2i(3, 4))]
	level.doors = [DoorDefinition.create(Vector2i(7, 4), &"core")]
	return level


static func build_vertical_slice() -> LevelDefinition:
	return build_full_workshop()


static func _base(id: StringName, name: String, objective_text: String, tip: String) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_id = id
	level.display_name = name
	level.objective = objective_text
	level.teaching_tip = tip
	return level
