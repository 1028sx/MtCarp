extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name EnemyHurtState

func on_enter() -> void:
	super.on_enter()
	owner.velocity.x = 0
	owner.animated_sprite.play("hurt")

func on_animation_finished() -> void:
	super.on_animation_finished()
	transition_to("Idle") 