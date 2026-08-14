extends Node

signal selection_changed(level_index: int)
signal completion_changed(level_index: int)

var selected_level_index := 0
var _completed_levels: Dictionary = {}


func select_level(index: int) -> bool:
	if index < 0 or index >= DemoLevels.LEVEL_COUNT:
		return false
	selected_level_index = index
	selection_changed.emit(index)
	return true


func selected_level() -> LevelDefinition:
	return DemoLevels.build_level(selected_level_index)


func mark_selected_completed() -> void:
	_completed_levels[selected_level_index] = true
	completion_changed.emit(selected_level_index)


func is_completed(index: int) -> bool:
	return bool(_completed_levels.get(index, false))


func select_next_level() -> bool:
	return select_level(selected_level_index + 1)


func completed_count() -> int:
	return _completed_levels.size()
