extends "res://scripts/enemies/base/states/common/enemy_hold_position_state.gd"

class_name ArcherHoldPositionState

func on_enter() -> void:
	super.on_enter()
	
	var anim = owner._get_hold_position_animation()
	if anim:
		owner.animated_sprite.play(anim)

func process_physics(_delta: float) -> void:
	super.process_physics(_delta)

	if not is_instance_valid(owner.player):
		transition_to("Idle")
		return
	
	owner._update_sprite_flip()
	
	var can_attack = owner.attack_cooldown_timer.is_stopped()
	var in_attack_zone = owner.is_in_zone("in_attack_zone")
	var in_retreat_zone = owner.is_in_zone("in_retreat_zone")
	
	if can_attack and in_attack_zone:
		transition_to("Attack")
		return
		
	var is_in_optimal_zone = in_attack_zone and not in_retreat_zone
	
	if not is_in_optimal_zone:
		var is_cornered = owner._is_wall_or_ledge_behind()
		if not is_cornered:
			transition_to("Chase")
			return
