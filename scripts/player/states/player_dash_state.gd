class_name PlayerDashState
extends PlayerState

@export var idle_state: PlayerState
@export var fall_state: PlayerState
@export var attack_state: PlayerState

var dash_attack_requested := false

func enter() -> void:
	dash_attack_requested = false


	player.dash_timer = player.dash_duration
	player.can_dash = false
	player.dash_cooldown_timer = player.dash_cooldown

	var input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		player.dash_direction = sign(input_direction)
	else:
		player.dash_direction = -1 if player.animated_sprite.flip_h else 1

	var current_dash_speed = player.dash_speed
	if player.active_effects.has("swift_dash"):
		current_dash_speed *= player.swift_dash_multiplier
	player.velocity = Vector2(player.dash_direction * current_dash_speed, 0)

	player.animated_sprite.play("dash")
	if player.player_effect_manager and player.player_effect_manager.has_method("play_dash"):
		player.player_effect_manager.play_dash(player.dash_direction < 0)
	player.set_collision_mask_value(1, false)

func process_physics(delta: float) -> void:
	var current_dash_speed = player.dash_speed
	if player.active_effects.has("swift_dash"):
		current_dash_speed *= player.swift_dash_multiplier
	player.velocity.x = player.dash_direction * current_dash_speed
	if not player.is_on_floor():
		player.velocity.y = min(player.velocity.y, 0)
		player.velocity.y += player.gravity * delta * 0.5

	player.move_and_slide()

	player.dash_timer -= delta

func process_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("attack"):
		dash_attack_requested = true

func get_transition() -> PlayerState:
	if player.dash_timer <= 0:
		if dash_attack_requested and attack_state:
			attack_state.set("is_dash_attack", true)
			return attack_state
		else:
			return fall_state if not player.is_on_floor() else idle_state

	return null

func exit() -> void:
	player.set_collision_mask_value(1, true)

	if not dash_attack_requested:
		player.velocity.x *= 0.5
		if player.active_effects.has("agile_dash"):
			player.agile_dash_attack_count = player.agile_dash_attack_limit

	# 觸發衝刺波 (如果擁有能力且不是以攻擊結束)
	# 注意：原代碼是在 start_dash_attack 時觸發，這裡移到 exit
	# if player.has_dash_wave and dash_attack_requested:
	# 	player.create_dash_wave()

	# player.is_dashing = false # 移除標誌，由狀態決定
	pass
