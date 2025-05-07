# scripts/player/states/State_Fall.gd
class_name State_Fall
extends PlayerState

@export var idle_state: PlayerState
@export var jump_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState
@export var wall_slide_state: PlayerState

# 可選：空中控制的減速率
@export var air_control_factor: float = 0.8

func enter() -> void:
	# 通常跳躍和下落可以共用一個動畫，或者你可以創建一個單獨的 fall 動畫
	# 如果動畫有不同的幀表示上升和下落，可能需要在這裏或 JumpState 中設置 frame
	player.animated_sprite.play("jump")

func process_physics(delta: float) -> void:
	# 應用重力，乘以係數減緩下落
	player.velocity.y += player.gravity * delta * 0.7

	# 空中水平移動控制
	var direction = Input.get_axis("move_left", "move_right")
	var current_speed = player.speed * air_control_factor # 空中減速
	
	if direction:
		player.velocity.x = direction * current_speed
		player.animated_sprite.flip_h = direction < 0
		if player.attack_area:
			player.attack_area.scale.x = -1 if direction < 0 else 1
		if player.special_attack_area:
			player.special_attack_area.scale.x = -1 if direction < 0 else 1
	else:
		# 空中水平減速
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed) # 使用空中減速度

	# ----- 新增：滑牆檢查 -----
	# 移除方向判斷，只要接觸牆壁且不在地上就嘗試滑牆
	# 加入冷卻判斷
	if wall_slide_state and not player.is_on_floor() and player.wall_jump_cooldown_timer <= 0:
		var wall_normal = player.get_raycast_wall_normal()
		if wall_normal != Vector2.ZERO:
			# 在這裡直接轉換狀態，避免執行 move_and_slide 後卡進牆裡
			state_machine._transition_to(wall_slide_state)
			return # 提前退出 process_physics

	# 執行移動
	player.move_and_slide()

func get_transition() -> PlayerState:
	# 檢查是否落地
	if player.is_on_floor():
		# 可以在這裡添加落地特效或聲音
		return idle_state

	# 檢查跳躍緩衝 (二段跳)
	if player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
		player.jump_buffer_timer = 0.0 # 使用跳躍緩衝後立即消耗掉
		return jump_state
	
	# 檢查攻擊輸入 (空中攻擊)
	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state
	
	# 修改特殊攻擊檢查 (空中)
	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack") # 假設節點名為 SpecialAttack
		if sa_state:
			return sa_state
		else:
			printerr("特殊攻擊狀態節點 (specialattack) 未在狀態機中找到！")

	# 檢查衝刺輸入 (空中衝刺)
	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null 
