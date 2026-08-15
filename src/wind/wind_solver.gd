class_name WindSolver
extends RefCounted

const MAX_STRENGTH := 15
const DEFAULT_FAN_STRENGTH := 6
const BEND_STRENGTH_LOSS := 1
const TURBINE_MIN_STRENGTH := 2
const TURBINE_STRENGTH_LOSS := 1


## Solve a stable, discrete wind field. Every cell stores one outgoing wind
## direction and strength, or a turbulence state when perpendicular/equal
## opposing winds meet. The iteration order and stopping rules are deterministic.
static func solve(level: LevelDefinition, placements: Dictionary, fan_directions: Dictionary) -> WindSolution:
	var states: Dictionary = {}
	var seen_signatures: Dictionary = {}
	var iteration_limit := maxi(32, level.size.x * level.size.y * MAX_STRENGTH * 2)
	for _iteration in iteration_limit:
		var next_states: Dictionary = {}
		for y in level.size.y:
			for x in level.size.x:
				var cell := Vector2i(x, y)
				if level.is_wall(cell):
					continue
				var state := _solve_cell(level, placements, fan_directions, states, cell)
				if not state.is_empty():
					next_states[cell] = state
		if _states_equal(states, next_states):
			states = next_states
			break
		var signature := _state_signature(level, next_states)
		if seen_signatures.has(signature):
			states = next_states
			break
		seen_signatures[signature] = true
		states = next_states

	return _build_solution(level, states, fan_directions)


static func _solve_cell(
	level: LevelDefinition,
	placements: Dictionary,
	fan_directions: Dictionary,
	previous_states: Dictionary,
	cell: Vector2i
) -> Dictionary:
	var incoming: Array[int] = [0, 0, 0, 0]
	for fan in level.fans:
		if fan.cell == cell:
			var fan_direction: int = fan_directions.get(fan.cell, fan.direction)
			incoming[wrapi(fan_direction, 0, 4)] += fan.strength

	for direction in 4:
		var upstream_cell := cell - GameRules.vector(direction)
		var upstream: Dictionary = previous_states.get(upstream_cell, {})
		if upstream.is_empty() or bool(upstream.get("conflict", false)):
			continue
		if int(upstream.get("direction", -1)) != direction:
			continue
		var strength := int(upstream.get("strength", 0))
		if level.fan_at(upstream_cell) == null:
			strength -= 1
		if strength > 0:
			incoming[direction] += strength

	# A fixed fan is a source boundary: tailwind can reinforce it, while wind
	# arriving from another direction cannot turn or stall the machine itself.
	var fan := level.fan_at(cell)
	if fan != null:
		var forced_direction: int = fan_directions.get(cell, fan.direction)
		var forced_strength := incoming[wrapi(forced_direction, 0, 4)]
		incoming = [0, 0, 0, 0]
		incoming[wrapi(forced_direction, 0, 4)] = forced_strength

	var transformed: Array[int] = [0, 0, 0, 0]
	var device: PlacedDevice = placements.get(cell)
	for direction in 4:
		var strength := mini(incoming[direction], MAX_STRENGTH)
		if strength <= 0:
			continue
		var output_direction := direction
		if device != null:
			output_direction = _transform_direction(device, direction)
			if output_direction < 0:
				continue
			if device.kind == GameRules.DeviceKind.BEND:
				strength -= BEND_STRENGTH_LOSS
		if strength > 0:
			transformed[output_direction] = mini(MAX_STRENGTH, transformed[output_direction] + strength)

	var resolved := _resolve_directions(transformed)
	if resolved.is_empty() or bool(resolved.get("conflict", false)):
		return resolved

	var turbine := level.turbine_at(cell)
	if turbine != null and int(resolved.strength) >= TURBINE_MIN_STRENGTH:
		resolved.powered = true
		resolved.strength = maxi(1, int(resolved.strength) - TURBINE_STRENGTH_LOSS)
	return resolved


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


static func _resolve_directions(strengths: Array[int]) -> Dictionary:
	var horizontal := strengths[GameRules.Direction.RIGHT] - strengths[GameRules.Direction.LEFT]
	var vertical := strengths[GameRules.Direction.DOWN] - strengths[GameRules.Direction.UP]
	var has_horizontal := strengths[GameRules.Direction.RIGHT] > 0 or strengths[GameRules.Direction.LEFT] > 0
	var has_vertical := strengths[GameRules.Direction.DOWN] > 0 or strengths[GameRules.Direction.UP] > 0
	var total := mini(MAX_STRENGTH, strengths.reduce(func(sum: int, value: int) -> int: return sum + value, 0))
	if has_horizontal and has_vertical:
		return {"direction": -1, "strength": 0, "conflict": true, "conflict_strength": total}
	if has_horizontal:
		if horizontal == 0:
			return {"direction": -1, "strength": 0, "conflict": true, "conflict_strength": total}
		return {
			"direction": GameRules.Direction.RIGHT if horizontal > 0 else GameRules.Direction.LEFT,
			"strength": mini(MAX_STRENGTH, absi(horizontal)),
			"conflict": false,
		}
	if has_vertical:
		if vertical == 0:
			return {"direction": -1, "strength": 0, "conflict": true, "conflict_strength": total}
		return {
			"direction": GameRules.Direction.DOWN if vertical > 0 else GameRules.Direction.UP,
			"strength": mini(MAX_STRENGTH, absi(vertical)),
			"conflict": false,
		}
	return {}


static func _build_solution(level: LevelDefinition, states: Dictionary, fan_directions: Dictionary) -> WindSolution:
	var solution := WindSolution.new()
	for y in level.size.y:
		for x in level.size.x:
			var cell := Vector2i(x, y)
			var state: Dictionary = states.get(cell, {})
			if state.is_empty():
				continue
			if bool(state.get("conflict", false)):
				solution.conflict_cells[cell] = true
				solution.conflict_strength_by_cell[cell] = int(state.get("conflict_strength", 0))
				continue
			var direction := int(state.direction)
			solution.directions_by_cell[cell] = [direction]
			solution.strength_by_cell[cell] = int(state.strength)
			var turbine := level.turbine_at(cell)
			if turbine != null and bool(state.get("powered", false)):
				solution.powered_turbine_ids[turbine.id] = true

	_detect_loops(level, states, solution)
	for fan in level.fans:
		var entries: Array = []
		var current := fan.cell
		var visited: Dictionary = {}
		while level.contains(current) and states.has(current) and not visited.has(current):
			visited[current] = true
			var state: Dictionary = states[current]
			if bool(state.get("conflict", false)):
				break
			entries.append({"cell": current, "direction": int(state.direction), "strength": int(state.strength)})
			current += GameRules.vector(int(state.direction))
		solution.paths.append(entries)
	return solution


static func _detect_loops(level: LevelDefinition, states: Dictionary, solution: WindSolution) -> void:
	for origin in states:
		var path: Array[Vector2i] = []
		var index_by_cell: Dictionary = {}
		var current: Vector2i = origin
		while level.contains(current) and states.has(current):
			var state: Dictionary = states[current]
			if bool(state.get("conflict", false)):
				break
			if index_by_cell.has(current):
				for index in range(int(index_by_cell[current]), path.size()):
					solution.loop_cells[path[index]] = true
				break
			index_by_cell[current] = path.size()
			path.append(current)
			current += GameRules.vector(int(state.direction))


static func _states_equal(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for cell in first:
		if not second.has(cell):
			return false
		var a: Dictionary = first[cell]
		var b: Dictionary = second[cell]
		for key in ["direction", "strength", "conflict", "conflict_strength", "powered"]:
			if a.get(key) != b.get(key):
				return false
	return true


static func _state_signature(level: LevelDefinition, states: Dictionary) -> String:
	var parts := PackedStringArray()
	for y in level.size.y:
		for x in level.size.x:
			var state: Dictionary = states.get(Vector2i(x, y), {})
			parts.append("%d:%d:%d:%d" % [
				int(state.get("direction", -2)),
				int(state.get("strength", 0)),
				int(bool(state.get("conflict", false))),
				int(bool(state.get("powered", false))),
			])
	return "|".join(parts)
