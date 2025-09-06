extends "res://scripts/enemies/base/states/common/enemy_attack_state.gd"

class_name ChickenAttackState

func on_enter() -> void:
	# AttackState 的 on_enter 已經處理了播放攻擊動畫和重置計時器
	super.on_enter()
	
	# 確保攻擊區域初始時是禁用的
	var current_attack_area = owner.get_current_attack_area()
	if current_attack_area:
		current_attack_area.monitoring = false
	
func on_animation_frame_changed(frame: int) -> void:
	# 覆寫這個方法來定義攻擊判定的確切時機
	# 在第 3 幀啟用攻擊區域
	if frame == 3:
		# 啟用攻擊區域
		var current_attack_area = owner.get_current_attack_area()
		if current_attack_area:
			current_attack_area.monitoring = true
	elif frame > 3 and frame <= 6:
		# 保持攻擊區域在這幾幀都是活動的
		var current_attack_area = owner.get_current_attack_area()
		if current_attack_area:
			current_attack_area.monitoring = true
	else:
		var current_attack_area = owner.get_current_attack_area()
		if current_attack_area:
			current_attack_area.monitoring = false
			
func on_animation_finished() -> void:
	# 確保在動畫結束時禁用攻擊區域
	var current_attack_area = owner.get_current_attack_area()
	if current_attack_area:
		current_attack_area.monitoring = false
	
	# 呼叫父類別的 on_animation_finished 來處理狀態轉換
	super.on_animation_finished()

func get_next_state() -> String:
	# AttackState 的父類別會處理冷卻後的狀態轉換，
	# 通常是回到 Chase 或 Idle。
	# 我們這裡返回 Chase，如果玩家還在範圍內。
	if is_instance_valid(owner.player):
		return "Chase"
	return "Idle"

func _on_test_timer_timeout() -> void:
	# 備用的測試計時器回調（不再使用，但保留以免出錯）
	pass 
