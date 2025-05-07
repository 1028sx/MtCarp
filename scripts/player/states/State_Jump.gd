class_name State_Jump
extends PlayerState

@export var fall_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState
@export var wall_slide_state: PlayerState

# 可選：空中控制的減速率
@export var air_control_factor: float = 0.8
# 可選：二段跳速度比例
@export var double_jump_velocity_multiplier: float = 0.8
var just_entered_from_ground := false

func enter() -> void:
	# var initial_jump_count = player.jump_count # 不再需要
	# just_entered_from_ground = false # 不再需要

	# 檢查是否是蹬牆跳 (由 WallSlideState 觸發)
	if player.last_jump_was_wall_jump:
		player.last_jump_was_wall_jump = false
		var wall_normal = player.get_raycast_wall_normal()
		# print("[Debug Jump] Wall Jump Enter: WallNormal=", wall_normal) # 註解掉
		if wall_normal != Vector2.ZERO:
			# 施加蹬牆跳力
			player.velocity.x = wall_normal.x * player.wall_jump_horizontal_force
			player.velocity.y = player.jump_velocity * player.wall_jump_vertical_force_multiplier # 0.6倍力
			player.jump_count = 1 # 蹬牆跳算作第一次跳躍
			player.is_double_jumping_after_wall_jump = false
			player.animated_sprite.play("wall_jump") # 播放蹬牆跳動畫
			player.jump_buffer_timer = 0.0 # 消耗跳躍緩衝
			player.wall_jump_cooldown_timer = 0.1 # <--- 設置冷卻
		else:
			# 如果意外觸發但沒獲取到牆壁法線，執行普通跳躍 (備份)
			_perform_ground_jump()
	else:
		# 普通地面跳躍 (由 Idle/Move State 觸發)
		_perform_ground_jump()

# 抽出地面跳躍邏輯，方便複用
func _perform_ground_jump() -> void:
	player.velocity.y = player.jump_velocity # 完整跳躍力
	player.jump_count = 1
	player.animated_sprite.play("jump") # 播放普通跳躍動畫
	player.jump_buffer_timer = 0.0 # 消耗跳躍緩衝
	player.is_double_jumping_after_wall_jump = false # 地面跳後不是特殊二段跳

func process_physics(delta: float) -> void:
	# 處理二段跳 (空中跳躍)
	# if not just_entered_from_ground and player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
	# 修改條件：移除 just_entered_from_ground，因為蹬牆跳也會進入此狀態
	if player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
		player.jump_buffer_timer = 0.0
		player.jump_count += 1
		
		# 計算二段跳力
		var jump_force: float
		if player.is_double_jumping_after_wall_jump: 
			# 蹬牆跳後的二段跳，使用 0.48 倍基礎跳躍力
			jump_force = player.jump_velocity * player.wall_jump_vertical_force_multiplier * player.wall_double_jump_multiplier
			# print("Double Jump after Wall Jump! Force: ", jump_force)
		else:
			# 普通二段跳，使用 0.8 倍基礎跳躍力
			jump_force = player.jump_velocity * double_jump_velocity_multiplier
			# print("Normal Double Jump! Force: ", jump_force)
		
		player.velocity.y = jump_force

		# 二段跳特效
		if player.effect_manager and player.effect_manager.has_method("play_double_jump"):
			player.effect_manager.play_double_jump(player.animated_sprite.flip_h)
		
		# 播放跳躍動畫 (如果二段跳動畫不同，可以在這裡改)
		player.animated_sprite.play("jump") 

	# 應用重力 (稍微減弱，讓跳躍感覺更好)
	var gravity_step = player.gravity * delta * 0.7
	player.velocity.y += gravity_step

	# 空中水平移動控制
	var direction = Input.get_axis("move_left", "move_right")
	var current_speed = player.speed * air_control_factor

	if direction:
		player.velocity.x = direction * current_speed
		player.animated_sprite.flip_h = direction < 0
		if player.attack_area:
			player.attack_area.scale.x = -1 if direction < 0 else 1
		if player.special_attack_area:
			player.special_attack_area.scale.x = -1 if direction < 0 else 1
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)

	# ----- 新增：滑牆檢查 -----
	# 在 move_and_slide 之前檢查
	# 移除方向判斷，僅在下落時檢查是否接觸牆壁
	# 加入冷卻判斷
	if wall_slide_state and not player.is_on_floor() and player.velocity.y > 0 and player.wall_jump_cooldown_timer <= 0:
		var wall_normal = player.get_raycast_wall_normal()
		# print("[Debug Jump] WallSlide Check: OnFloor=", player.is_on_floor(), " VelY=", player.velocity.y, " Cooldown=", player.wall_jump_cooldown_timer, " WallNormal=", wall_normal) # 註解掉
		if wall_normal != Vector2.ZERO:
			# print("[Debug Jump] Transitioning to WallSlide") # 註解掉
			state_machine._transition_to(wall_slide_state)
			return # 提前退出

	# 執行移動
	player.move_and_slide()

	# just_entered_from_ground = false # 不再需要

func get_transition() -> PlayerState:
	# 1. 檢查是否開始下落 (優先級最高)
	if player.velocity.y > 0:
		return fall_state
	
	# 2. 檢查是否應該滑牆 (如果 process_physics 中沒有成功轉換，且速度向上時)
	#    這種情況比較少見，但以防萬一
	# if wall_slide_state and player.is_touching_wall() and not player.is_on_floor():
	#     var wall_normal = player.get_wall_normal()
	#     var input_direction = Input.get_axis("move_left", "move_right")
	#     if input_direction == 0 or (wall_normal.x != 0 and sign(input_direction) == -sign(wall_normal.x)):
	#         return wall_slide_state

	# 3. 檢查攻擊輸入
	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state

	# 4. 檢查特殊攻擊輸入
	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			return sa_state
		else:
			printerr("特殊攻擊狀態節點 (specialattack) 未在狀態機中找到！")

	# 5. 檢查衝刺輸入
	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null
