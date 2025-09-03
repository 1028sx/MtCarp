extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdTakeoffState

var takeoff_timer: float = 0.0
var takeoff_duration: float = 1.0  # 起飛持續時間
var initial_position: Vector2

func on_enter() -> void:
	super.on_enter()
	
	# 記錄起飛位置
	initial_position = owner.global_position
	
	# 設置飛行模式
	owner.set_flight_mode()
	
	# 重置空中目標計數（開始新的空中階段）
	owner.reset_air_targets_count()
	
	# 重置角度
	if is_instance_valid(owner.animated_sprite):
		owner.animated_sprite.rotation_degrees = 0
	
	# 播放起飛動畫
	owner.animated_sprite.play(owner._get_takeoff_animation())
	
	# 重置計時器
	takeoff_timer = 0.0

func on_exit() -> void:
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	takeoff_timer += delta
	
	# 起飛行為：向上和略微前方飛行
	var takeoff_progress = takeoff_timer / takeoff_duration
	var vertical_force = 1.0 - takeoff_progress  # 起飛力度隨時間減少
	
	# 起飛方向：略微前傾
	var takeoff_direction = Vector2(0.3, -1.0).normalized()
	owner.velocity = takeoff_direction * owner.flight_speed * vertical_force
	
	# 確保最小垂直速度
	if owner.velocity.y > -50:
		owner.velocity.y = -50
	
	owner.update_sprite_orientation()
	
	# 檢查起飛完成條件
	var height_gained = initial_position.y - owner.global_position.y
	var time_elapsed = takeoff_timer >= takeoff_duration
	
	if height_gained > 80 or time_elapsed:
		transition_to("AirCombat")

func on_animation_finished() -> void:
	super.on_animation_finished()
	# 完成後切換到飛行動畫
	if owner.animated_sprite.animation == owner._get_takeoff_animation():
		owner.animated_sprite.play(owner._get_fly_animation())