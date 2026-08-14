class_name DoorDefinition
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export var turbine_id: StringName


static func create(at: Vector2i, required_turbine: StringName) -> DoorDefinition:
	var door := DoorDefinition.new()
	door.cell = at
	door.turbine_id = required_turbine
	return door
