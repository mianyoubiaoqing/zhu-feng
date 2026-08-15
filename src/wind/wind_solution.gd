class_name WindSolution
extends RefCounted

var directions_by_cell: Dictionary = {}
var strength_by_cell: Dictionary = {}
var conflict_strength_by_cell: Dictionary = {}
var conflict_cells: Dictionary = {}
var loop_cells: Dictionary = {}
var powered_turbine_ids: Dictionary = {}
var paths: Array = []


func direction_at(cell: Vector2i) -> int:
	if conflict_cells.has(cell):
		return -1
	var directions: Array = directions_by_cell.get(cell, [])
	if directions.size() != 1:
		return -1
	return directions[0]


func strength_at(cell: Vector2i) -> int:
	if conflict_cells.has(cell):
		return int(conflict_strength_by_cell.get(cell, 0))
	return int(strength_by_cell.get(cell, 0))


func has_wind(cell: Vector2i) -> bool:
	return directions_by_cell.has(cell) or conflict_cells.has(cell)


func is_conflict(cell: Vector2i) -> bool:
	return conflict_cells.has(cell)


func is_loop(cell: Vector2i) -> bool:
	return loop_cells.has(cell)


func is_turbine_powered(turbine_id: StringName) -> bool:
	return powered_turbine_ids.has(turbine_id)


func cells() -> Array:
	var result := directions_by_cell.keys()
	for cell in conflict_cells:
		if cell not in result:
			result.append(cell)
	return result
