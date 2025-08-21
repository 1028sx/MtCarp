extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name EnemyAttackState

# 攻擊狀態的通用基礎。
func on_enter() -> void:
	super.on_enter()
	owner.velocity.x = 0
	
	if is_instance_valid(owner.player):
		if owner.has_method("set_locked_target_position"):
			owner.set_locked_target_position(owner.player.global_position)
		else:
			if "locked_target_position" in owner:
				owner.locked_target_position = owner.player.global_position
		
		owner._update_sprite_flip()
	
	var attack_animation = owner._get_attack_animation()
	if attack_animation:
		owner.animated_sprite.play(attack_animation)


func on_animation_finished() -> void:
	super.on_animation_finished()

	if owner.has_method("_on_attack_animation_finished"):
		owner._on_attack_animation_finished()
	
	owner.attack_cooldown_timer.start()

	if is_instance_valid(owner.player):
		transition_to("Chase")
	else:
		transition_to("Idle") 
