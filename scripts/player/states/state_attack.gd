class_name state_attack
extends PlayerState

@export var idle_state: PlayerState
@export var fall_state: PlayerState
@export var move_state: PlayerState 
@export var jump_state: PlayerState 
@export var dash_state: PlayerState 

var is_dash_attack := false
var animation_finished := false

func _play_combo_animation() -> void:
	var attack_num = player.current_attack_combo + 1
	
	var speed_multiplier = 1.0
	
	if player.active_effects.has("agile_dash") and player.agile_dash_attack_count > 0:
		speed_multiplier *= player.agile_dash_attack_speed_bonus
		

	player.animated_sprite.play("attack" + str(attack_num))
	player.animated_sprite.speed_scale = speed_multiplier
	
	
	var mouse_pos = player.get_global_mouse_position()
	var direction_to_mouse = (mouse_pos - player.global_position).normalized()
	var flip = direction_to_mouse.x < 0
	player.animated_sprite.flip_h = flip
	if player.attack_area:
		player.attack_area.scale.x = -1 if flip else 1
	if player.special_attack_area:
		player.special_attack_area.scale.x = -1 if flip else 1
	animation_finished = false 
	player.hit_enemies.clear()
	if player.attack_area:
		player.attack_area.monitoring = true

func enter() -> void:
	if player.attack_area:
		player.attack_area.damage = 0.0
		player.attack_area.monitoring = false
	 
	if is_dash_attack:
		player.current_attack_combo = 0
	else:
		if player.can_continue_combo and player.combo_buffer_timer > 0:
			if player.current_attack_combo < 2:
				player.current_attack_combo += 1
			else:
				player.current_attack_combo = 0
		else:
			player.current_attack_combo = 0
		
		player.can_continue_combo = false
		player.combo_buffer_timer = 0.0
	 
	_play_combo_animation() 

	if is_dash_attack:
		player.is_in_dash_attack_recovery = true
		player.dash_attack_recovery_timer = player.dash_attack_recovery_time
	else:
		if player.current_attack_combo == 0 and player.active_effects.has("agile") and player.agile_perfect_dodge:
			player.agile_perfect_dodge = false
		
		if player.charge_damage_multiplier > 1.0:
			pass

func process_physics(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	var move_speed = player.speed * player.attack_move_speed_multiplier
	
	if player.is_on_floor():
		player.velocity.x = direction * move_speed
	else:
		var air_control_speed = player.speed * player.attack_move_speed_multiplier * 0.8
		if direction:
			player.velocity.x = direction * air_control_speed
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, air_control_speed)

	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta

	player.move_and_slide()

func get_transition() -> PlayerState:
	# 優先處理跳躍中斷
	if Input.is_action_just_pressed("jump") and jump_state:
		# 檢查玩家是否可以跳躍 (在地面上，或者還有剩餘跳躍次數)
		# 這裡我們假設 player.gd 中有 jump_buffer_timer 來處理跳躍緩衝
		# 並且 player.gd 的 _physics_process 或相關狀態會處理 jump_count
		if player.is_on_floor() or player.jump_count < player.max_jumps or player.jump_buffer_timer > 0:
			return jump_state

	if animation_finished:
		if Input.is_action_pressed("attack"):
			if player.current_attack_combo < 2:
				player.current_attack_combo += 1
				_play_combo_animation() 
				player.can_continue_combo = false 
				player.combo_buffer_timer = 0.0
				return null 
			else: 
				player.current_attack_combo = 0 
				_play_combo_animation() 
				player.can_continue_combo = false 
				player.combo_buffer_timer = 0.0
				return null 
		else:
			return fall_state if not player.is_on_floor() else idle_state

	if Input.is_action_just_pressed("dash") and dash_state and player.can_dash and player.dash_cooldown_timer <= 0:
		return dash_state

	return null

func on_animation_finished(anim_name: String) -> void:
	if anim_name.begins_with("attack") or anim_name == "charge_attack":
		animation_finished = true
		player.can_continue_combo = true
		player.combo_buffer_timer = player.combo_buffer_time

func on_frame_changed(frame: int) -> void:
	if player.animated_sprite.animation.begins_with("attack") and frame == 2:
		_apply_attack_damage()

func exit() -> void:
	if player.attack_area:
		player.attack_area.monitoring = false
		player.attack_area.damage = 0.0
	player.animated_sprite.speed_scale = 1.0
	is_dash_attack = false
	
	if player.charge_damage_multiplier > 1.0:
		player.reset_charge_state()
	
	player.current_attack_combo = 0
	player.can_continue_combo = false
	player.combo_buffer_timer = 0.0
	animation_finished = false
	pass
 
func _apply_attack_damage() -> void:
	if not player.attack_area:
		return
		
	var areas = player.attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		
		if body.is_in_group("enemy") and body.has_method("take_damage") and not player.hit_enemies.has(body):
			player.hit_enemies.append(body)
			
			var base_dmg = player.base_attack_damage
			var multiplier = 1.0
			
			if is_dash_attack:
				multiplier *= 1.5
			if player.charge_damage_multiplier > 1.0:
				multiplier *= player.charge_damage_multiplier
			if player.active_effects.has("berserker"):
				multiplier *= player.get_berserker_multiplier()
			if player.active_effects.has("agile") and player.agile_perfect_dodge:
				multiplier *= player.agile_damage_multiplier
			if player.active_effects.has("focus") and player.focus_target == body:
				multiplier *= (1.0 + player.focus_stack * player.focus_damage_bonus)
			
			var damage = base_dmg * multiplier
			
			var knockback_force = player.get_knockback_force()
			var knockback_direction = player.get_knockback_direction()
			
			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_direction * knockback_force)
			
			if body.is_in_group("boss"):
				body.take_damage(damage, player)
			else:
				body.take_damage(damage, player)
			
			if player.active_effects.has("life_steal"):
				player.current_health = min(player.current_health + 2, player.max_health)
				player.health_changed.emit(player.current_health)
				
			if player.active_effects.has("focus"):
				if player.focus_target != body:
					player.focus_stack = 1
					player.focus_target = body
				else:
					player.focus_stack = min(player.focus_stack + 1, player.focus_stack_limit)
				player.focus_reset_timer = player.focus_reset_time
