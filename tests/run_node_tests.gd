extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_flow := get_root().get_node_or_null("GameFlow")
	_expect(game_flow != null, "关卡流程单例已加载")
	game_flow.call("select_level", 5)
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var root := packed_scene.instantiate()
	get_root().add_child(root)
	await process_frame

	var session := root.get_node("Session") as GameSessionNode
	var build_controller := root.get_node("BuildController") as BuildControllerNode
	var board_view := root.get_node("BoardView") as BoardView
	var cargo_view := root.get_node("CargoView") as CargoView
	var audio_director := root.get_node("AudioDirector") as AudioDirector
	_expect(session != null and build_controller != null and board_view != null and cargo_view != null and audio_director != null, "调试节点全部实例化")
	_expect(session.is_initialized() and session.debug_phase == "BUILD", "Session节点初始化并暴露建造阶段")
	_expect(is_equal_approx(board_view.cell_size, cargo_view.cell_size) and board_view.board_origin.is_equal_approx(cargo_view.board_origin), "棋盘与风种共享自适应坐标")
	_expect(board_view.cell_size >= 88.0 and board_view.cell_size <= 140.0, "六关棋盘尺寸保持在可读范围")
	_expect(board_view.debug_loaded_art_assets == 38, "BoardView绑定新增风机、挡风板和门状态图片")
	_expect(cargo_view.debug_loaded_art_assets == 1, "CargoView绑定风种图片")
	_expect(audio_director.debug_loaded_audio_assets == 15, "AudioDirector绑定全部15段音频")
	_expect((root.get_node("HUD/Sidebar/MoneyIcon") as TextureRect).texture != null, "HUD绑定预算金币图片")
	var sidebar := root.get_node("HUD/Sidebar") as Panel
	var panel_style := sidebar.get_theme_stylebox("panel") as StyleBoxTexture
	_expect(panel_style != null and panel_style.texture != null, "施工侧栏绑定美术面板")
	var skinned_buttons := true
	for button_name in ["Bend", "Blocker", "Valve", "Undo", "Start", "Build", "Retry"]:
		var button := sidebar.get_node(button_name) as Button
		var button_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		if button_style == null or button_style.texture == null:
			skinned_buttons = false
	_expect(skinned_buttons, "施工按钮绑定裁切后的UI美术")
	var bend_button := sidebar.get_node("Bend") as Button
	_expect(bend_button.button_pressed, "默认装置以持续高亮反馈当前选择")
	var hover_timer := root.get_node("HUD/DeviceHoverTimer") as Timer
	var device_tooltip := root.get_node("HUD/DeviceTooltip") as Panel
	_expect(is_equal_approx(hover_timer.wait_time, 0.5) and hover_timer.one_shot, "设施说明使用0.5秒单次悬停计时")
	_expect(not device_tooltip.visible, "设施说明默认隐藏")
	bend_button.mouse_entered.emit()
	await create_timer(0.55).timeout
	_expect(device_tooltip.visible and (device_tooltip.get_node("Label") as Label).text.contains("导风板 · 2金币"), "导风板悬停0.5秒后显示用途与价格")
	bend_button.mouse_exited.emit()
	_expect(not device_tooltip.visible, "鼠标移开后收起设施说明")
	_expect(root.get_node_or_null("HUD/LevelSelect") != null and root.get_node_or_null("HUD/Next") != null, "关卡导航避开施工面板并保持可用")
	var next_button := root.get_node("HUD/Next") as Button
	var message := root.get_node("HUD/Message") as Label
	var board_right := board_view.board_origin.x + float(session.level().size.x) * board_view.cell_size
	var board_bottom := board_view.board_origin.y + float(session.level().size.y) * board_view.cell_size
	_expect(next_button.position.y > board_bottom, "下一关按钮位于地图下方")
	_expect(is_equal_approx(next_button.position.x + next_button.size.x, board_right), "下一关按钮与地图右边缘对齐")
	_expect(not next_button.get_rect().intersects(message.get_rect()), "下一关按钮不遮挡状态文字")
	_expect(not (root.get_node("HUD/RuntimeStats") as Label).visible, "发布态默认隐藏运行时调试信息")

	var initial_wind_cells := session.debug_wind_cell_count
	var placed := session.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(2, 5))
	_expect(placed and session.debug_device_count == 1 and session.debug_spent_budget == 1, "Session节点同步装置与预算字段")
	_expect(session.debug_wind_cell_count == initial_wind_cells, "无关装置不会改变风场调试统计")

	var result := session.start_test()
	_expect(session.debug_phase == "RESULT" and not session.debug_last_result.is_empty(), "测试结果写入Session调试字段")
	cargo_view.step_duration = 0.01
	cargo_view.play_result(result)
	var animation_frames := 0
	while cargo_view.debug_animating and animation_frames < 120:
		await process_frame
		animation_frames += 1
	_expect(not cargo_view.debug_animating and cargo_view.debug_outcome != "PENDING", "CargoView节点完成路线表现并暴露结果")
	var result_panel := root.get_node("HUD/ResultPanel") as Panel
	var result_title := root.get_node("HUD/ResultPanel/Title") as Label
	_expect(result_panel.visible and result_title.text == "风路未接通", "失败结果通过独立结算面板呈现")

	root.call("_on_return_to_build")
	_expect(session.debug_phase == "BUILD", "Session节点返回建造阶段")
	_expect(not result_panel.visible and sidebar.modulate.is_equal_approx(Color.WHITE), "返回施工时恢复侧栏并收起结算面板")
	print("节点验证完成：%d checks，%d failures" % [checks, failures])
	audio_director.stop_all_audio()
	for _audio_frame in 2:
		await process_frame
	root.queue_free()
	for _frame in 4:
		await process_frame
	_quit_after_cleanup.call_deferred(1 if failures > 0 else 0)


func _quit_after_cleanup(exit_code: int) -> void:
	quit(exit_code)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)
