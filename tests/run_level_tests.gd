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


func _quit_after_cleanup(exit_code: int) -> void:
	quit(exit_code)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)
