extends "res://scripts/enemies/base/enemy_ai_base.gd"

class_name FlyingEnemyBase

#region 導出屬性
@export_group("移動參數")
@export var flight_speed: float = 120.0
@export var ground_speed: float = 60.0
@export var target_reach_distance: float = 30.0

@export_group("空中作戰限制")
@export var max_air_targets: int = 3  # 空中最多處理3個目標
@export var threat_detection_time_min: float = 2.0  # 威脅檢測
@export var threat_detection_time_max: float = 3.0  
#endregion

#region 狀態追蹤變數
var air_targets_handled: int = 0  # 當前空中階段已處理的目標數
var is_flying: bool = false
var last_state_name: String = ""  # 記錄前一個狀態名稱(地面巡邏用)
#endregion

func _ready() -> void:
	super._ready()
	set_ground_mode()  # 以地面模式生成

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

#region 移動工具方法

## 飛向指定點
func fly_to_point(target_pos: Vector2) -> bool:
	var direction = (target_pos - global_position).normalized()
	velocity = direction * flight_speed
	update_sprite_orientation()
	
	# 返回是否到達目標
	return global_position.distance_to(target_pos) < target_reach_distance

## 在地面走向指定點
func walk_to_point(target_pos: Vector2) -> bool:
	# 只考慮水平方向
	var horizontal_direction = sign(target_pos.x - global_position.x)
	
	if abs(target_pos.x - global_position.x) > target_reach_distance:
		velocity.x = horizontal_direction * ground_speed
	else:
		velocity.x = 0
	
	update_sprite_orientation()
	
	# 檢查是否到達（只考慮水平距離）
	return abs(global_position.x - target_pos.x) < target_reach_distance

## 選擇隨機空中目標
func get_random_air_target() -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(80.0, 200.0)
	var offset = Vector2(cos(angle), sin(angle)) * distance
	# 限制垂直範圍
	offset.y = clamp(offset.y, -150, -20)
	return global_position + offset

## 選擇地面目標（使用射線檢測）
func get_ground_target(horizontal_distance: float) -> Vector2:
	var target_x = global_position.x + horizontal_distance
	
	# 使用射線檢測找到地面位置
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = Vector2(target_x, global_position.y - 50)
	query.to = Vector2(target_x, global_position.y + 300)
	query.collision_mask = collision_mask
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	var target_y = global_position.y + 40
	
	if result:
		target_y = result.position.y - 20
	
	return Vector2(target_x, target_y)

## 獲取追擊玩家的位置
func get_chase_target() -> Vector2:
	if not is_instance_valid(player):
		return global_position
	return player.global_position + Vector2(0, -50)

#endregion

#region 模式切換

## 設置飛行模式
func set_flight_mode() -> void:
	is_flying = true
	gravity_scale = 0.0

## 設置地面模式  
func set_ground_mode() -> void:
	is_flying = false
	gravity_scale = 1.0

## 重置空中目標計數
func reset_air_targets_count() -> void:
	air_targets_handled = 0

## 增加空中目標計數，返回是否達到上限
func increment_air_targets() -> bool:
	air_targets_handled += 1
	return air_targets_handled >= max_air_targets

## 設置上一個狀態名稱
func set_last_state(state_name: String) -> void:
	last_state_name = state_name

#endregion

#region 輔助方法

## 更新精靈朝向
func update_sprite_orientation() -> void:
	if not is_instance_valid(animated_sprite):
		return
	
	# 水平翻轉
	if velocity.x != 0:
		animated_sprite.flip_h = velocity.x < 0
	
	# 飛行時追加俯仰角度（但攻擊時不要俯仰）
	if is_flying and current_state_name != "AirCombat":
		var pitch_angle = clamp(velocity.y * 0.02, -15, 15)
		animated_sprite.rotation_degrees = pitch_angle
	elif not is_flying or current_state_name == "AirCombat":
		animated_sprite.rotation_degrees = 0

#endregion

#region 動畫方法（子類可覆寫）
func _get_fly_animation() -> String: return "fly"
func _get_walk_animation() -> String: return "walk" 
func _get_idle_animation() -> String: return "idle"
func _get_takeoff_animation() -> String: return "takeoff"
func _get_land_animation() -> String: return "land"
#endregion
