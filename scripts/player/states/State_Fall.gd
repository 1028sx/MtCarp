class_name state_fall
extends PlayerState

@export var idle_state: PlayerState
@export var jump_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState
@export var wall_slide_state: PlayerState
@export var air_control_factor: float = 0.8

func enter() -> void:
	player.animated_sprite.play("jump")

func process_physics(delta: float) -> void:

	player.velocity.y += player.gravity * delta * 0.7

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

	if wall_slide_state and not player.is_on_floor() and player.wall_jump_cooldown_timer <= 0:
		var wall_normal = player.get_raycast_wall_normal()
		if wall_normal != Vector2.ZERO:
			state_machine._transition_to(wall_slide_state)
			return

	player.move_and_slide()

func get_transition() -> PlayerState:
	if player.is_on_floor():
		return idle_state

	if player.jump_buffer_timer > 0 and player.jump_count < player.max_jumps:
		if jump_state is state_jump:
			(jump_state as state_jump).came_from_air_state = true
		
		return jump_state
	
	if Input.is_action_pressed("attack") and attack_state:
		return attack_state
	
	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			return sa_state

	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null 
