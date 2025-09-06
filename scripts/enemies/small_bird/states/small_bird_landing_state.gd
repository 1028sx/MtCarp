extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name SmallBirdLandingState

var landing_target: Vector2
var landing_timer: float = 0.0
var max_landing_time: float = 3.0  # 最大降落時間
var has_found_ground: bool = false
var landing_start_position: Vector2
var landing_progress: float = 0.0

func on_enter() -> void:
	super.on_enter()
	
	# 重置變數
	landing_timer = 0.0
	landing_progress = 0.0
	has_found_ground = false
	landing_start_position = owner.global_position
	
	# 重置角度
	if is_instance_valid(owner.animated_sprite):
		owner.animated_sprite.rotation_degrees = 0
	
	# 尋找降落目標
	find_landing_spot()

	# 播放下降動畫
	owner.animated_sprite.play(owner._get_fall_animation())

func on_exit() -> void:
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	landing_timer += delta
	
	if landing_target == Vector2.ZERO:
		# 沒有找到降落點，緊急降落到當前下方
		emergency_landing()
	else:
		# 正常降落到目標點
		normal_landing(delta)
	
	# 檢查降落完成條件
	check_landing_completion()

## 尋找安全的降落點
func find_landing_spot() -> void:
	# 強制選擇遠離玩家的方向
	var landing_direction = 1
	
	if is_instance_valid(owner.player):
		var to_player_x = owner.player.global_position.x - owner.global_position.x
		landing_direction = -sign(to_player_x) if to_player_x != 0 else (1 if randf() > 0.5 else -1)
	else:
		landing_direction = 1 if randf() > 0.5 else -1
	
	var safe_distance = randf_range(150.0, 250.0)
	
	# 嘗試在遠離玩家方向找到降落點
	landing_target = owner.get_ground_target(safe_distance * landing_direction)
	
	# 如果第一次嘗試失敗，嘗試反方向
	if landing_target == Vector2.ZERO:
		landing_target = owner.get_ground_target(safe_distance * -landing_direction)

## 正常降落到目標點
func normal_landing(delta: float) -> void:
	landing_progress += delta * 1.2
	
	if landing_progress >= 1.0:
		landing_progress = 1.0
	
	# 使用二次貝茲曲線實現自然弧形降落
	var control_point = (landing_start_position + landing_target) * 0.5
	control_point.y += 30
	
	var new_position = quadratic_bezier_landing(
		landing_start_position,
		control_point,
		landing_target,
		landing_progress
	)
	
	# 設置速度來移向新位置
	var direction = (new_position - owner.global_position)
	owner.velocity = direction * 3.0
	
	owner.update_sprite_orientation()

## 緊急降落（垂直下降）
func emergency_landing() -> void:
	# 直接向下降落
	owner.velocity.x = owner.velocity.x * 0.9  # 逐漸減少水平速度
	owner.velocity.y = 100
	
	owner.update_sprite_orientation()

## 檢查降落完成條件
func check_landing_completion() -> void:
	var is_close_to_ground = false
	var timeout = landing_timer >= max_landing_time
	
	# 檢查是否接近地面
	if landing_target != Vector2.ZERO:
		var distance_to_target = owner.global_position.distance_to(landing_target)
		is_close_to_ground = distance_to_target < 40 or landing_progress >= 0.9
	else:
		# 緊急降落情況，檢查是否碰到地面
		is_close_to_ground = owner.is_on_floor()
	
	# 高度檢查：如果已經很接近地面高度
	if landing_target != Vector2.ZERO:
		var height_diff = abs(owner.global_position.y - landing_target.y)
		if height_diff < 30:
			is_close_to_ground = true
	
	if is_close_to_ground or timeout:
		owner.animated_sprite.play(owner._get_land_animation())
		owner.set_ground_mode()
		owner.velocity.y = 0
		transition_to("GroundPatrol")

## 二次貝茲曲線插值（降落專用）
func quadratic_bezier_landing(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func on_animation_finished() -> void:
	super.on_animation_finished()
	# 降落動畫完成後切換到idle動畫
	if owner.animated_sprite.animation == owner._get_land_animation():
		owner.animated_sprite.play(owner._get_idle_animation())
