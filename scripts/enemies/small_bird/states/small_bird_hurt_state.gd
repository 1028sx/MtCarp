extends "res://scripts/enemies/base/states/common/enemy_hurt_state.gd"

class_name SmallBirdHurtState

func on_enter() -> void:
	super.on_enter()
	
	# 重置角度
	if is_instance_valid(owner.animated_sprite):
		owner.animated_sprite.rotation_degrees = 0

func on_animation_finished() -> void:
	# 返回地面巡邏狀態
	transition_to("GroundPatrol") 