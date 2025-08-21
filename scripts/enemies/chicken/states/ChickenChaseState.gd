extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name ChickenChaseState

#region 導出變數 - 可在編輯器中調整的跳躍參數
@export_group("跳躍決策參數")
# 情境1: 隨機前跳
@export var random_jump_min_chase_time: float = 1.0  # 至少追擊多久後才可能觸發隨機跳
@export var random_jump_chance: float = 0.2         # 每秒觸發隨機跳的機率
@export var random_jump_velocity: Vector2 = Vector2(180, -200) # 隨機前跳的固定速度（調整為合理範圍）

# 情境2: 目標跳躍攻擊
@export var target_jump_max_dist: float = 200.0     # 可觸發目標跳躍的最大距離
@export var target_jump_min_dist: float = 100.0     # 可觸發目標跳躍的最小距離
@export var target_jump_chance: float = 0.4         # 在區間內每秒觸發的機率

# 情境3: 平台跳躍
@export var platform_jump_max_height_diff: float = 150.0 # 玩家在上方多高以內可觸發
@export var platform_jump_max_h_dist: float = 100.0    # 水平距離多近可觸發

@export_group("通用參數")
@export var attack_distance: float = 60.0 # 進入攻擊狀態的距離（調整為更合理的近戰距離）
#endregion

#region 內部變數
# 從主腳本注入的共享資源
const PlayerGlobalScript = preload("res://scripts/globals/PlayerGlobal.gd")
var jump_cooldown_timer: Timer

# 狀態內部計時器
var _chase_timer: float = 0.0
var _random_jump_rng = RandomNumberGenerator.new()
var _jump_calculation_cooldown_timer: float = 0.0 # 新增：跳躍計算冷卻
const JUMP_CALCULATION_COOLDOWN = 1.0 # 延長冷卻時間到1.0秒，減少重複計算
#endregion

#region 狀態生命週期
func on_enter() -> void:
	super.on_enter()
	_chase_timer = 0.0
	_jump_calculation_cooldown_timer = 0.0
	owner.animated_sprite.play(owner._get_walk_animation())

func on_exit() -> void:
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	if not PlayerGlobalScript.is_player_available():
		owner.change_state("Idle")
		return
	
	_chase_timer += delta
	if _jump_calculation_cooldown_timer > 0:
		_jump_calculation_cooldown_timer -= delta
	
	var player = PlayerGlobalScript.get_player()
	var distance_to_player = owner.global_position.distance_to(player.global_position)

	# 優先檢查是否進入攻擊距離
	if distance_to_player <= attack_distance:
		owner.change_state("Attack")
		return
	
	# 檢查是否可以執行跳躍（冷卻完畢且在地面上）
	var can_jump = jump_cooldown_timer.is_stopped() and owner.is_on_floor()
	if not can_jump:
		_perform_chase(delta, player) # 如果不能跳，就執行普通追擊
		return

	# 跳躍決策樹 - 但避免在攻擊範圍附近跳躍
	# 有計算需求的跳躍，納入計算冷卻，避免訊息轟炸
	if _jump_calculation_cooldown_timer <= 0 and distance_to_player > attack_distance * 1.2:
		if _try_perform_platform_jump(player):
			return
		if _try_perform_target_jump(delta, distance_to_player, player):
			return
	
	# 純隨機跳躍不受計算冷卻影響
	if _try_perform_random_jump(delta, player):
		return

	# 如果沒有任何跳躍被觸發，則執行普通追擊
	_perform_chase(delta, player)
#endregion

#region 跳躍邏輯實現
func _try_perform_platform_jump(player: CharacterBody2D) -> bool:
	var height_difference = owner.global_position.y - player.global_position.y
	var h_distance = abs(owner.global_position.x - player.global_position.x)
	
	# 放寬條件：如果玩家在上方且距離合理，就嘗試跳躍
	if height_difference > 0 and height_difference <= 200.0 and h_distance <= 150.0:
		var jump_vel = _calculate_jump_velocity_to_target(player.global_position)
		if jump_vel != Vector2.ZERO:
			_execute_jump(jump_vel)
			return true
		else:
			# 計算失敗，啟動計算冷卻，防止垃圾訊息
			_jump_calculation_cooldown_timer = JUMP_CALCULATION_COOLDOWN
	return false

func _try_perform_target_jump(delta: float, distance_to_player: float, player: CharacterBody2D) -> bool:
	if distance_to_player > target_jump_min_dist and distance_to_player <= target_jump_max_dist:
		if _random_jump_rng.randf() < target_jump_chance * delta:
			var jump_vel = _calculate_jump_velocity_to_target(player.global_position)
			if jump_vel != Vector2.ZERO:
				_execute_jump(jump_vel)
				# 設計：目標跳躍成功後，預期是直接攻擊，所以可以立即重置追擊計時器
				_chase_timer = 0.0
				return true
			else:
				# 計算失敗，啟動計算冷卻
				_jump_calculation_cooldown_timer = JUMP_CALCULATION_COOLDOWN
	return false

func _try_perform_random_jump(delta: float, player: CharacterBody2D) -> bool:
	if _chase_timer >= random_jump_min_chase_time:
		if _random_jump_rng.randf() < random_jump_chance * delta:
			# 隨機跳躍需要考慮方向
			var jump_direction = sign(player.global_position.x - owner.global_position.x)
			var final_jump_velocity = Vector2(random_jump_velocity.x * jump_direction, random_jump_velocity.y)
			_execute_jump(final_jump_velocity)
			return true
	return false

func _execute_jump(velocity: Vector2) -> void:
	var jump_state = owner.states.get("Jump")
	if jump_state and jump_state is ChickenJumpState:
		jump_state.jump_velocity = velocity
		owner.change_state("Jump")
		if jump_cooldown_timer:
			jump_cooldown_timer.start() # 開始計時
#endregion

#region 核心行為
func _perform_chase(delta: float, player: CharacterBody2D) -> void:
	var direction_to_player = owner.global_position.direction_to(player.global_position)
	owner.velocity.x = move_toward(owner.velocity.x, direction_to_player.x * owner.move_speed, owner.acceleration * delta)
	owner._update_sprite_flip()
#endregion

#region 輔助函式 - 拋射物軌跡計算
func _calculate_jump_velocity_to_target(target_position: Vector2) -> Vector2:
	var target_vector = target_position - owner.global_position
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * owner.gravity_scale
	
	# --- 演算法修正 ---
	# 我們不再使用固定的初始垂直速度，而是根據目標高度動態調整。
	# 目標：即使犧牲部分跳躍高度，也要找到可行的跳躍路徑。
	var initial_vy = -450.0  # 調整為與玩家相仿：接近玩家的-450 

	# 計算最大可達高度。這個公式基於物理學中的鉛直上拋運動。
	# 在最高點，末速度為 0，所以 0 = initial_vy^2 + 2 * g * delta_y_max
	# 因此，delta_y_max = -initial_vy^2 / (2 * g)
	var max_jump_height = (initial_vy * initial_vy) / (2 * gravity)
	
	# 如果目標高度超過最大可達高度，使用簡單的跳躍策略
	if -target_vector.y > max_jump_height:
		# 使用簡化策略：朝玩家方向跳躍，但不強求到達確切位置
		var direction_to_player = sign(target_vector.x)
		var simplified_jump = Vector2(direction_to_player * 200, -350)  # 固定的合理跳躍
		return simplified_jump

	# 解二次方程式來找出飛行時間 't': 
	# 公式: delta_y = initial_vy * t + 0.5 * gravity * t^2
	# (0.5 * gravity) * t^2 + (initial_vy) * t - delta_y = 0
	var a: float = 0.5 * gravity
	var b: float = initial_vy
	var c: float = -target_vector.y
	
	var discriminant: float = (b * b) - (4 * a * c)
	
	if discriminant < 0:
		print("        [ChickenDebug] CALC FAILED: Target is physically unreachable (discriminant < 0).")
		return Vector2.ZERO # 目標點在物理上無法達到

	# 舊邏輯問題點：總是選擇 max(t1, t2)，導致總是採用高拋物線，看起來很慢。
	# 新邏輯：優先選擇最小的正數時間解，以獲得最低、最快的跳躍路徑。
	var time1: float = (-b + sqrt(discriminant)) / (2 * a)
	var time2: float = (-b - sqrt(discriminant)) / (2 * a)
	var jump_time: float = -1.0
	
	if time1 > 0 and time2 > 0:
		jump_time = min(time1, time2)
	elif time1 > 0:
		jump_time = time1
	elif time2 > 0:
		jump_time = time2
	else: # 兩個解都是負數或零
		print("        [ChickenDebug] CALC FAILED: No positive solution for jump time.")
		return Vector2.ZERO # 沒有正數時間解
		

	# 有了飛行時間，計算所需的水平速度
	var initial_vx = target_vector.x / jump_time

	var jump_velocity = Vector2(initial_vx, initial_vy)

	# 檢查所需的水平速度是否在雞的能力範圍內
	if abs(jump_velocity.x) > 300: # 最大水平速度（調整為與玩家相仿的合理範圍）
		return Vector2.ZERO

	# 暫時禁用障礙物檢測 - 讓物理系統自然處理碰撞
	# if owner.jump_obstacle_raycast:
	#	owner.jump_obstacle_raycast.target_position = target_vector
	#	owner.jump_obstacle_raycast.force_raycast_update()
	#	if owner.jump_obstacle_raycast.is_colliding():
	#		print("        [ChickenDebug] CALC FAILED: Obstacle detected at ", owner.jump_obstacle_raycast.get_collision_point())
	#		return Vector2.ZERO # 路徑上有障礙物

	# 所有計算都成功，返回最終速度
	return jump_velocity
#endregion 
