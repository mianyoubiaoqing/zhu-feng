extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
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
	_expect(board_view.debug_loaded_art_assets == 34, "BoardView绑定全部34张棋盘图片")
	_expect(audio_director.debug_loaded_audio_assets == 15, "AudioDirector绑定全部15段音频")
	_expect((root.get_node("HUD/Sidebar/MoneyIcon") as TextureRect).texture != null, "HUD绑定预算金币图片")

	var initial_wind_cells := session.debug_wind_cell_count
	var placed := session.place_device(GameRules.DeviceKind.BLOCKER, Vector2i(2, 5))
	_expect(placed and session.debug_device_count == 1 and session.debug_spent_budget == 1, "Session节点同步装置与预算字段")
	_expect(session.debug_wind_cell_count == initial_wind_cells, "无关装置不会改变风场调试统计")

	var result := session.start_test()
	_expect(session.debug_phase == "RESULT" and not session.debug_last_result.is_empty(), "测试结果写入Session调试字段")
	cargo_view.step_duration = 0.01
	cargo_view.play_result(result)
	await create_timer(0.15).timeout
	_expect(not cargo_view.debug_animating and cargo_view.debug_outcome != "PENDING", "CargoView节点完成路线表现并暴露结果")

	session.return_to_build()
	_expect(session.debug_phase == "BUILD", "Session节点返回建造阶段")
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
