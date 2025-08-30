extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdChaseState

func on_enter() -> void:
	super.on_enter()
	owner.set_flight_mode(true)  # 追蹤時必須飛行
	owner.animated_sprite.play(owner._get_fly_animation())
	
	# 重置追蹤目標，強制重新評估
	owner.chase_target_position = Vector2.ZERO
	owner.chase_update_timer = 0.0

func on_exit() -> void:
	owner.velocity = Vector2.ZERO
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	if not is_instance_valid(owner.player):
		transition_to("Patrol")
		return

	# 使用智能追蹤系統
	var target_position = owner.get_smart_chase_position(owner.player, delta)
	
	# 添加橫向擺動使追蹤更自然
	var wave_offset = sin(owner.time_counter * 2.0) * 15.0
	target_position.x += wave_offset
	
	# 根據距離調整追蹤速度
	var distance_to_player = owner.global_position.distance_to(owner.player.global_position)
	var speed_factor = 1.0
	
	# 距離太近時減速，太遠時加速
	if distance_to_player < 100:
		speed_factor = 0.7  # 接近時減速
	elif distance_to_player > 250:
		speed_factor = 1.2  # 距離遠時加速追趕
	
	# 使用調整後的速度飛行
	owner.fly_towards_target(target_position, owner.chase_speed * speed_factor, delta)

	# 檢查是否到達理想攻擊距離
	var ideal_attack_distance = 120  # 理想攻擊距離
	if distance_to_player < ideal_attack_distance and distance_to_player > 60:
		# 在理想距離範圍內，檢查冷卻
		if owner.attack_cooldown_timer.is_stopped():
			transition_to("Attack")
	elif distance_to_player < 60:
		# 太近了，後退一點
		var retreat_direction = (owner.global_position - owner.player.global_position).normalized()
		owner.velocity += retreat_direction * 50


func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	transition_to("Patrol") 