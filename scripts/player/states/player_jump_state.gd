class_name PlayerJumpState
extends PlayerState

@export var fall_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState
@export var wall_slide_state: PlayerState
@export var air_control_factor: float = 0.8
@export var double_jump_velocity_multiplier: float = 0.8
var just_entered_from_ground := false

var came_from_air_state := false

func enter() -> void:
	if player.last_jump_was_wall_jump:
		player.last_jump_was_wall_jump = false
		var wall_normal = player.get_raycast_wall_normal()
		if wall_normal != Vector2.ZERO:
			player.velocity.x = wall_normal.x * player.wall_jump_horizontal_force
			player.velocity.y = player.jump_velocity * player.wall_jump_vertical_force_multiplier
			player.jump_count = 1
			player.is_double_jumping_after_wall_jump = false
			player.animated_sprite.play("wall_jump")
			player.jump_buffer_timer = 0.0
			player.wall_jump_cooldown_timer = 0.1
		else:
			_perform_ground_jump()
	elif came_from_air_state:
		player.animated_sprite.play("jump")
	else:
		_perform_ground_jump()
	
	came_from_air_state = false

func _perform_ground_jump() -> void:
	player.velocity.y = player.jump_velocity
	player.jump_count = 1
	player.animated_sprite.play("jump")
	player.jump_buffer_timer = 0.0
	player.is_double_jumping_after_wall_jump = false

func process_physics(delta: float) -> void:
	if player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
		player.jump_buffer_timer = 0.0
		player.jump_count += 1
		
		if player.jump_count == player.max_jumps:
			player.set_can_ground_slam(true)

		var jump_force: float
		if player.is_double_jumping_after_wall_jump: 
			jump_force = player.jump_velocity * player.wall_jump_vertical_force_multiplier * player.wall_double_jump_multiplier
		else:
			jump_force = player.jump_velocity * double_jump_velocity_multiplier
		
		player.velocity.y = jump_force

		if player.player_effect_manager and player.player_effect_manager.has_method("play_double_jump"):
			player.player_effect_manager.play_double_jump(player.animated_sprite.flip_h)
		
		player.animated_sprite.play("jump") 

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

	if wall_slide_state and not player.is_on_floor() and player.velocity.y > 0 and player.wall_jump_cooldown_timer <= 0:
		var wall_normal = player.get_raycast_wall_normal()
		if wall_normal != Vector2.ZERO:
			state_machine._transition_to(wall_slide_state)
			return

	player.move_and_slide()

func get_transition() -> PlayerState:
	if player.velocity.y > 0:
		return fall_state


	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state

	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			return sa_state

	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null 
