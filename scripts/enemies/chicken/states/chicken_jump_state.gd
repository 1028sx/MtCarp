extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name ChickenJumpState

var jump_velocity: Vector2 = Vector2.ZERO

func on_enter() -> void:
	super.on_enter()
	if owner.is_on_floor() and jump_velocity != Vector2.ZERO:
		owner.velocity = jump_velocity
		owner.animated_sprite.play(owner._get_jump_animation())
	else:
		owner.change_state("Chase")


func process_physics(_delta: float) -> void:
	super.process_physics(_delta)
	if owner.velocity.y > 0 or not owner.is_on_floor():
		owner.change_state("Fall")

func on_exit() -> void:
	super.on_exit()
	jump_velocity = Vector2.ZERO 