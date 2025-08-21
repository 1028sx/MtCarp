extends EnemyHurtState

class_name ArcherHurtState

const PlayerGlobalScript = preload("res://scripts/globals/PlayerGlobal.gd")


func on_animation_finished() -> void:

	if not PlayerGlobalScript.is_player_available():
		transition_to("Idle")
		return

	var player = PlayerGlobalScript.get_player()
	var distance_to_player = owner.global_position.distance_to(player.global_position)

	if distance_to_player > owner.optimal_attack_range_max:
		transition_to("Chase")
	elif distance_to_player < owner.optimal_attack_range_min:
		transition_to("HoldPosition")
	else:
		transition_to("Attack")
