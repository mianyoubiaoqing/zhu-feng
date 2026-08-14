class_name DemoLevels
extends RefCounted


static func build_vertical_slice() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_id = &"vertical_slice"
	level.display_name = "灰盒：供能与送达"
	level.size = Vector2i(9, 6)
	level.budget = 10
	level.efficient_budget = 7
	level.start = Vector2i(1, 3)
	level.goal = Vector2i(8, 2)
	level.walls = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
	level.pits = [Vector2i(6, 4), Vector2i(7, 4)]
	level.fans = [
		FanDefinition.create(Vector2i(0, 3), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(8, 5), GameRules.Direction.UP),
	]
	level.turbines = [TurbineDefinition.create(&"amber", Vector2i(5, 1))]
	level.doors = [DoorDefinition.create(Vector2i(7, 2), &"amber")]
	level.required_turbine_ids = [&"amber"]
	return level
