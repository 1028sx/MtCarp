extends "res://scripts/enemies/base/states/common/enemy_attack_state.gd"

class_name ArcherAttackState
# 在攻擊動畫完成後確保攻擊冷卻計時器被正確啟動。

func on_animation_finished() -> void:
	if owner.has_method("_on_attack_animation_finished"):
		owner._on_attack_animation_finished()
		
	# 在動畫播放完畢並且箭已射出後，啟動攻擊冷卻計時器。
	if owner and owner.has_method("attack_is_ready"):
		owner.attack_cooldown_timer.start()

	# 轉換回 HoldPosition 狀態，使得 AI 在冷卻期間可以重新評估情況（例如玩家是否逃離）。
	transition_to("HoldPosition") 