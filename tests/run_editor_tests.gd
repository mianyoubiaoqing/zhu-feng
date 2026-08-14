extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_codec_round_trip()
	var game_flow := get_root().get_node_or_null("GameFlow")
	_expect(game_flow != null, "关卡流程单例可承载工坊关卡")
	game_flow.call("clear_custom_level")

	var packed_editor := load("res://scenes/level_editor.tscn") as PackedScene
	var editor_root := packed_editor.instantiate()
	get_root().add_child(editor_root)
	await process_frame
	var editor := editor_root as LevelEditor
	_expect(editor != null, "关卡工坊场景可实例化")
	_expect(editor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "空白棋盘点击不会被根 UI 截获")
	_expect(editor_root.get_node_or_null("EditorBoard") is LevelEditorBoard, "棋盘为独立可调试节点")
	_expect(editor_root.get_node_or_null("LeftPanel/Wall") is Button and editor_root.get_node_or_null("RightPanel/Test") is Button, "绘制与试玩控件均落实到节点")
	_expect(editor.level_definition().validate().is_empty(), "默认空白关卡通过结构校验")
	var board := editor_root.get_node("EditorBoard") as LevelEditorBoard
	var pointer := board.debug_board_origin + Vector2(2.5, 1.5) * board.debug_cell_size
	var board_input := editor_root.get_node("BoardInput") as Control
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pointer - board_input.position
	click.global_position = pointer
	board_input.gui_input.emit(click)
	await process_frame
	_expect(editor.level_definition().walls.has(Vector2i(2, 1)), "棋盘输入节点接收鼠标事件并绘制当前工具")

	editor.select_tool(LevelEditor.Tool.WALL)
	_expect(editor.apply_tool_at(Vector2i(3, 2)), "墙体工具可绘制")
	editor.select_tool(LevelEditor.Tool.PIT)
	_expect(editor.apply_tool_at(Vector2i(4, 2)), "深坑工具可绘制")
	(editor_root.get_node("RightPanel/LinkEdit") as LineEdit).text = "switch_a"
	editor.select_tool(LevelEditor.Tool.TURBINE)
	_expect(editor.apply_tool_at(Vector2i(5, 2)), "涡轮工具可绘制联动机关")
	editor.select_tool(LevelEditor.Tool.DOOR)
	_expect(editor.apply_tool_at(Vector2i(6, 2)), "门工具可引用联动 ID")
	var built := editor.level_definition()
	_expect(built.walls.has(Vector2i(3, 2)) and built.pits.has(Vector2i(4, 2)), "地形写入 LevelDefinition")
	_expect(built.turbines.size() == 1 and built.doors.size() == 1 and built.required_turbine_ids.has(&"switch_a"), "机关联动与通关条件写入 LevelDefinition")
	_expect(built.validate().is_empty(), "绘制后的关卡通过结构校验")
	_expect(game_flow.call("set_custom_level", built) as bool, "自定义关卡可交给试玩流程")
	var selected := game_flow.call("selected_level") as LevelDefinition
	_expect(selected.level_id == &"custom_workshop" and selected.doors.size() == 1, "试玩流程读取工坊关卡而非正式关卡")

	editor_root.queue_free()
	for _frame in 3:
		await process_frame
	var packed_game := load("res://scenes/main.tscn") as PackedScene
	var game_root := packed_game.instantiate()
	get_root().add_child(game_root)
	await process_frame
	var session := game_root.get_node("Session") as GameSessionNode
	_expect(session.is_initialized() and session.level().level_id == &"custom_workshop", "完整游戏场景可初始化工坊关卡")
	_expect((game_root.get_node("HUD/Title") as Label).text.contains("工坊试玩"), "试玩 HUD 明确标注工坊关卡")
	_expect((game_root.get_node("HUD/LevelSelect") as Button).text == "返回工坊", "试玩可返回继续编辑")

	print("编辑器验证完成：%d checks，%d failures" % [checks, failures])
	(game_root.get_node("AudioDirector") as AudioDirector).stop_all_audio()
	game_root.queue_free()
	game_flow.call("clear_custom_level")
	for _frame in 4:
		await process_frame
	_quit_after_cleanup.call_deferred(1 if failures > 0 else 0)


func _test_codec_round_trip() -> void:
	var source := DemoLevels.build_level(5)
	var json := LevelCodec.to_json(source)
	var restored := LevelCodec.from_json(json)
	_expect(not json.is_empty() and restored != null, "关卡可编码并解码 JSON")
	_expect(restored.size == source.size and restored.start == source.start and restored.goal == source.goal, "JSON 保留画布与起终点")
	_expect(restored.fans.size() == source.fans.size() and restored.fans[0].direction == source.fans[0].direction, "JSON 保留风机位置与方向")
	_expect(restored.turbines.size() == source.turbines.size() and restored.doors.size() == source.doors.size(), "JSON 保留涡轮与门")
	_expect(restored.validate().is_empty(), "JSON 往返后的关卡仍可加载")


func _quit_after_cleanup(exit_code: int) -> void:
	quit(exit_code)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)
