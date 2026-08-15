class_name FanDefinition
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export_enum("Up", "Right", "Down", "Left") var direction: int = GameRules.Direction.RIGHT
@export_range(1, 15, 1) var strength := 6


static func create(at: Vector2i, facing: int, power: int = 6) -> FanDefinition:
	var fan := FanDefinition.new()
	fan.cell = at
	fan.direction = facing
	fan.strength = clampi(power, 1, WindSolver.MAX_STRENGTH)
	return fan
