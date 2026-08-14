extends Node

signal selection_changed(level_index: int)
signal completion_changed(level_index: int)

var selected_level_index := 0
var _completed_levels: Dictionary = {}
var _custom_level: LevelDefinition


func select_level(index: int) -> bool:
	if index < 0 or index >= DemoLevels.LEVEL_COUNT:
		return false
	_custom_level = null
	selected_level_index = index
	selection_changed.emit(index)
	return true


func selected_level() -> LevelDefinition:
	if _custom_level != null:
		return _custom_level.duplicate(true) as LevelDefinition
	return DemoLevels.build_level(selected_level_index)


func set_custom_level(level: LevelDefinition) -> bool:
	if level == null or not level.validate().is_empty():
		return false
	_custom_level = level.duplicate(true) as LevelDefinition
	return true


func custom_level() -> LevelDefinition:
	return _custom_level.duplicate(true) as LevelDefinition if _custom_level != null else null


func has_custom_level() -> bool:
	return _custom_level != null


func clear_custom_level() -> void:
	_custom_level = null


func mark_selected_completed() -> void:
	if _custom_level != null:
		return
	_completed_levels[selected_level_index] = true
	completion_changed.emit(selected_level_index)


func is_completed(index: int) -> bool:
	return bool(_completed_levels.get(index, false))


func select_next_level() -> bool:
	return select_level(selected_level_index + 1)


func completed_count() -> int:
	return _completed_levels.size()
