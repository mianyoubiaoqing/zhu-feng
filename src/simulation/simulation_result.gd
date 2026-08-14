class_name SimulationResult
extends RefCounted

var succeeded := false
var efficient := false
var failure_reason: int = GameRules.FailureReason.NONE
var failure_cell: Vector2i = Vector2i(-1, -1)
var route: Array[Vector2i] = []
var powered_turbine_ids: Array[StringName] = []


func failure_label() -> String:
	match failure_reason:
		GameRules.FailureReason.NO_WIND:
			return "风种进入无风格"
		GameRules.FailureReason.CONFLICT:
			return "风向冲突"
		GameRules.FailureReason.COLLISION:
			return "风种撞上障碍"
		GameRules.FailureReason.PIT:
			return "风种坠入深渊"
		GameRules.FailureReason.LOOP:
			return "风种进入闭环"
		GameRules.FailureReason.MISSING_POWER:
			return "必需涡轮尚未供能"
		GameRules.FailureReason.STEP_LIMIT:
			return "模拟超过安全步数"
	return ""
