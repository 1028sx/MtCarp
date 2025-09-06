extends "res://scripts/enemies/base/states/common/enemy_hurt_state.gd"

class_name ArcherHurtState

# 直接使用 PlayerSystem 單例


func on_animation_finished() -> void:

	if not PlayerSystem.is_player_available():
		transition_to("Idle")
		return

	var player = PlayerSystem.get_player()
	var distance_to_player = owner.global_position.distance_to(player.global_position)

	if distance_to_player > owner.optimal_attack_range_max:
		transition_to("Chase")
	elif distance_to_player < owner.optimal_attack_range_min:
		transition_to("HoldPosition")
	else:
		transition_to("Attack")
