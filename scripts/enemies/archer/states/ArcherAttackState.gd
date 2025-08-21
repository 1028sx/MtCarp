extends EnemyAttackState

class_name ArcherAttackState

# 弓箭手的攻擊狀態。
# 主要的額外邏輯是在攻擊動畫完成後，
# 確保攻擊冷卻計時器被正確啟動。

func on_animation_finished() -> void:
	# 我們手動呼叫主腳本中的函式來觸發射箭動作。
	# 這是為了解決之前移除 super() 呼叫所帶來的副作用。
	if owner.has_method("_on_attack_animation_finished"):
		owner._on_attack_animation_finished()
		
	# 在動畫播放完畢（並且箭已射出）後，立即啟動攻擊冷卻計時器。
	if owner and owner.has_method("attack_is_ready"):
		owner.attack_cooldown_timer.start()

	# 之後，我們轉換回 HoldPosition 狀態，等待下一次決策。
	# 這使得 AI 在冷卻期間可以重新評估情況（例如玩家是否逃離）。
	transition_to("HoldPosition") 