extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdAirCombatState

enum CombatPhase { CHASING, DIVING, RECOVERING }
var combat_phase: CombatPhase = CombatPhase.CHASING

# 追擊相關
var chase_target_position: Vector2

# 攻擊相關
var attack_target_position: Vector2
var attack_start_position: Vector2
var attack_progress: float = 0.0

func on_enter() -> void:
	super.on_enter()
	
	# 確保飛行模式
	owner.set_flight_mode()
	
	# 開始追擊階段
	combat_phase = CombatPhase.CHASING
	chase_target_position = Vector2.ZERO
	
	# 重置角度
	if is_instance_valid(owner.animated_sprite):
		owner.animated_sprite.rotation_degrees = 0
	
	# 播放飛行動畫
	owner.animated_sprite.play(owner._get_fly_animation())

func on_exit() -> void:
	# 關閉所有攻擊碰撞區
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	# 檢查玩家是否仍然存在
	if not is_instance_valid(owner.player):
		transition_to("Landing")
		return
	
	# 檢查是否達到目標上限
	if owner.air_targets_handled >= owner.max_air_targets:
		transition_to("Landing")
		return
	
	# 根據當前階段執行邏輯
	match combat_phase:
		CombatPhase.CHASING:
			process_chasing()
		CombatPhase.DIVING:
			process_diving(delta)
		CombatPhase.RECOVERING:
			process_recovering(delta)

## 追擊階段
func process_chasing() -> void:
	# 檢查攻擊冷卻
	if not owner.attack_cooldown_timer.is_stopped():
		# 還在冷卻，原地等待
		owner.velocity = Vector2.ZERO
		return
	
	# 冷卻結束，開始攻擊接近
	if chase_target_position == Vector2.ZERO:
		chase_target_position = get_new_attack_position()
	
	# 飛向攻擊位置
	var reached_target = owner.fly_to_point(chase_target_position)
	
	if reached_target:
		start_attack_sequence()

## 開始攻擊序列
func start_attack_sequence() -> void:
	attack_target_position = owner.player.global_position
	attack_start_position = owner.global_position
	start_diving()

## 開始俯衝
func start_diving() -> void:
	combat_phase = CombatPhase.DIVING
	attack_progress = 0.0
	attack_start_position = owner.global_position
	
	# 播放攻擊動畫並啟用碰撞
	owner.animated_sprite.play(owner._get_attack_animation())
	var attack_area = owner.get_current_attack_area()
	if attack_area:
		attack_area.monitoring = true
	
	# 啟動攻擊冷卻
	if owner.attack_cooldown_timer:
		owner.attack_cooldown_timer.start()

## 俯衝階段
func process_diving(delta: float) -> void:
	attack_progress += delta * 3.0
	
	if attack_progress >= 1.0:
		start_recovering()
		return
	
	# 使用貝茲曲線計算俯衝軌跡
	var control_point = (attack_start_position + attack_target_position) * 0.5
	control_point.y -= 20
	
	var new_position = quadratic_bezier(
		attack_start_position,
		control_point,
		attack_target_position,
		attack_progress
	)
	
	var direction = (new_position - owner.global_position)
	owner.velocity = direction * owner.flight_speed * 1.8 * 0.05
	
	# 檢查是否接近目標
	if owner.global_position.distance_to(attack_target_position) < 35:
		start_recovering()

## 開始恢復
func start_recovering() -> void:
	combat_phase = CombatPhase.RECOVERING
	
	# 關閉攻擊碰撞
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	
	# 播放飛行動畫
	owner.animated_sprite.play(owner._get_fly_animation())

## 恢復階段
func process_recovering(delta: float) -> void:
	# 向上爬升遠離目標
	var recover_direction = Vector2(
		sign(owner.velocity.x) * 0.5,
		-1.0
	).normalized()
	
	owner.velocity = owner.velocity.move_toward(
		recover_direction * owner.flight_speed,
		owner.acceleration * delta * 1.2
	)
	
	# 爬升一段距離後決定下一步
	if owner.global_position.y < attack_start_position.y - 30:
		# 恢復完成，增加攻擊計數
		owner.increment_air_targets()
		
		# 檢查是否需要降落
		if owner.air_targets_handled >= owner.max_air_targets:
			transition_to("Landing")
		else:
			# 繼續追擊，選擇新的攻擊位置
			combat_phase = CombatPhase.CHASING
			chase_target_position = Vector2.ZERO  # 重置讓下一幀選擇新目標

## 獲取新的攻擊位置
func get_new_attack_position() -> Vector2:
	if not is_instance_valid(owner.player):
		return owner.get_chase_target()
	
	# 攻擊位置：玩家正上方
	var player_pos = owner.player.global_position
	return player_pos + Vector2(0, -50)

## 二次貝茲曲線插值
func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	# 失去玩家時降落
	transition_to("Landing")
