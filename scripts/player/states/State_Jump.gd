class_name State_Jump
extends PlayerState

@export var fall_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState

# 可選：空中控制的減速率
@export var air_control_factor: float = 0.8
# 可選：二段跳速度比例
@export var double_jump_velocity_multiplier: float = 0.8
var just_entered_from_ground := false

func enter() -> void:
	var initial_jump_count = player.jump_count 
	just_entered_from_ground = false
	
	if initial_jump_count == 0: # 第一次跳躍
		player.velocity.y = player.jump_velocity
		player.jump_count = 1
		just_entered_from_ground = true
		player.jump_buffer_timer = 0.0
	player.animated_sprite.play("jump")

func process_physics(delta: float) -> void:
	if not just_entered_from_ground and player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
		player.jump_buffer_timer = 0.0
		player.jump_count += 1
		player.velocity.y = player.jump_velocity * double_jump_velocity_multiplier
		if player.effect_manager and player.effect_manager.has_method("play_double_jump"):
			player.effect_manager.play_double_jump(player.animated_sprite.flip_h)
	
	var gravity_step = player.gravity * delta * 0.7
	player.velocity.y += gravity_step

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

	player.move_and_slide()
	
	just_entered_from_ground = false

func get_transition() -> PlayerState:
	if player.velocity.y > 0:
		return fall_state

	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state
	
	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			return sa_state
		else:
			printerr("特殊攻擊狀態節點 (specialattack) 未在狀態機中找到！")

	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null
