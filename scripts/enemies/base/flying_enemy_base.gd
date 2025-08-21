extends EnemyAIBase

class_name FlyingEnemyBase

#region 飛行專屬導出屬性
@export_group("飛行行為")
@export var patrol_area_radius: float = 300.0
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 250.0
@export var dive_speed: float = 400.0
@export var climb_speed: float = 200.0
@export var ideal_attack_height: float = 150.0

@export_group("飛行物理")
@export var wave_amplitude: float = 15.0  # 波浪幅度（減少搖擺）
@export var wave_frequency: float = 2.0   # 波浪頻率（降低頻率）
@export var turn_speed: float = 1.5       # 轉向速度（減緩轉向）
@export var banking_angle: float = 10.0   # 銀行轉彎角度（度）
@export var min_turn_radius: float = 80.0 # 最小轉彎半徑（增加轉彎半徑）
@export var arrival_distance: float = 30.0 # 到達目標的距離閾值

@export_group("外觀控制")
@export var max_pitch_angle: float = 30.0  # 最大俯衝/爬升角度（度）
@export var rotation_smoothing: float = 3.0 # 旋轉平滑度

@export_group("拍翅節奏")
@export var flap_duration: float = 0.8    # 拍翅上升時間
@export var glide_duration: float = 1.2   # 滑翔下降時間
@export var flap_lift_force: float = 100.0 # 拍翅上升力
@export var glide_fall_rate: float = 50.0  # 滑翔下降率
#endregion

#region 飛行狀態變數
var patrol_center: Vector2
var time_counter: float = 0.0
var flight_phase: FlightPhase = FlightPhase.FLAP_UP
var flap_timer: float = 0.0
var target_direction: Vector2 = Vector2.RIGHT
var current_direction: Vector2 = Vector2.RIGHT
var is_flying: bool = true
var flying_gravity_scale: float = 0.2
var walking_gravity_scale: float = 1.0

# 緊急迫降狀態
var is_emergency_landing: bool = false
var emergency_target: Vector2

# 追蹤行為控制
var chase_target_position: Vector2
var chase_update_timer: float = 0.0
var chase_update_interval: float = 1.5  # 每1.5秒重新評估目標
var min_chase_distance: float = 100.0   # 必須飛行的最小距離才能重新轉向

# 卡住檢測變數
var last_position: Vector2
var stuck_timer: float = 0.0
var stuck_threshold: float = 3.0  # 3秒沒移動視為卡住
var min_movement_distance: float = 10.0  # 最小移動距離
var last_unstuck_time: float = 0.0
var unstuck_cooldown: float = 8.0  # 8秒內不重複解困

# 模式切換控制
var mode_switch_timer: float = 0.0
var mode_switch_cooldown: float = 2.0  # 2秒內不重複切換模式
var last_collision_time: float = 0.0
var collision_cooldown: float = 1.0  # 1秒內忽略重複碰撞

enum FlightPhase { FLAP_UP, GLIDE_DOWN }
#endregion

func _ready() -> void:
	super._ready()
	patrol_center = global_position
	set_flight_mode(true)  # 默認飛行模式
	last_position = global_position
	
	# 確保初始方向向量有效
	if current_direction.length() < 0.1:
		current_direction = Vector2.RIGHT  # 默認朝右
	

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	check_if_stuck(delta)
	
	# 確保外觀始終更新（包括緊急迫降時）
	if is_emergency_landing:
		update_sprite_orientation(delta)


#region 通用飛行方法

## 朝目標飛行，包含波浪運動和轉向
func fly_towards_target(target_pos: Vector2, speed: float, delta: float) -> void:
	# 優先處理緊急迫降
	if is_emergency_landing:
		handle_emergency_landing(delta)
		return
	
	var distance_to_target = global_position.distance_to(target_pos)
	
	# 如果已經接近目標，減少運動強度避免搖擺
	var movement_factor = clamp(distance_to_target / arrival_distance, 0.1, 1.0)
	
	# 計算理想方向
	var ideal_direction = (target_pos - global_position).normalized()
	
	# 平滑轉向，距離近時轉向更慢
	var effective_turn_speed = turn_speed * movement_factor
	
	# 確保 current_direction 不會變成零向量
	if current_direction.length() < 0.1:
		current_direction = ideal_direction
	else:
		current_direction = current_direction.slerp(ideal_direction, effective_turn_speed * delta)
	
	# 確保方向向量已正規化
	current_direction = current_direction.normalized()
	
	# 基礎速度，距離近時速度降低
	var effective_speed = speed * movement_factor
	var base_velocity = current_direction * effective_speed
	
	# 只在距離足夠遠時應用波浪運動
	var wave_velocity = base_velocity
	if distance_to_target > arrival_distance:
		wave_velocity = apply_wave_motion(base_velocity, delta)
	
	# 應用拍翅節奏（減弱效果）
	var final_velocity = apply_flap_rhythm(wave_velocity, delta)
	
	# 設定速度
	velocity = velocity.move_toward(final_velocity, acceleration * delta)
	
	# 更新外觀朝向和旋轉
	update_sprite_orientation(delta)
	
	# 檢測是否卡住
	check_if_stuck(delta)


## 應用波浪狀運動
func apply_wave_motion(base_velocity: Vector2, delta: float) -> Vector2:
	time_counter += delta
	var wave_offset = sin(time_counter * wave_frequency) * wave_amplitude
	
	# 根據飛行方向調整波浪方向
	var perpendicular = Vector2(-base_velocity.y, base_velocity.x).normalized()
	return base_velocity + perpendicular * wave_offset * delta


## 應用拍翅節奏效果（減弱版本）
func apply_flap_rhythm(base_velocity: Vector2, delta: float) -> Vector2:
	flap_timer += delta
	
	match flight_phase:
		FlightPhase.FLAP_UP:
			if flap_timer >= flap_duration:
				flight_phase = FlightPhase.GLIDE_DOWN
				flap_timer = 0.0
			# 拍翅階段：輕微上升力
			return base_velocity + Vector2(0, -flap_lift_force * 0.3 * delta)
		
		FlightPhase.GLIDE_DOWN:
			if flap_timer >= glide_duration:
				flight_phase = FlightPhase.FLAP_UP
				flap_timer = 0.0
			# 滑翔階段：輕微下降
			return base_velocity + Vector2(0, glide_fall_rate * 0.3 * delta)
	
	return base_velocity


## 更新精靈外觀朝向和旋轉
func update_sprite_orientation(delta: float) -> void:
	if not is_instance_valid(animated_sprite):
		return
	
	# 地面行走模式使用簡化的方向邏輯
	if not is_flying:
		update_ground_walking_orientation()
		return
	
	# 飛行模式使用原本的複雜邏輯
	update_flying_orientation(delta)


## 更新地面行走時的外觀
func update_ground_walking_orientation() -> void:
	# 地面行走時只處理水平翻轉，不處理旋轉
	if velocity.length() > 5.0:  # 只在移動時更新朝向
		var should_flip = velocity.x < 0
		if animated_sprite.flip_h != should_flip:
			animated_sprite.flip_h = should_flip
	
	# 確保地面行走時角度為0
	animated_sprite.rotation_degrees = 0.0


## 更新飛行時的外觀
func update_flying_orientation(delta: float) -> void:
	# 使用飛行意圖方向而非實際速度來決定朝向
	var movement_vector = current_direction if current_direction.length() > 0.1 else velocity.normalized()
	
	
	# 1. 更新水平翻轉（面向飛行意圖方向）
	if movement_vector.length() > 0.1:
		var should_flip = movement_vector.x < 0
		if animated_sprite.flip_h != should_flip:
			animated_sprite.flip_h = should_flip
	
	# 2. 計算俯衝/爬升角度（使用飛行意圖方向）
	var pitch_angle = 0.0
	if movement_vector.length() > 0.1:
		# 根據飛行意圖的垂直分量計算角度
		var vertical_ratio = movement_vector.y / movement_vector.length()
		pitch_angle = vertical_ratio * max_pitch_angle
		# 限制角度範圍
		pitch_angle = clamp(pitch_angle, -max_pitch_angle, max_pitch_angle)
	
	# 3. 簡化銀行轉彎角度計算
	var bank_angle = 0.0
	# 迫降時不應用銀行轉彎，避免歪斜
	if not is_emergency_landing and current_direction.length() > 0 and velocity.length() > 5.0:
		# 使用轉向角速度來計算銀行角度
		var angular_velocity = current_direction.angle_to(velocity.normalized())
		bank_angle = clamp(angular_velocity * banking_angle * 0.2, -banking_angle * 0.3, banking_angle * 0.3)
	
	# 4. 組合最終旋轉角度
	var target_rotation = pitch_angle + bank_angle
	
	# 5. 平滑過渡到目標旋轉
	animated_sprite.rotation_degrees = lerp(
		animated_sprite.rotation_degrees,
		target_rotation,
		rotation_smoothing * delta
	)


## 巡邏範圍內選擇新目標
func pick_random_patrol_target() -> Vector2:
	var radius = patrol_area_radius
	var random_offset = Vector2(
		randf_range(-radius, radius),
		randf_range(-radius * 0.3, radius * 0.3)  # 垂直範圍較小，更符合鳥類行為
	)
	return patrol_center + random_offset


## 智能追蹤目標獲取（帶慣性）
func get_smart_chase_position(target: Node2D, delta: float) -> Vector2:
	if not is_instance_valid(target):
		return chase_target_position if chase_target_position != Vector2.ZERO else global_position
	
	# 更新計時器
	chase_update_timer += delta
	
	# 檢查是否需要重新評估目標
	var should_update_target = false
	
	# 情況1：還沒有設定過目標
	if chase_target_position == Vector2.ZERO:
		should_update_target = true
	
	# 情況2：時間間隔到了
	elif chase_update_timer >= chase_update_interval:
		should_update_target = true
	
	# 情況3：已經到達當前目標附近
	elif global_position.distance_to(chase_target_position) < 60:
		should_update_target = true
	
	# 重新計算目標位置
	if should_update_target:
		chase_update_timer = 0.0
		chase_target_position = calculate_intercept_position(target)
		
	
	return chase_target_position


## 計算攔截位置（預判玩家移動）
func calculate_intercept_position(target: Node2D) -> Vector2:
	var target_velocity = Vector2.ZERO
	if target.has_method("get_velocity"):
		target_velocity = target.get_velocity()
	elif "velocity" in target:
		target_velocity = target.velocity
	
	# 計算到達目標所需的時間
	var distance_to_target = global_position.distance_to(target.global_position)
	var time_to_reach = distance_to_target / chase_speed
	
	# 預測玩家在這個時間後的位置
	var predicted_pos = target.global_position + target_velocity * time_to_reach
	
	# 調整攻擊高度
	var intercept_pos = predicted_pos - Vector2(0, ideal_attack_height)
	
	# 確保位置安全（避開天花板）
	return adjust_for_ceiling_clearance(intercept_pos)


## 調整位置避開天花板
func adjust_for_ceiling_clearance(target_position: Vector2) -> Vector2:
	# 添加冷卻時間，避免頻繁調整
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	if (current_time - last_collision_time) < collision_cooldown:
		return target_position
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = target_position
	query.to = target_position - Vector2(0, 100)  # 檢查上方100像素
	query.collision_mask = collision_mask
	
	var result = space_state.intersect_ray(query)
	if result:
		# 如果上方有障礙物，調整到安全位置
		var original_y = target_position.y
		var adjusted_y = result.position.y + 80  # 距離障礙物80像素
		target_position.y = adjusted_y
		
		# 更新時間
		if abs(adjusted_y - original_y) > 20:
			last_collision_time = current_time
	
	return target_position


## 平滑改變飛行速度
func adjust_flight_speed(target_speed: float, delta: float) -> void:
	var current_speed = velocity.length()
	var new_speed = move_toward(current_speed, target_speed, acceleration * delta)
	if velocity.length() > 0:
		velocity = velocity.normalized() * new_speed

#endregion


#region 飛行動畫方法（子類可覆寫）
func _get_fly_animation() -> String: return "fly"
func _get_soar_animation() -> String: return "soar" 
func _get_takeoff_animation() -> String: return "takeoff"
func _get_land_animation() -> String: return "land"
func _get_dive_animation() -> String: return "dive"
#endregion


#region 調試方法

## 檢測是否卡住
func check_if_stuck(delta: float) -> void:
	var current_pos = global_position
	var distance_moved = current_pos.distance_to(last_position)
	
	# 檢查是否有碰撞
	var is_colliding = is_on_wall() or is_on_ceiling() or is_on_floor()
	
	# 特殊處理：飛行模式下碰到地面（添加冷卻時間）
	mode_switch_timer += delta
	if is_flying and is_on_floor() and mode_switch_timer >= mode_switch_cooldown:
		handle_ground_collision()
		mode_switch_timer = 0.0
		return
	
	# 更寬松的卡住判定：只在確實嚴重卡住時才觸發
	var is_truly_stuck = distance_moved < min_movement_distance * delta and is_colliding and velocity.length() < 10.0
	
	if is_truly_stuck:
		stuck_timer += delta
	else:
		stuck_timer = max(0.0, stuck_timer - delta * 2.0)  # 快速減少卡住計時器
	
	# 更新位置記錄
	last_position = current_pos
	
	# 只在真正卡住很久時才嘗試解困
	if stuck_timer >= stuck_threshold:
		# 檢查解困冷卻時間
		var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
		if (current_time - last_unstuck_time) >= unstuck_cooldown:
			attempt_unstuck()
			last_unstuck_time = current_time
			stuck_timer = 0.0  # 重置卡住計時器


## 嘗試解除卡住狀態
func attempt_unstuck() -> void:
	
	# 首先嘗試簡單的位移解困
	if try_simple_unstuck():
		return
	
	# 如果簡單解困失敗，才使用緊急迫降
	var safe_landing_spot = find_safe_landing_spot()
	
	if safe_landing_spot != Vector2.ZERO:
		start_emergency_landing(safe_landing_spot)
	else:
		# 如果找不到安全地點，回到巡邏中心
		start_emergency_landing(patrol_center)


## 嘗試簡單的位移解困
func try_simple_unstuck() -> bool:
	
	# 嘗試向不同方向移動一小段距離
	var escape_directions = [Vector2.UP * 50, Vector2.LEFT * 50, Vector2.RIGHT * 50, Vector2(50, -50), Vector2(-50, -50)]
	
	for direction in escape_directions:
		var test_position = global_position + direction
		if is_position_safe(test_position):
			global_position = test_position
			velocity = Vector2.ZERO
			stuck_timer = 0.0
			return true
	
	return false


## 檢查位置是否安全（無碰撞）
func is_position_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.collision_mask = collision_mask
	
	# 檢查四個方向是否有障礙物
	var check_distances = [30, 30, 30, 30]  # 上下左右檢查30像素
	var check_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for i in range(check_directions.size()):
		query.from = pos
		query.to = pos + check_directions[i] * check_distances[i]
		var result = space_state.intersect_ray(query)
		if result:
			return false  # 有障礙物，不安全
	
	return true  # 沒有障礙物，安全


## 尋找安全的降落地點
func find_safe_landing_spot() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.collision_mask = collision_mask
	
	# 搜索範圍和方向
	var search_distances = [50, 100, 150, 200]
	var search_angles = [0, 45, 90, 135, 180, 225, 270, 315]  # 八個方向
	
	for distance in search_distances:
		for angle_deg in search_angles:
			var angle_rad = deg_to_rad(angle_deg)
			var search_direction = Vector2(cos(angle_rad), sin(angle_rad))
			var search_pos = global_position + search_direction * distance
			
			# 從搜索點向下射線，找地面
			query.from = search_pos
			query.to = search_pos + Vector2(0, 300)  # 向下300像素
			var ground_result = space_state.intersect_ray(query)
			
			if ground_result:
				var ground_y = ground_result.position.y
				var landing_spot = Vector2(search_pos.x, ground_y - 30)  # 地面上方30像素
				
				# 檢查降落點上方是否有足夠空間
				query.from = landing_spot
				query.to = landing_spot - Vector2(0, 80)  # 檢查上方80像素
				var ceiling_result = space_state.intersect_ray(query)
				
				if not ceiling_result:  # 上方沒有障礙物
					return landing_spot
	
	return Vector2.ZERO


## 開始緊急迫降
func start_emergency_landing(target_pos: Vector2) -> void:
	is_emergency_landing = true
	emergency_target = target_pos
	stuck_timer = 0.0
	
	# 切換到迫降專用的重力設置
	gravity_scale = 0.5  # 比正常飛行重一些，但比行走輕
	
	# 強制重新選擇目標，避免回到卡住的地方
	force_new_target()


## 處理緊急迫降
func handle_emergency_landing(delta: float) -> void:
	var distance_to_emergency = global_position.distance_to(emergency_target)
	
	# 如果到達迫降點附近
	if distance_to_emergency < 40:
		is_emergency_landing = false
		set_flight_mode(true)  # 恢復正常飛行模式
		return
	
	# 計算迫降方向
	var emergency_direction = (emergency_target - global_position).normalized()
	
	# 較快調整 current_direction 到迫降方向（鳥類緊急情況下轉向很快）
	if current_direction.length() < 0.1:
		current_direction = emergency_direction
	else:
		current_direction = current_direction.slerp(emergency_direction, turn_speed * 1.5 * delta)
	
	# 確保方向正規化
	current_direction = current_direction.normalized()
	
	# 緊急迫降時速度應該更快（真實鳥類緊急迫降很迅速）
	var emergency_speed = chase_speed * 1.2  # 比追蹤速度還快
	var emergency_velocity = current_direction * emergency_speed
	
	# 設定速度，加快加速度使迫降更迅速
	velocity = velocity.move_toward(emergency_velocity, acceleration * 2.0 * delta)
	
	# 更新外觀朝向
	update_sprite_orientation(delta)


## 強制重新選擇目標
func force_new_target() -> void:
	
	match current_state_name:
		"Chase":
			# 追蹤狀態：重置追蹤目標而不切換狀態
			chase_target_position = Vector2.ZERO
			chase_update_timer = 0.0
		"Attack":
			# 攻擊狀態：切換到巡邏狀態
			change_state("Patrol")
		"Patrol":
			# 巡邏狀態：重新選擇巡邏目標
			# 通知巡邏狀態重新選擇目標
			if current_state and current_state.has_method("force_new_patrol_target"):
				current_state.force_new_patrol_target()


## 處理飛行模式下的地面碰撞
func handle_ground_collision() -> void:
	
	# 檢查當前狀態是否支援地面模式
	var current_patrol_state = current_state
	if current_patrol_state and current_patrol_state.has_method("_pick_new_action") and current_state_name == "Patrol":
		# 只有在巡邏狀態且子狀態不是WALKING時才切換
		if not ("sub_state" in current_patrol_state and current_patrol_state.sub_state == current_patrol_state.SubState.WALKING):
			set_flight_mode(false)
			
			# 通知巡邏狀態強制選擇地面行為
			if current_patrol_state.has_method("force_ground_mode"):
				current_patrol_state.force_ground_mode()
			else:
				# 備用方案：直接設置子狀態為行走
				if "sub_state" in current_patrol_state:
					current_patrol_state.sub_state = current_patrol_state.SubState.WALKING
	else:
		# 其他狀態（如追蹤、攻擊）需要抬升離開地面
		elevate_from_ground()


## 從地面快速抬升
func elevate_from_ground() -> void:
	# 添加向上的速度分量，快速脫離地面
	var lift_velocity = Vector2(velocity.x * 0.5, -climb_speed * 0.8)
	velocity = velocity.move_toward(lift_velocity, acceleration * 3.0 * get_physics_process_delta_time())
	
	# 強制更新飛行方向為向上
	current_direction = Vector2(current_direction.x, -0.5).normalized()
	


## 設置飛行/行走模式
func set_flight_mode(flying: bool) -> void:
	# 避免重複設置相同模式
	if is_flying == flying:
		return
		
	is_flying = flying
	if flying:
		gravity_scale = flying_gravity_scale
	else:
		gravity_scale = walking_gravity_scale
		# 切換到行走模式時重置角度和垂直速度
		if is_instance_valid(animated_sprite):
			animated_sprite.rotation_degrees = 0.0
		velocity.y = 0.0  # 清除垂直速度，避免彈跳

#endregion
