extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdAttackState

enum AttackPhase { POSITIONING, HOVERING, DIVING, RECOVERING }
var phase: AttackPhase
var attack_target_position: Vector2
var attack_start_position: Vector2
var hover_timer: float = 0.0
var hover_duration: float = 0.5  # 懸停瞄準時間
var attack_progress: float = 0.0  # 攻擊進度（用於曲線計算）

func on_enter() -> void:
	super.on_enter()
	
	if not is_instance_valid(owner.player):
		transition_to("Patrol")
		return
	
	# 從定位階段開始
	phase = AttackPhase.POSITIONING
	attack_target_position = owner.player.global_position
	attack_start_position = owner.global_position
	hover_timer = 0.0
	attack_progress = 0.0
	
	owner.animated_sprite.play(owner._get_fly_animation())

func on_exit() -> void:
	# 確保離開狀態時，所有攻擊碰撞都關閉
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	
	# 恢復正常飛行週期
	owner.start_new_cycle()
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	match phase:
		AttackPhase.POSITIONING:
			_process_positioning(delta)
		AttackPhase.HOVERING:
			_process_hovering(delta)
		AttackPhase.DIVING:
			_process_diving(delta)
		AttackPhase.RECOVERING:
			_process_recovering(delta)

## 移動到理想攻擊位置
func _process_positioning(delta: float) -> void:
	# 計算理位置（玩家上方）
	var ideal_attack_pos = attack_target_position + Vector2(0, -80)
	
	# 設置目標並使用基類的飛行方法
	owner.current_target = ideal_attack_pos
	owner.is_flying = true
	owner.fly_toward_target(delta)
	
	# 到達定位點後進入懸停
	if owner.global_position.distance_to(ideal_attack_pos) < 40:
		phase = AttackPhase.HOVERING
		hover_timer = 0.0
		owner.velocity = owner.velocity * 0.3

## 處理懸停瞄準階段
func _process_hovering(delta: float) -> void:
	hover_timer += delta
	
	# 輕微的懸停擺動
	var hover_offset = sin(hover_timer * 8.0) * Vector2(5, 3)
	owner.velocity = hover_offset
	
	# 更新目標位置（預測玩家移動）
	if is_instance_valid(owner.player):
		attack_target_position = owner.player.global_position
		if "velocity" in owner.player:
			attack_target_position += owner.player.velocity * 0.2  # 預測0.2秒後的位置
	
	# 懸停時間結束，開始俯衝
	if hover_timer >= hover_duration:
		_start_diving()

## 處理俯衝攻擊階段
func _process_diving(delta: float) -> void:
	attack_progress += delta * 2.0
	
	if attack_progress >= 1.0:
		_start_recovering()
		return
	
	# 使用二次貝塞爾曲線計算俯衝軌跡
	var control_point = (attack_start_position + attack_target_position) * 0.5
	control_point.y -= 30  # 控制點稍微向上，產生弧形軌跡
	
	# 計算曲線上的位置
	var new_position = _bezier_interpolate(
		attack_start_position,
		control_point,
		attack_target_position,
		attack_progress
	)
	
	# 計算速度向量
	var direction = (new_position - owner.global_position)
	owner.velocity = direction * owner.flight_speed * 1.5 * 0.05
	
	# 檢查是否接近目標
	if owner.global_position.distance_to(attack_target_position) < 30:
		_start_recovering()

## 處理恢復階段 - 弧形爬升
func _process_recovering(delta: float) -> void:
	# 計算恢復目標位置（向上和側面）
	var recover_target = owner.global_position + Vector2(
		sign(owner.velocity.x) * 100,  # 保持水平方向
		-150  # 向上爬升
	)
	
	# 平滑過渡到爬升
	var direction = (recover_target - owner.global_position).normalized()
	owner.velocity = owner.velocity.move_toward(
		direction * owner.flight_speed,
		owner.acceleration * delta * 1.5
	)
	
	# 恢復到一定高度後切換回巡邏狀態
	if owner.global_position.y < attack_start_position.y - 50:
		transition_to("Patrol")

## 開始俯衝
func _start_diving() -> void:
	phase = AttackPhase.DIVING
	attack_progress = 0.0
	attack_start_position = owner.global_position
	
	# 播放攻擊動畫
	owner.animated_sprite.play(owner._get_attack_animation())
	
	# 啟用攻擊碰撞區
	var current_attack_area = owner.get_current_attack_area()
	if current_attack_area:
		current_attack_area.monitoring = true
	
	# 啟動攻擊冷卻
	if owner.attack_cooldown_timer:
		owner.attack_cooldown_timer.start()

## 開始恢復
func _start_recovering() -> void:
	phase = AttackPhase.RECOVERING
	
	# 關閉所有攻擊碰撞區
	if owner.attack_area_right:
		owner.attack_area_right.monitoring = false
	if owner.attack_area_left:
		owner.attack_area_left.monitoring = false
	
	# 播放飛翔動畫
	owner.animated_sprite.play(owner._get_fly_animation())

## 二次貝塞爾曲線插值
func _bezier_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)
	
func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	transition_to("Patrol") 