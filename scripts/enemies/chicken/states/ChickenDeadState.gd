extends EnemyDeadState

class_name ChickenDeadState

func on_enter() -> void:
	super.on_enter() # 這會播放死亡動畫並禁用物理
	
	# 在這裡加入遊戲特有的死亡邏輯
	
	# 添加擊殺計數
	var game_manager = owner.get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("enemy_killed"):
		game_manager.enemy_killed()
	
	# 使用 WordSystem 處理掉落
	var word_system = owner.get_tree().get_first_node_in_group("word_system")
	if word_system and word_system.has_method("handle_enemy_drops"):
		word_system.handle_enemy_drops("Chicken", owner.global_position)

# DeadState 的父類別會處理在死亡動畫結束後釋放節點 (queue_free) 