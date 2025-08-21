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
	
	# 使用新的飛行方法
	owner.fly_towards_target(target_position, owner.chase_speed, delta)

	# 檢查是否到達攻擊位置（改為檢查到玩家的實際距離）
	var distance_to_player = owner.global_position.distance_to(owner.player.global_position)
	if distance_to_player < 80 and owner.attack_cooldown_timer.is_stopped():
		transition_to("Attack")


func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	transition_to("Patrol") 