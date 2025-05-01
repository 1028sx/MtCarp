class_name State_Dash
extends PlayerState

@export var idle_state: PlayerState
@export var fall_state: PlayerState
@export var attack_state: PlayerState # 用於衝刺攻擊轉換

var dash_attack_requested := false

func enter() -> void:
	# print("Entering Dash State") # Debug
	dash_attack_requested = false

	# 設置計時器和冷卻
	player.dash_timer = player.dash_duration
	player.can_dash = false # 在衝刺期間不能再次衝刺
	player.dash_cooldown_timer = player.dash_cooldown # 開始計算冷卻

	# 確定衝刺方向
	var input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		player.dash_direction = sign(input_direction)
	else:
		# 如果沒有輸入，則根據角色朝向衝刺
		player.dash_direction = -1 if player.animated_sprite.flip_h else 1

	# 應用衝刺速度 (注意: 原代碼速度較快，這裡暫時沿用)
	# 應用衝刺速度加成 (例如 'swift_dash' 效果)
	var current_dash_speed = player.dash_speed
	if player.active_effects.has("swift_dash"):
		current_dash_speed *= player.swift_dash_multiplier
	player.velocity = Vector2(player.dash_direction * current_dash_speed, 0)

	# 播放動畫和特效
	player.animated_sprite.play("dash")
	if player.effect_manager and player.effect_manager.has_method("play_dash"):
		player.effect_manager.play_dash(player.dash_direction < 0)

	# 處理碰撞 (暫時關閉與地形的碰撞，模擬穿透效果，可選)
	# 取消註解以啟用穿牆
	player.set_collision_mask_value(1, false)

	# 處理完美迴避 (如果需要)
	# if player.active_effects.has("agile") and player.is_about_to_be_hit():
	# 	player.agile_perfect_dodge = true
	# 	player.agile_dodge_timer = player.agile_dodge_window
	# 	# 播放特效/音效...

func process_physics(delta: float) -> void:
	# 保持衝刺速度，如果不在地面則稍微抑制y軸速度
	var current_dash_speed = player.dash_speed
	if player.active_effects.has("swift_dash"):
		current_dash_speed *= player.swift_dash_multiplier
	player.velocity.x = player.dash_direction * current_dash_speed
	if not player.is_on_floor():
		player.velocity.y = min(player.velocity.y, 0) # 限制向上的速度
		player.velocity.y += player.gravity * delta * 0.5 # 可以施加部分重力

	# 執行移動
	player.move_and_slide()

	# 更新衝刺計時器
	player.dash_timer -= delta

func process_input(_event: InputEvent) -> void:
	# 在衝刺過程中按下攻擊鍵，標記為衝刺攻擊請求
	if Input.is_action_just_pressed("attack"):
		dash_attack_requested = true

func get_transition() -> PlayerState:
	# 檢查衝刺是否結束
	if player.dash_timer <= 0:
		# 如果請求了衝刺攻擊，轉換到攻擊狀態
		if dash_attack_requested and attack_state:
			# 可以在 attack_state.enter() 中處理衝刺攻擊的特殊邏輯
			# 或者創建一個專門的 State_DashAttack
			attack_state.set("is_dash_attack", true) # 傳遞信息給攻擊狀態
			return attack_state
		else:
			# 否則根據是否在地面轉換到 Idle 或 Fall
			return fall_state if not player.is_on_floor() else idle_state

	# 如果在衝刺中請求了攻擊，也可以立即轉換（如果設計需要）
	# elif dash_attack_requested and attack_state:
	# 	 attack_state.set("is_dash_attack", true)
	# 	 return attack_state

	return null

func exit() -> void:
	# print("Exiting Dash State") # Debug
	# 恢復碰撞 (如果之前修改過)
	# 取消註解以恢復碰撞
	player.set_collision_mask_value(1, true)
	# player._check_and_fix_wall_collision() # 檢查是否卡牆

	# 根據是否是衝刺攻擊，調整結束時的速度
	if not dash_attack_requested:
		player.velocity.x *= 0.5 # 衝刺結束後速度減半
		# 重置敏捷衝刺攻擊計數器 (如果不是以攻擊結束衝刺)
		if player.active_effects.has("agile_dash"):
			player.agile_dash_attack_count = player.agile_dash_attack_limit

	# 觸發衝刺波 (如果擁有能力且不是以攻擊結束)
	# 注意：原代碼是在 start_dash_attack 時觸發，這裡移到 exit
	# if player.has_dash_wave and dash_attack_requested:
	# 	player.create_dash_wave()

	# player.is_dashing = false # 移除標誌，由狀態決定
	pass
