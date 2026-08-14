class_name GameRules
extends RefCounted

enum Direction { UP, RIGHT, DOWN, LEFT }
enum DeviceKind { BEND, BLOCKER, ONE_WAY_VALVE }
enum Phase { BUILD, RESULT }
enum FailureReason { NONE, NO_WIND, CONFLICT, COLLISION, PIT, LOOP, MISSING_POWER, STEP_LIMIT }

const DEVICE_COSTS := {
	DeviceKind.BEND: 2,
	DeviceKind.BLOCKER: 1,
	DeviceKind.ONE_WAY_VALVE: 2,
}

const DIRECTION_VECTORS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]


static func vector(direction: int) -> Vector2i:
	return DIRECTION_VECTORS[wrapi(direction, 0, 4)]


static func opposite(direction: int) -> int:
	return wrapi(direction + 2, 0, 4)


static func clockwise(direction: int) -> int:
	return wrapi(direction + 1, 0, 4)


static func cost(device_kind: int) -> int:
	return DEVICE_COSTS.get(device_kind, 0)
