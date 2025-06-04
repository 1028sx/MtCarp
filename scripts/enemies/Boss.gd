extends CharacterBody2D

class_name Boss

# Boss 相關信號
signal phase_changed(phase: int)
signal boss_defeated
signal attack_started(attack_name: String)
signal health_changed(current: float, max_health: float)

#region 導出屬性
@export_group("基本屬性")
@export var boss_name: String = "Boss"
@export var max_health: float = 1000.0
@export var defense: float = 10.0
@export var total_phases: int = 3
@export var knockback_resistance: float = 0.9

@export_group("移動與行為")
@export var move_speed: float = 120.0
@export var acceleration: float = 500.0
@export var deceleration: float = 800.0
@export var phase_transition_time: float = 2.0

@export_group("攻擊屬性")
@export var attack_cooldown: float = 2.0
@export var attack_damage: float = 15.0
@export var special_attack_cooldown: float = 8.0 
@export var special_attack_damage: float = 30.0
@export var attack_range: float = 150.0

@export_group("掉落物")
@export var guaranteed_drops: Array[String] = []
@export var random_drops: Array[String] = []
@export var drop_chance: float = 0.5
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var attack_area = $AttackArea
@onready var detection_area = $DetectionArea
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var special_attack_cooldown_timer = $"SpecialAttackCooldownTimer" if has_node("SpecialAttackCooldownTimer") else null
@onready var health_bar = $"BossHealthBar" if has_node("BossHealthBar") else null
@onready var effect_manager = $EffectManager
@onready var state_label = $StateLabel
@onready var touch_damage_area: Area2D = $TouchDamageArea
#endregion

#region 狀態變量
enum BossState {IDLE, APPEAR, PHASE_TRANSITION, MOVE, ATTACK, SPECIAL_ATTACK, STUNNED, HURT, DEFEATED, MAX_BOSS_STATES}

var current_state: int = BossState.IDLE
var previous_state: int = BossState.IDLE
var current_phase: int = 1
var current_health: float
var current_attack: String = ""
var attack_patterns: Dictionary = {}
var phase_attacks: Dictionary = {}
var vulnerable: bool = true
var target_player: CharacterBody2D = null
var active: bool = true

# 移動相關
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var move_direction: Vector2 = Vector2.ZERO
var target_position: Vector2
var knockback_velocity: Vector2 = Vector2.ZERO

# 攻擊模式
var available_attacks: Array = []
var current_attack_index: int = 0
var attack_combo_count: int = 0
var max_combo_attacks: int = 3

# 相位轉換
var transition_timer: float = 0.0
var can_be_interrupted: bool = true

# 調試用
var debug_mode: bool = false
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_boss()
	_setup_collisions()
	_connect_signals()
	_setup_attack_patterns()

	# Attempt to get player from PlayerGlobal on ready
	if PlayerGlobal and PlayerGlobal.is_player_available():
		target_player = PlayerGlobal.get_player()
		print_debug("[Boss._ready] Initial target_player set from PlayerGlobal: ", target_player.name if target_player else "null")
	# Connect to PlayerGlobal's signal to know when player registration changes
	if PlayerGlobal and not PlayerGlobal.player_registration_changed.is_connected(_on_player_registration_changed):
		PlayerGlobal.player_registration_changed.connect(_on_player_registration_changed)

	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_error("[Boss_ready] CRITICAL ERROR: animated_sprite node is not ready or not found in _ready!")
	
	if debug_mode and state_label:
		state_label.visible = true
	else:
		state_label.visible = false

func is_player_valid(p_player: Node) -> bool:
	# Now, just check if the provided node is the one registered in PlayerGlobal
	# and also ensure it's a valid instance (it might have been freed).
	if not PlayerGlobal:
		printerr("[Boss.is_player_valid] PlayerGlobal not available!")
		return false
	return p_player != null and is_instance_valid(p_player) and p_player == PlayerGlobal.get_player()

func _handle_vision_cone_detection(delta: float) -> void:
	pass # TODO: Implement vision cone logic if needed

func _physics_process(delta: float) -> void:
	if not active: return

	# Primary way to get player is now through PlayerGlobal, updated by _on_player_registration_changed
	# The fallback logic below can be significantly simplified or removed if PlayerGlobal is reliable.
	# For now, let's keep a simplified version that only tries if target_player is null AND PlayerGlobal has a player.

	if not is_instance_valid(target_player): # More robust check than just target_player == null
		if PlayerGlobal and PlayerGlobal.is_player_available():
			var player_from_global = PlayerGlobal.get_player()
			if is_instance_valid(player_from_global): # Double check validity
				target_player = player_from_global
				# print_debug("[Boss Fallback] Acquired player from PlayerGlobal: ", target_player.name)
		# else: # Player not available in PlayerGlobal either, or PlayerGlobal itself is missing.
			# if current_state != BossState.IDLE and current_state != BossState.APPEAR and current_state != BossState.DEFEATED:
				# No valid player, ensure we are in a state that doesn't require one (like IDLE)
				# _change_state(BossState.IDLE) # This might be too aggressive, handled by _on_player_registration_changed now
			# pass

	# Original fallback logic (commented out, can be removed later if PlayerGlobal proves robust)
	# if not is_player_valid(target_player) and current_state != BossState.APPEAR and current_state != BossState.DEFEATED and current_state != BossState.PHASE_TRANSITION: # Added PHASE_TRANSITION
	# 	var frame = Engine.get_physics_frames()
	# 	print_debug("[Boss Fallback@", frame, "] Attempting to find player. Current target_player is null: ", target_player == null, ", Current State: ", BossState.keys()[BossState.values().find(current_state)] if BossState.values().has(current_state) else current_state)
	# 	var potential_targets = get_tree().get_nodes_in_group("Player") # This is the part we want to replace mostly
	# 	if not potential_targets.is_empty():
	# 		print_debug("[Boss Fallback@", frame, "] Found potential targets: ", potential_targets.size())
	# 		var new_target = potential_targets[0] as CharacterBody2D # Assuming player is CharacterBody2D
	# 		# Check if new_target is valid using the Boss's own validation method
	# 		if is_player_valid(new_target): # is_player_valid will now use PlayerGlobal
	# 			target_player = new_target
	# 			print_debug("[Boss Fallback@", frame, "] Target acquired: ", target_player.name if target_player else "null")
	# 		else:
	# 			var nt_name = new_target.name if new_target else "null_node"
	# 			var nt_valid_instance = is_instance_valid(new_target) if new_target else "N/A"
	# 			var nt_in_group = new_target.is_in_group("Player") if new_target and nt_valid_instance else "N/A"
	# 			print_debug("[Boss Fallback@", frame, "] Potential target node '", nt_name, "' is NOT valid by Boss.is_player_valid(). InstanceValid: ", nt_valid_instance, ", InGroupPlayer: ", nt_in_group)
	# 	else:
	# 		print_debug("[Boss Fallback@", frame, "] No potential targets found in group 'Player'.")
	
	_handle_vision_cone_detection(delta)

	if current_state == BossState.DEFEATED:
		return
		
	if not is_on_floor() and current_state != BossState.APPEAR:
		velocity.y += gravity * delta
	
	# 狀態特定邏輯
		match current_state:
			BossState.IDLE:
				_process_idle_state(delta)
			BossState.APPEAR:
				_process_appear_state(delta)
			BossState.PHASE_TRANSITION:
				_process_phase_transition(delta)
			BossState.MOVE:
				_process_move_state(delta)
			BossState.HURT:
				_process_hurt_state(delta)
	
	# 更新動畫
	_update_animation()

	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 2000 * knockback_resistance)

	# 最終移動前打印速度
	print("[Boss _physics_process] Node: ", name, ", Velocity BEFORE move_and_slide: ", velocity)
	move_and_slide()
	
	if debug_mode and state_label:
		state_label.text = BossState.keys()[current_state] + " - Phase: " + str(current_phase)
#endregion

#region 初始化系統
func _initialize_boss() -> void:
	add_to_group("boss")
	current_health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = max_health
		health_bar.visible = true
	
	call_deferred("emit_signal", "health_changed", current_health, max_health)
	call_deferred("emit_signal", "phase_changed", current_phase)

func _setup_collisions() -> void:
	pass

func _connect_signals() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_area:
		if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)

	if touch_damage_area:
		if touch_damage_area.is_connected("body_entered", Callable(self, "_on_touch_damage_area_body_entered")):
			touch_damage_area.body_entered.disconnect(Callable(self, "_on_touch_damage_area_body_entered"))
		
		if touch_damage_area.is_connected("area_entered", Callable(self, "_on_touch_damage_area_area_entered_fixed")):
			touch_damage_area.area_entered.disconnect(Callable(self, "_on_touch_damage_area_area_entered_fixed"))

		if not touch_damage_area.is_connected("area_entered", Callable(self, "_on_touch_damage_area_entered")):
			touch_damage_area.area_entered.connect(Callable(self, "_on_touch_damage_area_entered"))

func _setup_attack_patterns() -> void:
	pass
#endregion

#region 狀態處理函數
func _process_idle_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
	
	if is_instance_valid(target_player):
		_change_state(BossState.MOVE)

func _process_appear_state(_delta: float) -> void:
	pass

func _process_phase_transition(_delta: float) -> void:
	velocity.x = 0
	transition_timer -= _delta
	
	if transition_timer <= 0:
		_change_state(BossState.MOVE)
		vulnerable = true

func _process_move_state(_delta: float) -> void:
	if not is_instance_valid(target_player):
		_change_state(BossState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	var direction_to_player = (target_player.global_position - global_position).normalized()
	
	if distance_to_player <= attack_range:
		if attack_cooldown_timer.is_stopped():
			_select_attack()
		else:
			velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed * 0.5, acceleration * _delta)
	else:
		velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed, acceleration * _delta)
	
	if velocity.x != 0:
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0

func _process_attack_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)

func _process_special_attack_state(_delta: float) -> void:
	if special_attack_cooldown_timer and special_attack_cooldown_timer.is_stopped():
		pass
	else:
		_change_state(BossState.IDLE)

func _process_hurt_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
#endregion

#region 攻擊系統
func _select_attack() -> void:
	if available_attacks.is_empty():
		return
	
	var phase_attack_list: Array
	if phase_attacks.has(current_phase):
		phase_attack_list = phase_attacks[current_phase]
	else:
		phase_attack_list = available_attacks
	
	if phase_attack_list.is_empty():
		return
	
	var attack_name = phase_attack_list[randi() % phase_attack_list.size()]
	current_attack = attack_name
	
	if attack_name.begins_with("special_"):
		_change_state(BossState.SPECIAL_ATTACK)
		special_attack_cooldown_timer.start(special_attack_cooldown)
	else:
		_change_state(BossState.ATTACK)
		attack_cooldown_timer.start(attack_cooldown)
	
	attack_started.emit(attack_name)

func _apply_attack_damage(body: Node2D, damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount, self)
	
	if knockback_force != Vector2.ZERO and body.has_method("apply_knockback"):
		body.apply_knockback(knockback_force)
#endregion

#region 受傷系統
func take_damage(damage_amount: float, attacker: Node = null) -> void:
	if current_state == BossState.DEFEATED or current_state == BossState.APPEAR or not vulnerable:
		return
	
	var actual_damage = max(1, damage_amount - defense)
	current_health -= actual_damage
	
	if health_bar:
		health_bar.value = current_health
	
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		_handle_defeat()
	elif current_health <= max_health / total_phases * (total_phases - current_phase):
		_enter_next_phase()
	elif can_be_interrupted:
		_change_state(BossState.HURT)
		
		if attacker != null and attacker is Node2D:
			var knockback_dir = (global_position - attacker.global_position).normalized()
			knockback_velocity = knockback_dir * 300 * (1.0 - knockback_resistance)

func _handle_defeat() -> void:
	current_health = 0
	_change_state(BossState.DEFEATED)
	boss_defeated.emit()
	
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	
func _enter_next_phase() -> void:
	current_phase += 1
	if current_phase > total_phases:
		current_phase = total_phases
	
	phase_changed.emit(current_phase)
	
	_change_state(BossState.PHASE_TRANSITION)
	transition_timer = phase_transition_time
	vulnerable = false

func _on_defeated() -> void:
	_drop_items()
	
	queue_free()
	
func _drop_items() -> void:
	for item_name in guaranteed_drops:
		_spawn_item(item_name)
	
	for item_name in random_drops:
		if randf() <= drop_chance:
			_spawn_item(item_name)

func _spawn_item(_item_name: String) -> void:
	pass
#endregion

#region 動畫系統
func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_animation = get_current_animation_name()
	if animated_sprite.animation != null:
		pass
	
	if current_state >= 0 and current_state < BossState.size():
		pass

	if animated_sprite.animation != new_animation and new_animation != "":
		animated_sprite.play(new_animation)
	elif animated_sprite.animation == new_animation and not animated_sprite.is_playing() and new_animation != "":
		animated_sprite.play(new_animation)

func get_current_animation_name() -> String:
	match current_state:
		BossState.IDLE:
			return "idle"
		BossState.MOVE:
			return "move"
		BossState.ATTACK:
			return current_attack if current_attack != "" else "attack" 
		BossState.SPECIAL_ATTACK:
			return current_attack if current_attack != "" else "special_attack"
		BossState.HURT:
			return "hurt"
		BossState.DEFEATED:
			return "defeat"
		BossState.APPEAR:
			return "appear"
		BossState.PHASE_TRANSITION:
			return "phase_transition"
		_:
			return "idle"

func _change_state(new_state: int) -> void:
	var old_state_name = "UNKNOWN_STATE"
	var old_state_idx = BossState.values().find(current_state)
	if old_state_idx != -1:
		old_state_name = BossState.keys()[old_state_idx]
	
	var new_state_name = "UNKNOWN_STATE"
	var new_state_idx = BossState.values().find(new_state)
	if new_state_idx != -1:
		new_state_name = BossState.keys()[new_state_idx]
	
	if old_state_name == new_state_name and current_state == new_state: 
		return 
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		BossState.APPEAR:
			vulnerable = false
		BossState.ATTACK, BossState.SPECIAL_ATTACK:
			can_be_interrupted = false
		BossState.HURT:
			can_be_interrupted = true
		BossState.PHASE_TRANSITION:
			vulnerable = false
			can_be_interrupted = false
	
	if new_state == BossState.DEFEATED:
		_update_animation()
	elif new_state == BossState.APPEAR:
		_update_animation()
#endregion

#region 信號回調
func _on_animation_finished() -> void:
	var anim_name = "null_anim_name_on_finish"
	if animated_sprite and animated_sprite.animation != null: 
		anim_name = animated_sprite.animation
	
	var current_state_val_on_finish = current_state
	if current_state_val_on_finish >= 0 and current_state_val_on_finish < BossState.size():
		pass
	
	match current_state_val_on_finish:
		BossState.APPEAR:
			if anim_name == "appear":
				vulnerable = true 
				_change_state(BossState.IDLE)
			else:
				vulnerable = true 
				_change_state(BossState.IDLE)
		BossState.ATTACK, BossState.SPECIAL_ATTACK:
			if attack_area:
				attack_area.monitoring = false
			_change_state(BossState.MOVE)
		BossState.HURT:
			_change_state(BossState.MOVE)
		BossState.DEFEATED:
			var death_anim_name = get_current_animation_name()
			if anim_name == death_anim_name:
				_on_defeated()

func _on_detection_area_body_entered(body: Node2D) -> void:
	# if body.is_in_group("player") and not target_player: # Old check
	if PlayerGlobal and PlayerGlobal.get_player() == body and not is_instance_valid(target_player):
		target_player = body as CharacterBody2D # Cast to be sure
		print_debug("[Boss _on_detection_area_body_entered] Player entered detection area. Target acquired: ", target_player.name if target_player else "null")
		if current_state >= 0 and current_state < BossState.size():
			pass
		if current_state == BossState.IDLE:
			_change_state(BossState.APPEAR) # Consider changing to MOVE if player is already there
	# elif body.is_in_group("player") and target_player: # Old check, if already has a target, this might be redundant if it's the same player
	elif PlayerGlobal and PlayerGlobal.get_player() == body and is_instance_valid(target_player):
		# Player is the same as current target, no action needed or maybe refresh something?
		if current_state >= 0 and current_state < BossState.size():
			pass

func _on_detection_area_body_exited(body: Node2D) -> void:
	# if body == target_player: # Old check
	if PlayerGlobal and PlayerGlobal.get_player() == body and body == target_player: # Ensure it's the correct player exiting
		target_player = null
		print_debug("[Boss _on_detection_area_body_exited] Player exited detection area. Target lost.")
		# Optionally, change state if the boss should stop attacking or moving
		# if current_state == BossState.MOVE or current_state == BossState.ATTACK:
		#     _change_state(BossState.IDLE)

func _on_attack_area_body_entered(body: Node2D) -> void:
	# if body.is_in_group("player"): # Old check
	if PlayerGlobal and PlayerGlobal.get_player() == body:
		var damage = attack_damage
		if current_state == BossState.SPECIAL_ATTACK:
			damage = special_attack_damage
		
		var knockback_dir = (body.global_position - global_position).normalized()
		var knockback_force = knockback_dir * 300
		
		_apply_attack_damage(body, damage, knockback_force)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(6): 
		pass

func _on_touch_damage_area_entered(area: Area2D) -> void:
	if current_state == BossState.DEFEATED:
		return

	if area.get_collision_layer_value(4):
		var player_node = area.owner
		if player_node and player_node is CharacterBody2D and player_node.has_method("take_damage"):
			var touch_damage_value = 5.0
			
			player_node.call("take_damage", touch_damage_value)

			var knockback_dir = (player_node.global_position - global_position).normalized()
			var knockback_force_on_player = knockback_dir * 100
			if player_node.has_method("apply_knockback_from_vector"):
				player_node.call("apply_knockback_from_vector", knockback_force_on_player)

		else:
			if not player_node:
				push_error("TouchDamageArea: PlayerHitbox (Area2D on Layer 4) does not have a valid 'owner' or owner is not a Node2D.")
			elif not player_node is CharacterBody2D:
				push_error("TouchDamageArea: Owner of PlayerHitbox is not a CharacterBody2D.")
			elif not player_node.has_method("take_damage"):
				push_error("TouchDamageArea: Player node does not have 'take_damage' method.")

func _on_touch_damage_area_body_entered(body: Node2D) -> void: 
	if current_state == BossState.DEFEATED:
		return

	if body.is_in_group("player"):
		var player_hitbox = null
		for child in body.get_children():
			if child is Area2D and child.get_collision_layer_value(4):
				player_hitbox = child
				break
		
		if player_hitbox:
			_on_touch_damage_area_entered(player_hitbox)
			return

		var touch_damage_value = 5.0 
		if body.has_method("take_damage"):
			body.call("take_damage", touch_damage_value)

			var knockback_dir = (body.global_position - global_position).normalized()
			var knockback_force_on_player = knockback_dir * 100
			if body.has_method("apply_knockback_from_vector"):
				body.call("apply_knockback_from_vector", knockback_force_on_player)

# Add a handler for PlayerGlobal's signal
func _on_player_registration_changed(is_registered: bool) -> void:
	print_debug("[Boss._on_player_registration_changed] Player registration changed. Registered: ", is_registered)
	if is_registered:
		target_player = PlayerGlobal.get_player()
		print_debug("[Boss] Target player updated from PlayerGlobal: ", target_player.name if target_player else "null")
		# If boss was IDLE because no target, maybe trigger state change
		if current_state == BossState.IDLE and is_instance_valid(target_player):
			_change_state(BossState.MOVE) # Or APPEAR, depending on logic
	else:
		target_player = null
		print_debug("[Boss] Target player set to null due to unregistration.")
		# If boss was targeting player, might need to go to IDLE
		# This depends on how you want the boss to react when player disappears
		# For example, if in MOVE or ATTACK state, go to IDLE.
		if current_state == BossState.MOVE or current_state == BossState.ATTACK or current_state == BossState.SPECIAL_ATTACK:
			_change_state(BossState.IDLE)
#endregion 
