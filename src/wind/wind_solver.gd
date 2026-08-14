class_name WindSolver
extends RefCounted

## Interface: solve one immutable level/build snapshot and return all observable wind facts.
## The result is deterministic, has no Node dependencies, and performs no side effects.
static func solve(level: LevelDefinition, placements: Dictionary, fan_directions: Dictionary) -> WindSolution:
	var raw_paths: Array = []
	for fan in level.fans:
		var direction: int = fan_directions.get(fan.cell, fan.direction)
		raw_paths.append(_trace_path(level, placements, fan.cell, direction))

	var active_lengths: Array[int] = []
	for path in raw_paths:
		active_lengths.append(path.entries.size())

	var conflicts := _truncate_at_conflicts(raw_paths, active_lengths)
	var solution := WindSolution.new()
	solution.conflict_cells = conflicts

	for path_index in raw_paths.size():
		var path = raw_paths[path_index]
		var visible_entries: Array = path.entries.slice(0, active_lengths[path_index])
		solution.paths.append(visible_entries)
		for entry in visible_entries:
			_add_direction(solution.directions_by_cell, entry.cell, entry.direction)
		if path.loop_start >= 0 and path.loop_start < active_lengths[path_index]:
			for entry_index in range(path.loop_start, active_lengths[path_index]):
				solution.loop_cells[visible_entries[entry_index].cell] = true

	for turbine in level.turbines:
		if solution.has_wind(turbine.cell) and not solution.is_conflict(turbine.cell) and not solution.is_loop(turbine.cell):
			solution.powered_turbine_ids[turbine.id] = true
	return solution


static func _trace_path(level: LevelDefinition, placements: Dictionary, start: Vector2i, initial_direction: int) -> Dictionary:
	var entries: Array = []
	var visited: Dictionary = {}
	var cell := start
	var direction := initial_direction
	var loop_start := -1
	var safety_limit: int = maxi(8, level.size.x * level.size.y * 4 + 1)

	for _step in safety_limit:
		if not level.contains(cell) or level.is_wall(cell):
			break
		if cell != start:
			var device: PlacedDevice = placements.get(cell)
			if device != null:
				direction = _transform_direction(device, direction)
				if direction < 0:
					break
		var state := Vector3i(cell.x, cell.y, direction)
		if visited.has(state):
			loop_start = visited[state]
			break
		visited[state] = entries.size()
		entries.append({"cell": cell, "direction": direction})
		cell += GameRules.vector(direction)

	return {"entries": entries, "loop_start": loop_start}


static func _transform_direction(device: PlacedDevice, incoming_direction: int) -> int:
	match device.kind:
		GameRules.DeviceKind.BLOCKER:
			return -1
		GameRules.DeviceKind.ONE_WAY_VALVE:
			return incoming_direction if incoming_direction == device.orientation else -1
		GameRules.DeviceKind.BEND:
			var port_a := device.orientation
			var port_b := GameRules.clockwise(device.orientation)
			var entry_side := GameRules.opposite(incoming_direction)
			if entry_side == port_a:
				return port_b
			if entry_side == port_b:
				return port_a
	return -1


static func _truncate_at_conflicts(paths: Array, active_lengths: Array[int]) -> Dictionary:
	var conflicts: Dictionary = {}
	while true:
		var current_conflicts: Dictionary = {}
		for first_path_index in paths.size():
			for second_path_index in range(first_path_index + 1, paths.size()):
				var collision_cell := _find_pair_collision(
					paths[first_path_index].entries,
					active_lengths[first_path_index],
					paths[second_path_index].entries,
					active_lengths[second_path_index]
				)
				if collision_cell != Vector2i(-1, -1):
					current_conflicts[collision_cell] = true

		var changed := false
		for path_index in paths.size():
			var entries: Array = paths[path_index].entries
			for entry_index in active_lengths[path_index]:
				if current_conflicts.has(entries[entry_index].cell):
					var new_length := entry_index + 1
					if new_length < active_lengths[path_index]:
						active_lengths[path_index] = new_length
						changed = true
					break
		conflicts = current_conflicts
		if not changed:
			return conflicts
	return conflicts


## Wind fronts advance one grid cell per logical step. When two paths overlap in
## opposite directions, their collision is the shared cell both fronts can reach
## earliest, rather than every cell in the overlapping corridor.
static func _find_pair_collision(first_entries: Array, first_length: int, second_entries: Array, second_length: int) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_time := 2147483647
	var best_total_distance := 2147483647
	for first_index in first_length:
		var first_entry = first_entries[first_index]
		for second_index in second_length:
			var second_entry = second_entries[second_index]
			if first_entry.cell != second_entry.cell or first_entry.direction == second_entry.direction:
				continue
			var arrival_time: int = maxi(first_index, second_index)
			var total_distance: int = first_index + second_index
			if arrival_time < best_time or (arrival_time == best_time and total_distance < best_total_distance):
				best_cell = first_entry.cell
				best_time = arrival_time
				best_total_distance = total_distance
	return best_cell


static func _add_direction(target: Dictionary, cell: Vector2i, direction: int) -> void:
	if not target.has(cell):
		target[cell] = []
	var directions: Array = target[cell]
	if direction not in directions:
		directions.append(direction)
