extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var levels := DemoLevels.all_levels()
	_expect(levels.size() == 6, "关卡目录包含6关")
	var ids: Dictionary = {}
	for level in levels:
		_expect(level.validate().is_empty(), "%s通过结构校验" % level.display_name)
		ids[level.level_id] = true
	_expect(ids.size() == levels.size(), "关卡ID互不重复")

	for index in levels.size():
		var session := GameSession.new()
		_expect(session.load_level(levels[index]), "第%d关可加载" % (index + 1))
		_apply_reference_solution(index, session)
		var result := session.start_test()
		_expect(result.succeeded, "第%d关参考解可通关" % (index + 1))
		_expect(result.efficient, "第%d关参考解达到精简预算" % (index + 1))

	_test_final_level_alternate_routes(levels[5])

	var game_flow := get_root().get_node_or_null("GameFlow")
	_expect(game_flow != null, "关卡流程单例已加载")
	game_flow.call("select_level", 0)
	var packed_select := load("res://scenes/level_select.tscn") as PackedScene
	var select_root := packed_select.instantiate()
	get_root().add_child(select_root)
	await process_frame
	var select := select_root as LevelSelect
	_expect(select != null and select.debug_level_count == 6, "关卡选择场景生成6张关卡卡片")
	_expect(select_root.get_node("LevelGrid").get_child_count() == 6, "关卡卡片全部进入场景树")

	print("关卡验证完成：%d checks，%d failures" % [checks, failures])
	select_root.queue_free()
	for _frame in 3:
		await process_frame
	_quit_after_cleanup.call_deferred(1 if failures > 0 else 0)


func _apply_reference_solution(index: int, session: GameSession) -> void:
	match index:
		0:
			session.rotate_at(Vector2i(0, 2))
		1:
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(5, 4), GameRules.Direction.LEFT)
		2:
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(2, 4), GameRules.Direction.LEFT)
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(2, 1), GameRules.Direction.RIGHT)
		3:
			session.place_device(GameRules.DeviceKind.ONE_WAY_VALVE, Vector2i(4, 2), GameRules.Direction.RIGHT)
		4:
			session.rotate_at(Vector2i(0, 0))
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(7, 4), GameRules.Direction.LEFT)
		5:
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 2), GameRules.Direction.DOWN)
			session.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 4), GameRules.Direction.UP)
			session.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(3, 3), GameRules.Direction.UP)
			session.place_device(GameRules.DeviceKind.ONE_WAY_VALVE, Vector2i(9, 4), GameRules.Direction.RIGHT)


func _test_final_level_alternate_routes(level: LevelDefinition) -> void:
	_expect(level.walls.is_empty() and level.required_turbine_ids.is_empty(), "终关开放中层并取消全局供能硬条件")
	var standard := GameSession.new()
	_expect(standard.load_level(level), "终关正规供能路线可加载")
	_apply_reference_solution(5, standard)
	var standard_result := standard.start_test()
	_expect(
		standard_result.succeeded
		and standard_result.traversed_door_count == 1
		and standard_result.all_turbines_powered
		and standard_result.device_kind_count == 3
		and standard_result.route_style_label() == "供能通行",
		"正规路线开门通行并使用三类装置"
	)

	var upper := GameSession.new()
	_expect(upper.load_level(level), "终关上绕路线可加载")
	upper.rotate_at(Vector2i(3, 5))
	upper.rotate_at(Vector2i(10, 4))
	upper.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 2), GameRules.Direction.DOWN)
	upper.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 3), GameRules.Direction.UP)
	upper.place_device(GameRules.DeviceKind.BEND, Vector2i(8, 3), GameRules.Direction.DOWN)
	var upper_result := upper.start_test()
	_expect(
		upper_result.succeeded
		and upper_result.bypassed_door_count == 1
		and not upper_result.all_turbines_powered
		and upper_result.rotated_fan_count == 2
		and upper_result.route_style_label() == "绕门抵达",
		"上绕路线旋开支线并从终点上方绕门抵达"
	)

	var lower := GameSession.new()
	_expect(lower.load_level(level), "终关下绕路线可加载")
	lower.rotate_at(Vector2i(3, 5))
	lower.rotate_at(Vector2i(10, 4))
	lower.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 2), GameRules.Direction.DOWN)
	lower.place_device(GameRules.DeviceKind.BEND, Vector2i(6, 5), GameRules.Direction.UP)
	lower.place_device(GameRules.DeviceKind.BEND, Vector2i(8, 5), GameRules.Direction.LEFT)
	var lower_result := lower.start_test()
	_expect(lower_result.succeeded and lower_result.bypassed_door_count == 1, "下绕路线从终点下方绕门抵达")

	var early_door := GameSession.new()
	_expect(early_door.load_level(level), "终关提前下行路线可加载")
	early_door.place_device(GameRules.DeviceKind.BEND, Vector2i(4, 2), GameRules.Direction.DOWN)
	early_door.place_device(GameRules.DeviceKind.BEND, Vector2i(4, 4), GameRules.Direction.UP)
	early_door.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(3, 3), GameRules.Direction.UP)
	early_door.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(9, 4), GameRules.Direction.UP)
	var early_result := early_door.start_test()
	_expect(early_result.succeeded and early_result.traversed_door_count == 1, "开放中层后可提前下行并继续使用门路线")

	var route_keys: Dictionary = {}
	for result in [standard_result, upper_result, lower_result, early_result]:
		route_keys[_route_key(result.route)] = true
	_expect(route_keys.size() == 4, "终关自动验证四条不同运输路线")


func _route_key(route: Array[Vector2i]) -> String:
	var parts: PackedStringArray = []
	for cell in route:
		parts.append("%d,%d" % [cell.x, cell.y])
	return "|".join(parts)


func _quit_after_cleanup(exit_code: int) -> void:
	quit(exit_code)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)
