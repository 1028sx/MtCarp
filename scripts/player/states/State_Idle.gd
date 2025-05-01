# scripts/player/states/State_Idle.gd
class_name State_Idle
extends PlayerState

@export var move_state: PlayerState
@export var jump_state: PlayerState
@export var fall_state: PlayerState
@export var attack_state: PlayerState
@export var special_attack_state: PlayerState
@export var dash_state: PlayerState

func enter() -> void:
	if player and player.animated_sprite:
		player.animated_sprite.play("idle")
	else:
		push_error("State_Idle 無法播放 idle 動畫：player 或 animated_sprite 為 Nil")

func process_physics(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	
	player.move_and_slide()

func get_transition() -> PlayerState:
	if not player.is_on_floor() and player.velocity.y > 0:
		return fall_state
	
	if Input.is_action_just_pressed("jump"):
		print("[Idle -> Jump] Condition met")
		return jump_state
	
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		print("[Idle -> Move] Condition met")
		return move_state

	if Input.is_action_just_pressed("attack") and attack_state:
		print("[Idle -> Attack] Condition met")
		return attack_state

	if Input.is_action_just_pressed("special_attack") and player.can_special_attack:
		var sa_state = state_machine.states.get("specialattack")
		if sa_state:
			print("[Idle -> SpecialAttack] Condition met")
			return sa_state
		else:
			printerr("特殊攻擊狀態節點 (specialattack) 未在狀態機中找到！")

	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		print("[Idle -> Dash] Condition met")
		return dash_state

	return null 
