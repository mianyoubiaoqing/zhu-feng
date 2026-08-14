class_name TurbineDefinition
extends Resource

@export var id: StringName
@export var cell: Vector2i = Vector2i.ZERO


static func create(turbine_id: StringName, at: Vector2i) -> TurbineDefinition:
	var turbine := TurbineDefinition.new()
	turbine.id = turbine_id
	turbine.cell = at
	return turbine
