extends EnemyHurtState

class_name SmallBirdHurtState

func on_animation_finished() -> void:
	# 返回巡邏狀態， क्योंकि 飛行單位沒有真正的「待機」
	transition_to("Patrol") 