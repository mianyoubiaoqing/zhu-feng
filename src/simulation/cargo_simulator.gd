class_name CargoSimulator
extends RefCounted

## Interface: simulate the single wind seed against a solved wind field.
## Returns the entire logical route; presentation may animate it at any speed.
static func simulate(level: LevelDefinition, wind: WindSolution, spent_budget: int) -> SimulationResult:
	var result := SimulationResult.new()
	result.route.append(level.start)
	result.powered_turbine_ids.assign(wind.powered_turbine_ids.keys())
	var current := level.start
	var visited_states: Dictionary = {}
	var step_limit: int = maxi(8, level.size.x * level.size.y * 4 + 1)

	for _step in step_limit:
		if wind.is_conflict(current):
			return _fail(result, GameRules.FailureReason.CONFLICT, current)
		if current == level.goal:
			if _required_power_ready(level, wind):
				result.succeeded = true
				result.efficient = spent_budget <= level.efficient_budget
				return result
			return _fail(result, GameRules.FailureReason.MISSING_POWER, current)
		var direction := wind.direction_at(current)
		if direction < 0:
			return _fail(result, GameRules.FailureReason.NO_WIND, current)

		var state := Vector3i(current.x, current.y, direction)
		if visited_states.has(state):
			return _fail(result, GameRules.FailureReason.LOOP, current)
		visited_states[state] = true

		var next := current + GameRules.vector(direction)
		if not level.contains(next) or level.is_wall(next):
			return _fail(result, GameRules.FailureReason.COLLISION, current)
		if level.is_pit(next):
			result.route.append(next)
			return _fail(result, GameRules.FailureReason.PIT, next)
		var door := level.door_at(next)
		if door != null and not wind.is_turbine_powered(door.turbine_id):
			return _fail(result, GameRules.FailureReason.COLLISION, current)
		current = next
		result.route.append(current)

	return _fail(result, GameRules.FailureReason.STEP_LIMIT, current)


static func _required_power_ready(level: LevelDefinition, wind: WindSolution) -> bool:
	for turbine_id in level.required_turbine_ids:
		if not wind.is_turbine_powered(turbine_id):
			return false
	return true


static func _fail(result: SimulationResult, reason: int, cell: Vector2i) -> SimulationResult:
	result.failure_reason = reason
	result.failure_cell = cell
	return result
