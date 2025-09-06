extends "res://scripts/enemies/base/states/common/enemy_dead_state.gd"

class_name ChickenDeadState

func on_enter() -> void:
	super.on_enter() # 播放死亡動畫並禁用物理
	
	# 添加擊殺計數
	var combat_system = owner.get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("enemy_killed"):
		combat_system.enemy_killed()
 
