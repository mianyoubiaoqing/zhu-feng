extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	_test_straight_wind()
	_test_bend()
	_test_blocker()
	_test_valve()
	_test_same_direction_merge()
	_test_opposite_wind_conflict()
	_test_loop_detection()
	_test_turbine_door_and_cargo()
	_test_budget_and_undo()
	_test_ten_run_determinism()
	print("规则验证完成：%d checks，%d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_straight_wind() -> void:
	var level := _level(Vector2i(5, 3))
	level.fans = [FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT)]
	var wind := WindSolver.solve(level, {}, {})
	_expect(wind.direction_at(Vector2i(3, 1)) == GameRules.Direction.RIGHT, "直线风传播")


func _test_bend() -> void:
	var level := _level(Vector2i(4, 4))
	level.fans = [FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT)]
	var placements := {Vector2i(2, 1): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(2, 1), GameRules.Direction.DOWN)}
	var wind := WindSolver.solve(level, placements, {})
	_expect(wind.direction_at(Vector2i(2, 1)) == GameRules.Direction.DOWN, "双向弯管转向")
	_expect(wind.direction_at(Vector2i(2, 2)) == GameRules.Direction.DOWN, "转向后继续传播")


func _test_blocker() -> void:
	var level := _level(Vector2i(5, 3))
	level.fans = [FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT)]
	var placements := {Vector2i(2, 1): PlacedDevice.new(GameRules.DeviceKind.BLOCKER, Vector2i(2, 1))}
	var wind := WindSolver.solve(level, placements, {})
	_expect(not wind.has_wind(Vector2i(2, 1)), "挡风板截断风")


func _test_valve() -> void:
	var level := _level(Vector2i(5, 3))
	level.fans = [FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT)]
	var passing := {Vector2i(2, 1): PlacedDevice.new(GameRules.DeviceKind.ONE_WAY_VALVE, Vector2i(2, 1), GameRules.Direction.RIGHT)}
	var blocking := {Vector2i(2, 1): PlacedDevice.new(GameRules.DeviceKind.ONE_WAY_VALVE, Vector2i(2, 1), GameRules.Direction.LEFT)}
	_expect(WindSolver.solve(level, passing, {}).has_wind(Vector2i(3, 1)), "单向风阀允许同向风")
	_expect(not WindSolver.solve(level, blocking, {}).has_wind(Vector2i(2, 1)), "单向风阀拦截反向风")


func _test_same_direction_merge() -> void:
	var level := _level(Vector2i(6, 3))
	level.fans = [
		FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(2, 1), GameRules.Direction.RIGHT),
	]
	var wind := WindSolver.solve(level, {}, {})
	_expect(not wind.is_conflict(Vector2i(3, 1)), "同向风合并而不冲突")
	_expect(wind.direction_at(Vector2i(4, 1)) == GameRules.Direction.RIGHT, "合并风继续传播")


func _test_opposite_wind_conflict() -> void:
	var level := _level(Vector2i(5, 3))
	level.fans = [
		FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT),
		FanDefinition.create(Vector2i(4, 1), GameRules.Direction.LEFT),
	]
	var wind := WindSolver.solve(level, {}, {})
	_expect(wind.is_conflict(Vector2i(2, 1)), "异向风完全抵消")
	_expect(wind.direction_at(Vector2i(2, 1)) < 0, "冲突格没有有效方向")


func _test_loop_detection() -> void:
	var level := _level(Vector2i(4, 4))
	level.fans = [FanDefinition.create(Vector2i(1, 1), GameRules.Direction.RIGHT)]
	var placements := {
		Vector2i(2, 1): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(2, 1), GameRules.Direction.DOWN),
		Vector2i(2, 2): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(2, 2), GameRules.Direction.LEFT),
		Vector2i(0, 2): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(0, 2), GameRules.Direction.UP),
		Vector2i(0, 1): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(0, 1), GameRules.Direction.RIGHT),
	}
	var wind := WindSolver.solve(level, placements, {})
	_expect(wind.is_loop(Vector2i(1, 1)), "闭环被标记")


func _test_turbine_door_and_cargo() -> void:
	var level := _level(Vector2i(7, 3))
	level.start = Vector2i(1, 1)
	level.goal = Vector2i(6, 1)
	level.fans = [FanDefinition.create(Vector2i(0, 1), GameRules.Direction.RIGHT)]
	level.turbines = [TurbineDefinition.create(&"t1", Vector2i(3, 1))]
	level.doors = [DoorDefinition.create(Vector2i(5, 1), &"t1")]
	level.required_turbine_ids = [&"t1"]
	var wind := WindSolver.solve(level, {}, {})
	var result := CargoSimulator.simulate(level, wind, 4)
	_expect(wind.is_turbine_powered(&"t1"), "涡轮在风场阶段供能")
	_expect(result.succeeded, "供能后风种穿门抵达终点")


func _test_budget_and_undo() -> void:
	var level := _level(Vector2i(5, 3))
	level.budget = 2
	level.efficient_budget = 1
	var session := GameSession.new()
	_expect(session.load_level(level), "会话加载合法关卡")
	_expect(session.place_device(GameRules.DeviceKind.BEND, Vector2i(2, 1)), "预算内可放置")
	_expect(not session.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(3, 1)), "超过预算时拒绝放置")
	_expect(session.undo() and session.spent_budget() == 0, "撤销恢复预算和布局")


func _test_ten_run_determinism() -> void:
	var level := _level(Vector2i(7, 5))
	level.start = Vector2i(1, 2)
	level.goal = Vector2i(5, 3)
	level.fans = [FanDefinition.create(Vector2i(0, 2), GameRules.Direction.RIGHT)]
	var placements := {
		Vector2i(3, 2): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(3, 2), GameRules.Direction.DOWN),
		Vector2i(3, 3): PlacedDevice.new(GameRules.DeviceKind.BEND, Vector2i(3, 3), GameRules.Direction.LEFT),
	}
	var baseline := ""
	var stable := true
	for run_index in 10:
		var wind := WindSolver.solve(level, placements, {})
		var simulation := CargoSimulator.simulate(level, wind, 4)
		var fingerprint := "%s|%s|%s|%s" % [
			wind.directions_by_cell,
			wind.conflict_cells,
			wind.loop_cells,
			simulation.route,
		]
		if run_index == 0:
			baseline = fingerprint
		elif fingerprint != baseline:
			stable = false
	_expect(stable, "相同布局连续运行10次结果一致")


func _level(grid_size: Vector2i) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.size = grid_size
	level.start = Vector2i(1, 1)
	level.goal = Vector2i(grid_size.x - 1, 1)
	level.budget = 20
	level.efficient_budget = 10
	return level


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)
