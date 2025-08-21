extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdAttackState

enum AttackPhase { DIVING, CLIMBING }
var phase: AttackPhase
var attack_target_position: Vector2

func on_enter() -> void:
	super.on_enter()
	
	if not is_instance_valid(owner.player):
		transition_to("Patrol")
		return
	
	phase = AttackPhase.DIVING
	attack_target_position = owner.player.global_position
	
	owner.animated_sprite.play(owner._get_attack_animation())
	var direction = (attack_target_position - owner.global_position).normalized()
	owner.velocity = direction * owner.dive_speed
	
	# 啟用當前攻擊區域
	var current_attack_area = owner.get_current_attack_area()
	if current_attack_area:
		current_attack_area.monitoring = true
		
	# 啟動攻擊冷卻計時器
	if owner.attack_cooldown_timer:
		owner.attack_cooldown_timer.start()

func on_exit() -> void:
	# 確保離開狀態時，所有攻擊碰撞都關閉
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	if phase == AttackPhase.DIVING:
		# 在俯衝階段，持續朝目標移動
		# 當接近目標或超過一定時間後，切換到爬升階段
		if owner.global_position.distance_to(attack_target_position) < 30:
			_start_climbing_phase()
	
	elif phase == AttackPhase.CLIMBING:
		# 在爬升階段，朝理想攻擊高度移動
		var ideal_position = owner.patrol_center + Vector2(0, -owner.ideal_attack_height) # 爬升回巡邏中心上方
		var direction = (ideal_position - owner.global_position).normalized()
		owner.velocity = owner.velocity.move_toward(direction * owner.climb_speed, owner.acceleration * delta * 2)
		
		if owner.global_position.distance_to(ideal_position) < 50:
			transition_to("Chase")

func _start_climbing_phase() -> void:
	phase = AttackPhase.CLIMBING
	# 關閉所有攻擊碰撞區
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	# 播放飛翔動畫
	owner.animated_sprite.play(owner._get_fly_animation())
	
func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	transition_to("Patrol") 