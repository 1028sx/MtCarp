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
	var current_speed = player.speed


	if direction:
		player.velocity.x = direction * current_speed
		player.animated_sprite.flip_h = direction < 0
		if player.attack_area:
			player.attack_area.scale.x = -1 if direction < 0 else 1
		if player.special_attack_area:
			player.special_attack_area.scale.x = -1 if direction < 0 else 1
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	
	player.move_and_slide()

func get_transition() -> PlayerState:
	if not player.is_on_floor() and player.velocity.y > 0.1:
		return fall_state
	
	if Input.is_action_just_pressed("jump"):
		return jump_state
	
	var direction = Input.get_axis("move_left", "move_right")
	if direction == 0:
		return idle_state

	if Input.is_action_just_pressed("attack") and attack_state:
		return attack_state

	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			return sa_state


	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null
