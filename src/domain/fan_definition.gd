class_name FanDefinition
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export_enum("Up", "Right", "Down", "Left") var direction: int = GameRules.Direction.RIGHT


static func create(at: Vector2i, facing: int) -> FanDefinition:
	var fan := FanDefinition.new()
	fan.cell = at
	fan.direction = facing
	return fan
