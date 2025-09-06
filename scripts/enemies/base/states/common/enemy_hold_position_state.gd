extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name EnemyHoldPositionState

func on_enter() -> void:
	owner.velocity.x = 0

func process_physics(delta: float) -> void:
	owner.velocity.x = move_toward(owner.velocity.x, 0, owner.deceleration * delta)
