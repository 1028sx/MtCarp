class_name State_Run
extends PlayerState

@export var idle_state: PlayerState
@export var jump_state: PlayerState
@export var fall_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState

func enter() -> void:
	player.animated_sprite.play("run")

func process_physics(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	# 計算速度 (基礎速度，未來可以應用效果修改)
	# 注意：這裡我們直接使用 player.speed，之後可以根據需要引入效果系統
	var current_speed = player.speed
	# 可以在這裡加入狂戰士等效果的速度修正
	# current_speed *= player.get_berserker_multiplier()

	if direction:
		player.velocity.x = direction * current_speed
		# 翻轉角色和攻擊區域
		player.animated_sprite.flip_h = direction < 0
		if player.attack_area:
			player.attack_area.scale.x = -1 if direction < 0 else 1
		if player.special_attack_area:
			player.special_attack_area.scale.x = -1 if direction < 0 else 1
	else:
		# 如果沒有方向輸入（雖然 get_transition 會處理到 Idle），以防萬一還是減速
		player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	
	# 應用重力 (主要由 FallState 處理，但在邊緣可能需要)
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	
	# 執行移動
	player.move_and_slide()

func get_transition() -> PlayerState:
	# 檢查是否下落
	if not player.is_on_floor() and player.velocity.y > 0.1: # 加一個小的閾值避免抖動
		return fall_state
	
	# 檢查跳躍輸入
	if Input.is_action_just_pressed("jump"):
		return jump_state
	
	# 檢查是否停止移動
	var direction = Input.get_axis("move_left", "move_right")
	if direction == 0:
		return idle_state

	# 檢查攻擊輸入
	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state

	# 修改特殊攻擊檢查
	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack") # 假設節點名為 SpecialAttack
		if sa_state:
			return sa_state
		else:
			printerr("特殊攻擊狀態節點 (specialattack) 未在狀態機中找到！")

	# 檢查衝刺輸入
	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null
