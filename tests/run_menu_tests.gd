extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/start_menu.tscn") as PackedScene
	var root := packed_scene.instantiate()
	get_root().add_child(root)
	await process_frame

	var menu := root as StartMenu
	var title := root.get_node("MenuPanel/Title") as TextureRect
	var start_button := root.get_node("MenuPanel/Start") as Button
	var exit_button := root.get_node("MenuPanel/Exit") as Button
	_expect(menu != null, "开始菜单节点实例化")
	_expect(menu.debug_title_texture_ready and title.texture != null, "标题有效区域已绑定")
	_expect(menu.gameplay_scene_path == "res://scenes/level_select.tscn" and ResourceLoader.exists(menu.gameplay_scene_path), "开始按钮目标为关卡选择")
	_expect(not start_button.get_signal_connection_list(&"pressed").is_empty(), "开始按钮已连接")
	_expect(not exit_button.get_signal_connection_list(&"pressed").is_empty(), "退出按钮已连接")
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start_menu.tscn", "项目启动入口为开始菜单")

	print("菜单验证完成：%d checks，%d failures" % [checks, failures])
	root.queue_free()
	for _frame in 3:
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
