extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name EnemyDeadState

func on_enter() -> void:
	super.on_enter()
	owner.velocity = Vector2.ZERO
	
	owner._on_death() 
	
	var death_animation = owner._get_death_animation()
	if death_animation:
		owner.animated_sprite.play(death_animation)

func on_animation_finished() -> void:
	super.on_animation_finished()
	owner.queue_free() 