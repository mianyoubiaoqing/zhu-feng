class_name PlacedDevice
extends RefCounted

var kind: int
var cell: Vector2i
var orientation: int


func _init(device_kind: int, at: Vector2i, facing: int = GameRules.Direction.UP) -> void:
	kind = device_kind
	cell = at
	orientation = wrapi(facing, 0, 4)


func copy() -> PlacedDevice:
	return PlacedDevice.new(kind, cell, orientation)
