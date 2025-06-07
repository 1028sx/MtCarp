extends CharacterBody2D

# Preload the PlayerGlobal script resource to call static functions from the type
const PlayerGlobalScript = preload("res://scripts/globals/PlayerGlobal.gd")

#region 常量定義
const NORMAL_TIME_SCALE = 1.0
const CAMERA_MODE_TIME_SCALE = 0.1
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0
const ZOOM_STEP = 0.01
const ZOOM_DURATION = 0.05
const BLINK_INTERVAL = 0.1
const JUMP_VELOCITY = -450.0
const CHARGE_EFFECT_INTERVAL = 2.0
#endregion

#region 導出屬性
@export_group("Movement")
@export var speed = 200.0
@export var jump_velocity = -450.0
@export var max_jumps = 2
@export var jump_buffer_time = 0.2
@export var coyote_time = 0.1

@export_group("Dash")
@export var dash_speed = 250.0
@export var dash_duration = 0.3
@export var dash_cooldown = 0.7
@export var dash_attack_recovery_time = 0.2

@export_group("Combat")
@export var max_health = 100
@export var defense_duration = 0.5
@export var defense_cooldown = 1.0
@export var defense_strength = 0.5
@export var invincible_duration = 0.5

@export_group("Attack")
@export var attack_move_speed_multiplier = 0.1
@export var attack_combo_window = 0.5
@export var attack_hold_threshold = 0.15
@export var combo_buffer_time = 0.3

@export_group("Special Attack")
@export var special_attack_velocity = -400
@export var special_attack_cooldown = 1.0

@export_group("Wall Jump")
@export var wall_slide_speed: float = 100.0
@export var wall_jump_horizontal_force: float = 300.0
@export var wall_jump_vertical_force_multiplier: float = 0.6
@export var wall_double_jump_multiplier: float = 0.8
#endregion

#region 節點引用
@onready var animated_sprite = $AniSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_area = $AttackArea
@onready var effect_manager = $EffectManager
@onready var special_attack_area = $SpecialAttackArea
@onready var camera = $Camera2D
@onready var state_machine = $StateMachine
@onready var metsys_node = $MetroidvaniaSystem
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var ground_slam_area: Area2D

var shuriken_scene = preload("res://scenes/player/shuriken.tscn")
var wave_scene = preload("res://scenes/player/dash_wave.tscn")
#endregion

#region 狀態變量
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_health = max_health
var jump_count := 0
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var was_on_floor := false
var can_dash := true
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_attack_recovery_timer := 0.0
var is_in_dash_attack_recovery := false
var dash_direction := 1
var current_attack_combo := 0
var can_continue_combo := false
var combo_buffer_timer := 0.0
var hit_enemies: Array = []
var last_special_attack_frame := -1
var special_attack_timer := 0.0
var can_special_attack := true
var is_invincible := false
var invincible_timer := 0.0
var blink_timer := 0.0

var is_camera_mode := false
var camera_move_speed := 500.0
var default_camera_zoom := Vector2(1.2, 1.2)
var camera_mode_zoom := Vector2(1, 1)
var camera_zoom_duration := 0.5
var camera_zoom_tween: Tween
var previous_zoom := Vector2(1.2, 1.2)

var blink_colors := [Color(1, 1, 1, 0.7), Color(1, 0.5, 0.5, 0.7)]
var current_blink_color := 0

var has_revive_heart := true

var gold := 0

var active_effects := {}

var knockback_velocity := Vector2.ZERO

var has_dash_wave := false

var is_charging := false
var charge_time := 0.0
var max_charge_bonus := 1.0
var current_charge_rate := 0.15
var charge_damage_multiplier := 1.0
var charge_start_timer := 0.0
var is_charge_ready := false
var saved_charge_multiplier := 1.0

var base_attack_damage := 50.0
var base_special_attack_damage := 30.0
var current_attack_damage: float
var current_special_attack_damage: float

var swift_dash_multiplier := 1.25
var swift_dash_cooldown_reduction := 0.5
var swift_dash_attack_count := 0
var swift_dash_attack_limit := 3
var swift_dash_attack_speed_bonus := 1.5

var agile_dash_attack_count := 0
var agile_dash_attack_limit := 3
var agile_dash_attack_speed_bonus := 2.0

var rage_stack := 0
var rage_stack_limit := 5
var rage_damage_bonus := 0.1

var wall_jump_cooldown_timer := 0.0

var can_perform_ground_slam := false
const GROUND_SLAM_SPEED := 600.0
const GROUND_SLAM_DAMAGE_MULTIPLIER := 3.0
const GROUND_SLAM_KNOCKBACK_FORCE := 150.0

signal health_changed(new_health: int)
signal gold_changed(new_gold: int)

# warning-ignore:unused_signal
signal effect_changed(effects: Dictionary)
signal player_fully_died

var agile_perfect_dodge := false
var agile_dodge_window := 0.2
var agile_dodge_timer := 0.0
var agile_damage_multiplier := 2.0

var focus_stack := 0
var focus_stack_limit := 5
var focus_damage_bonus := 0.05
var focus_target: Node = null
var focus_reset_timer := 0.0
var focus_reset_time := 10.0

var charge_effect_timer := 0.0
var has_played_max_charge_effect := false
var has_played_first_effect := false
var has_played_second_effect := false
var has_ice_freeze := false
var ice_freeze_cooldown := 5.0
var ice_freeze_timer := 0.0
var ice_freeze_duration := 2.0

var is_wall_sliding := false
var last_jump_was_wall_jump := false
var is_double_jumping_after_wall_jump := false
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_player()
	_setup_collisions()
	_connect_signals()
	_connect_death_state_signal()
	current_attack_damage = base_attack_damage
	current_special_attack_damage = base_special_attack_damage
	active_effects = {}
	# emit_signal("effect_changed", active_effects) # 改用以下更直接的方式
	effect_changed.emit(active_effects)

	# Register with PlayerGlobal
	if PlayerGlobal: # Autoload PlayerGlobal 自身
		PlayerGlobal.register_player(self)

func _physics_process(delta: float) -> void:
	if _handle_camera_mode(delta):
		return
		
	_update_global_timers(delta)

	if state_machine and state_machine.current_state: 
		state_machine._physics_process(delta)
	else:
		printerr("[Player] Error: Invalid State Machine or Current State in _physics_process!")

	_handle_ground_slam_input()

	var current_on_floor = is_on_floor()
	if current_on_floor and not was_on_floor:
		_on_landed()
	was_on_floor = current_on_floor

	if metsys_node:
		metsys_node.set_player_position(global_position)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if is_camera_mode and event is InputEventMouseButton:
		_handle_camera_zoom(event)
		return
	
	if state_machine and state_machine.current_state:
		state_machine._input(event)

func _tree_exiting() -> void:
	# Unregister from PlayerGlobal when the player is removed from the scene tree
	# if PlayerGlobal and PlayerGlobal.get_player() == self: # 原來的調用方式
	if PlayerGlobal and PlayerGlobalScript.get_player() == self: # 修改後的調用方式
		PlayerGlobal.unregister_player()

#endregion

#region 初始化系統
func _initialize_player() -> void:
	add_to_group("player")
	current_health = max_health
	gold = 0

func _setup_collisions() -> void:
	# set_collision_layer_value(2, true)  # Player layer
	# set_collision_mask_value(1, true)   # Detect Environment
	
	# var hitbox = $Hitbox
	# if hitbox:
		# hitbox.set_collision_layer_value(3, true) # PlayerHitbox layer (assuming layer 3 is PlayerHitbox)
		# hitbox.set_collision_mask_value(4, true)  # Detect EnemyAttack layer (assuming layer 4 is EnemyAttack)
	
	# if attack_area:
		# attack_area.set_collision_layer_value(4, true) # PlayerAttack layer (assuming layer 4 is PlayerAttack)
		# attack_area.set_collision_mask_value(3, true)  # Detect EnemyHitbox layer (assuming layer 3 is EnemyHitbox)

	# if special_attack_area:
		# special_attack_area.collision_layer = 0
		# special_attack_area.collision_mask = 0
		
		# special_attack_area.set_collision_layer_value(4, true) # PlayerAttack layer
		# special_attack_area.set_collision_mask_value(3, true)  # Detect EnemyHitbox layer
		
		# # 確保特殊攻擊區域預設為禁用狀態
		# special_attack_area.monitoring = false
		# special_attack_area.monitorable = false
	
	# ground_slam_area = $GroundSlamArea
	# if ground_slam_area:
		# ground_slam_area.monitoring = false
		# ground_slam_area.monitorable = false
	pass # 保留函數定義，但內容被註解掉

func _connect_signals() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_ani_sprite_2d_animation_finished):
			animated_sprite.animation_finished.connect(_on_ani_sprite_2d_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_ani_sprite_2d_frame_changed):
			animated_sprite.frame_changed.connect(_on_ani_sprite_2d_frame_changed)
	
	var hitbox = $Hitbox
	if hitbox and not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if effect_manager and not effect_manager.effect_finished.is_connected(_on_effect_finished):
		effect_manager.effect_finished.connect(_on_effect_finished)

func _connect_death_state_signal():
	# 使用 call_deferred 確保狀態機和狀態節點已準備好
	call_deferred("_deferred_connect_death_state_signal")

func _deferred_connect_death_state_signal():
	if state_machine and state_machine.states.has("dead"):
		var dead_state = state_machine.states.get("dead") # 使用 .get() 更安全
		if is_instance_valid(dead_state): # 檢查實例是否有效
			if not dead_state.death_animation_truly_finished.is_connected(_on_death_animation_truly_finished):
				var error_code = dead_state.death_animation_truly_finished.connect(_on_death_animation_truly_finished)
				if error_code != OK:
					printerr("[Player] Failed to connect to State_Dead.death_animation_truly_finished. Error: ", error_code)
				else:
					print_debug("[Player] Successfully connected to State_Dead.death_animation_truly_finished.")
		else:
			printerr("[Player] 'dead' state instance is invalid in _deferred_connect_death_state_signal.")
	else:
		printerr("[Player] Could not find 'dead' state in StateMachine to connect signal in _deferred_connect_death_state_signal.")

func _on_death_animation_truly_finished():
	# 這是 State_Dead 動畫播放完畢後的回調
	print_debug("[Player] Death animation truly finished (received from State_Dead). Emitting player_fully_died.")
	player_fully_died.emit()

#endregion

#region 相機系統
func _handle_camera_mode(delta: float) -> bool:
	if Input.is_action_just_pressed("camera_mode"):
		is_camera_mode = !is_camera_mode
		if is_camera_mode:
			velocity = Vector2.ZERO
			previous_zoom = camera.zoom
			_zoom_camera(camera_mode_zoom)
			Engine.time_scale = CAMERA_MODE_TIME_SCALE
		else:
			camera.position = Vector2.ZERO
			_zoom_camera(previous_zoom)
			Engine.time_scale = NORMAL_TIME_SCALE
	
	if is_camera_mode:
		_handle_camera_movement(delta)
		return true
	return false

func _handle_camera_movement(delta: float) -> void:
	var camera_movement = Vector2.ZERO
	
	if Input.is_action_pressed("jump"):
		camera_movement.y -= 1
	if Input.is_action_pressed("dash"):
		camera_movement.y += 1
	if Input.is_action_pressed("move_left"):
		camera_movement.x -= 1
	if Input.is_action_pressed("move_right"):
		camera_movement.x += 1
	
	if camera_movement != Vector2.ZERO:
		camera_movement = camera_movement.normalized()
		var real_delta = delta / Engine.time_scale
		camera.position += camera_movement * camera_move_speed * real_delta

func _handle_camera_zoom(event: InputEventMouseButton) -> void:
	var actual_zoom_step = ZOOM_STEP / Engine.time_scale
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_zoom(actual_zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_zoom(-actual_zoom_step)

func _zoom_camera(target_zoom: Vector2, force_immediate: bool = false) -> void:
	if camera_zoom_tween and camera_zoom_tween.is_valid():
		if force_immediate:
			camera.zoom = target_zoom
		camera_zoom_tween.kill()
	
	camera_zoom_tween = create_tween()
	camera_zoom_tween.set_trans(Tween.TRANS_SINE)
	camera_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	camera_zoom_tween.set_parallel(true)
	
	camera_zoom_tween.tween_property(
		camera,
		"zoom",
		target_zoom,
		ZOOM_DURATION
	)

func _adjust_camera_zoom(delta_zoom: float) -> void:
	if not camera:
		return
	
	var new_zoom = clamp(
		camera.zoom.x + delta_zoom,
		MIN_ZOOM,
		MAX_ZOOM
	)
	
	_zoom_camera(Vector2(new_zoom, new_zoom), true)
#endregion

#region 戰鬥系統 (受傷和死亡)
func take_damage(amount: float, attacker: Node = null) -> void:
	print("--------------------------------------------------")
	print("[Player_take_damage] CALLED!")
	print("- Timestamp: ", Time.get_ticks_msec())
	print("- Damage Amount: ", amount)
	if attacker:
		print("- Attacker Name: ", attacker.name)
		print("- Attacker Path: ", attacker.get_path())
		print("- Attacker Type: ", attacker.get_class())
		if attacker.owner and attacker.owner != attacker: # 避免重複打印自身
			print("- Attacker Owner Name: ", attacker.owner.name)
			print("- Attacker Owner Path: ", attacker.owner.get_path())
			print("- Attacker Owner Type: ", attacker.owner.get_class())
		print("- Attacker Global Position: ", str(attacker.global_position) if attacker is Node2D else "N/A (Attacker not Node2D)")
		print("- Player Global Position: ", global_position)
		print("- Distance to Attacker: ", str(global_position.distance_to(attacker.global_position)) if attacker is Node2D else "N/A")
	else:
		print("- Attacker: null (Damage might be environmental or self-inflicted)")
	print("- Current Player State: ", String(state_machine.current_state.name) if state_machine and state_machine.current_state else "N/A")
	print("- Is Invincible Flag: ", is_invincible)
	print("- Is Dashing (State Check): ", str(state_machine.current_state is State_Dash) if state_machine and state_machine.current_state else "N/A")
	print("--------------------------------------------------")

	# 1. Check for full invincibility (Dash or general invincible flag)
	if is_invincible or (state_machine and state_machine.current_state is State_Dash):
		print("[Player_take_damage] Damage ignored due to invincibility or Dash state.")
		return # No damage, no effects, no interruption
		
	# 2. Apply damage
	var previous_health = current_health
	current_health -= amount
	print("[Player_take_damage] Health changed from %s to %s (Damage: %s)" % [previous_health, current_health, amount])
	
	# 3. Emit health signal
	health_changed.emit(current_health)
	
	# 4. Apply unconditional on-hit effects (apply regardless of interruption)
	# Example: Thorns damage back to attacker
	if active_effects.has("thorns") and attacker != null:
		var real_attacker = attacker
		if attacker.has_method("get_shooter"):
			real_attacker = attacker.get_shooter()
		if real_attacker != null and real_attacker.has_method("take_damage"):
			# 注意：避免無限遞迴，Thorns 傷害不應觸發 Thorns
			# 可以傳遞一個標誌，或者確保 Thorns 傷害源不同
			print("[Player_take_damage] Applying Thorns damage back.")
			real_attacker.call("take_damage", amount * 5.0) # 假設傷害倍數是 5.0
	
	# Example: Gain Rage stack on taking damage
	if active_effects.has("rage") and rage_stack < rage_stack_limit:
		rage_stack += 1
		_update_rage_damage()
		print("[Player_take_damage] Rage stack increased to: %s" % rage_stack)

	# 5. Check for death
	if current_health <= 0:
		if has_revive_heart:
			has_revive_heart = false
			current_health = float(max_health) / 2.0 # Restore half health
			health_changed.emit(current_health)
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("use_revive_heart"):
				ui.use_revive_heart()
			set_invincible(2.0) # Grant invincibility after revive
			print("[Player_take_damage] Player Revived! Granted 2s invincibility.")
			# Consider transitioning to a specific state after revive if needed
			# if state_machine and state_machine.states.has("idle"):
			# state_machine._transition_to(state_machine.states["idle"])
		else:
			# Actual Death
			print("[Player_take_damage] Player Died! Initiating death state.")
			set_physics_process(false) # Stop player physics
			set_process_input(false) # Stop player input
			
			# Transition to death state
			if state_machine and state_machine.states.has("dead"):
				state_machine._transition_to(state_machine.states["dead"])
			else:
				printerr("[Player_take_damage] Error: 'dead' state not found in StateMachine!")
				# If no death state, we might need to manually emit the fully_died signal here
				# as a fallback, or consider this a critical error.
				# For now, assume death state handles emitting via its animation.
				# If State_Dead might not exist or its animation signal might not fire,
				# emitting here would be a backup.
				# player_fully_died.emit() # Fallback if no proper death state path
				if animated_sprite: 
					animated_sprite.stop() # Stop animation if no death state
			
			# died.emit() # Signal that player died <--- REMOVED/COMMENTED OUT
			# The 'player_fully_died' signal will be emitted by _on_death_animation_truly_finished
			# after the State_Dead has confirmed its animation is complete.
		return # Stop further processing after death/revive

	# 6. Handle interruption vs Super Armor (only if not dead and not invincible/dashing)
	var has_super_armor = false
	# 檢查當前狀態是否提供霸體 (目前只有 SpecialAttack)
	if state_machine and state_machine.current_state is State_Special_Attack:
		has_super_armor = true

	if not has_super_armor:
		# --- Interruption Logic --- (沒有霸體，正常受傷反應)
		print("[Player_take_damage] Interrupted (No Super Armor)!")

		# 重置連擊 (如果需要)
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager and game_manager.has_method("reset_combo"): # Assuming GameManager handles combo
			game_manager.reset_combo() 

		# 轉換到 Hurt 狀態
		if state_machine and state_machine.states.has("hurt"):
			state_machine._transition_to(state_machine.states["hurt"])
		else:
			printerr("[Player_take_damage] Hurt state not found!")
			
		set_invincible(invincible_duration) # 賦予玩家受傷後的無敵時間
		
		# 重置因被打斷而應取消的狀態或能力
		print("[Player_take_damage] Attempting to reset can_perform_ground_slam. Current value:", can_perform_ground_slam)
		last_jump_was_wall_jump = false
		is_double_jumping_after_wall_jump = false
		set_can_ground_slam(false) # 只有在被打斷時才取消地面衝擊能力
		reset_charge_state() # 只有在被打斷時才取消蓄力
	else:
		# --- Super Armor Logic --- (有霸體)
		print("[Player_take_damage] Super Armor absorbed interruption!")
		# 不轉換到 Hurt 狀態
		# 不重置 can_perform_ground_slam
		# 不重置 charge_state
		# 不重置 combo (取決於你的設計，但通常霸體不重置連擊)

func set_invincible(duration: float) -> void:
	if duration > 0:
		is_invincible = true
		invincible_timer = duration
		modulate.a = 0.5
	else:
		is_invincible = false
		invincible_timer = 0
		modulate.a = 1.0

func _handle_invincibility(delta: float) -> void:
	if is_invincible:
		invincible_timer -= delta
		blink_timer += delta
		if blink_timer >= BLINK_INTERVAL:
			blink_timer = 0.0
			modulate.a = 1.0 if modulate.a < 1.0 else 0.5
		
		if invincible_timer <= 0:
			set_invincible(0)
#endregion

#region 信號處理
func _on_ani_sprite_2d_animation_finished() -> void:
	if state_machine and state_machine.current_state and state_machine.current_state.has_method("on_animation_finished"):
		state_machine.current_state.on_animation_finished(animated_sprite.animation)

func _on_ani_sprite_2d_frame_changed() -> void:
	if state_machine and state_machine.current_state and state_machine.current_state.has_method("on_frame_changed"):
		state_machine.current_state.on_frame_changed(animated_sprite.frame)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_invincible or (state_machine and state_machine.current_state is State_Dash):
		return
		
	if area.get_parent().is_in_group("enemy"):
		var enemy = area.get_parent()
		var damage_amount = enemy.damage if "damage" in enemy else 10
		take_damage(damage_amount, enemy)

func _on_effect_finished() -> void:
	pass
#endregion

#region 輔助函數
func _update_global_timers(delta: float) -> void:
	_update_cooldowns(delta)
	_handle_invincibility(delta)

	if is_in_dash_attack_recovery:
		dash_attack_recovery_timer -= delta
		if dash_attack_recovery_timer <= 0:
			is_in_dash_attack_recovery = false

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if wall_jump_cooldown_timer > 0:
		wall_jump_cooldown_timer -= delta

	if agile_dodge_timer > 0:
		agile_dodge_timer -= delta
		if agile_dodge_timer <= 0:
			agile_perfect_dodge = false

	if focus_target and focus_reset_timer > 0:
		focus_reset_timer -= delta
		if focus_reset_timer <= 0:
			_reset_focus()
			
	if ice_freeze_timer > 0:
		ice_freeze_timer -= delta

func _update_cooldowns(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true
	
	if special_attack_timer > 0:
		special_attack_timer -= delta
		if special_attack_timer <= 0:
			can_special_attack = true

func _on_landed() -> void:
	print("[Player_on_landed] Attempting to reset can_perform_ground_slam. Current value:", can_perform_ground_slam)
	jump_count = 0
	coyote_timer = coyote_time
	last_jump_was_wall_jump = false
	is_double_jumping_after_wall_jump = false
	set_can_ground_slam(false)

func get_knockback_force() -> float:
	var force = 100.0
	match current_attack_combo:
		1: force = 120.0
		2: force = 150.0
	return force

func get_knockback_direction() -> Vector2:
	return Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT

func _reset_focus() -> void:
	if focus_stack > 0:
		focus_stack = 0
		focus_target = null
		focus_reset_timer = 0.0

func reset_charge_state() -> void:
	if is_charging or charge_damage_multiplier > 1.0:
		is_charging = false
		charge_time = 0.0
		charge_damage_multiplier = 1.0
		has_played_first_effect = false
		has_played_second_effect = false
		has_played_max_charge_effect = false
		if effect_manager:
			effect_manager.stop_charge_effect()

func get_raycast_wall_normal() -> Vector2:
	if not is_node_ready() or not wall_check_left or not wall_check_right:
		return Vector2.ZERO

	wall_check_left.force_raycast_update()
	wall_check_right.force_raycast_update()

	if wall_check_left.is_colliding():
		return Vector2.RIGHT
	elif wall_check_right.is_colliding():
		return Vector2.LEFT

	return Vector2.ZERO

#endregion

#region 金幣系統
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
#endregion

#region 效果系統
func apply_effect(effect: Dictionary) -> void:
	if not effect.has("effect"):
		return
	
	var effect_type = effect.effect
	var previous_effects_count = active_effects.size()
	
	match effect_type:
		"life_steal":
			active_effects["life_steal"] = true
			max_health *= 0.5
			current_health *= 0.5
			health_changed.emit(current_health)
			
		"multi_strike":
			active_effects["multi_strike"] = true
			
		"berserker":
			active_effects["berserker"] = true
			health_changed.emit(current_health)
			
		"dash_wave":
			active_effects["dash_wave"] = true
			has_dash_wave = true
			
		"charge_attack_movement":
			active_effects["charge_attack_movement"] = true
			max_charge_bonus = effect.max_charge_bonus
			current_charge_rate = effect.charge_rate
			enable_charge_attack(effect.max_charge_bonus, effect.charge_rate)
			
		"thorns":
			active_effects["thorns"] = true
			current_attack_damage *= 0.5
			current_special_attack_damage *= 0.5
			max_health *= 3
			var new_health = current_health *2
			current_health = new_health
			health_changed.emit(current_health)
			
		"swift_dash":
			if not active_effects.has("swift_dash"):
				active_effects["swift_dash"] = true
				apply_swift_dash()
			
		"agile_dash":
			if not active_effects.has("agile_dash"):
				active_effects["agile_dash"] = true
				agile_dash_attack_count = agile_dash_attack_limit

		"rage":
			if not active_effects.has("rage"):
				active_effects["rage"] = true
				rage_stack = 0

		"agile":
			if not active_effects.has("agile"):
				active_effects["agile"] = true

		"focus":
			if not active_effects.has("focus"):
				active_effects["focus"] = true
				_reset_focus()

		"harvest":
			if not active_effects.has("harvest"):
				active_effects["harvest"] = true

		"ice_freeze":
			active_effects["ice_freeze"] = true
			has_ice_freeze = true
			ice_freeze_timer = 0.0

	# 如果效果列表真的改變了，才發出信號
	if active_effects.size() != previous_effects_count or not active_effects.has(effect_type):
		effect_changed.emit(active_effects)

func apply_swift_dash() -> void:
	dash_cooldown *= swift_dash_cooldown_reduction
	dash_speed *= swift_dash_multiplier
	dash_duration *= swift_dash_multiplier

func remove_swift_dash() -> void:
	dash_cooldown = 0.7
	dash_speed = 250.0
	dash_duration = 0.15

func process_loot_effect(effect_name: String) -> void:
	match effect_name:
		"swift_dash":
			if not active_effects.has("swift_dash"):
				active_effects["swift_dash"] = true
				apply_swift_dash()

func _handle_charge_state(delta: float) -> void:
	if not active_effects or not "charge_attack_movement" in active_effects:
		if is_charging or charge_damage_multiplier > 1.0:
			reset_charge_state()
		return
	
	if not is_charging:
		is_charging = true
		charge_effect_timer = 0.0
		if charge_damage_multiplier <= 1.0:
			charge_time = 0.0
			charge_damage_multiplier = 1.0
			has_played_first_effect = false
			has_played_second_effect = false
			has_played_max_charge_effect = false
	
	charge_time += delta * current_charge_rate
	var previous_multiplier = charge_damage_multiplier
	charge_damage_multiplier = min(1.0 + (charge_time * max_charge_bonus), 6.0)
	
	if effect_manager:
		if previous_multiplier < 1.2 and charge_damage_multiplier >= 1.2 and not has_played_first_effect:
			effect_manager.play_charge_effect(1.2)
			has_played_first_effect = true
		elif previous_multiplier < 3.0 and charge_damage_multiplier >= 3.0 and not has_played_second_effect:
			effect_manager.play_charge_effect(3.0)
			has_played_second_effect = true
		elif previous_multiplier < 5.0 and charge_damage_multiplier >= 5.0 and not has_played_max_charge_effect:
			effect_manager.play_charge_complete_effect()
			has_played_max_charge_effect = true

func enable_charge_attack(_max_bonus: float, _charge_rate: float) -> void:
	max_charge_bonus = 5.0
	current_charge_rate = 0.8
	active_effects["charge_attack_movement"] = true

func get_berserker_multiplier() -> float:
	if not active_effects.has("berserker"):
		return 1.0
	
	var health_percent = float(current_health) / float(max_health)
	var lost_health_percent = 1.0 - health_percent
	return min(1.0 + lost_health_percent, 2.0)

func reset_all_states() -> void:
	if active_effects.has("swift_dash"):
		remove_swift_dash()
	var effects_were_cleared = not active_effects.is_empty()
	active_effects.clear()
	if effects_were_cleared:
		effect_changed.emit(active_effects)
	has_dash_wave = false
	max_jumps = 2
	
	reset_move_speed()
	reset_jump_height()
	reset_attack_speed()
	reset_damage()
	reset_dash_distance()
	
	is_charging = false
	charge_time = 0.0
	charge_damage_multiplier = 1.0
	charge_start_timer = 0.0
	is_charge_ready = false
	max_charge_bonus = 1.0
	current_charge_rate = 0.15
	if effect_manager:
		effect_manager.stop_charge_effect()
	
	current_health = max_health
	
	is_invincible = false
	
	dash_cooldown_timer = 0
	dash_timer = 0
	invincible_timer = 0
	special_attack_timer = 0
	blink_timer = 0
	
	jump_count = 0
	current_attack_combo = 0
	
	hit_enemies.clear()
	
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	set_collision_layer_value(2, true)
	modulate.a = 1.0
	visible = true
	
	set_physics_process(true)
	set_process_input(true)
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")
	
	agile_dash_attack_count = 0
	active_effects.erase("agile_dash")
	
	rage_stack = 0
	active_effects.erase("rage")
	
	has_ice_freeze = false
	ice_freeze_timer = 0.0
	active_effects.erase("ice_freeze")

func _on_effect_manager_effect_finished() -> void:
	pass

func _on_double_jump_effect_animation_finished() -> void:
	pass

func _on_health_changed(_new_health: Variant) -> void:
	pass

func apply_knockback(knockback: Vector2) -> void:
	velocity = knockback
	
	if is_on_floor() and knockback.y < 0:
		velocity.y = knockback.y
	
	move_and_slide()

func create_dash_wave() -> void:
	if not wave_scene:
		return
		
	var wave = wave_scene.instantiate()
	get_parent().add_child(wave)
	wave.global_position = global_position
	
	if dash_direction < 0:
		wave.rotation = PI
		wave.scale.x = -1
	else:
		wave.rotation = 0
		wave.scale.x = 1

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = -JUMP_VELOCITY
			jump_count = 1
		elif jump_count < max_jumps:
			velocity.y = -JUMP_VELOCITY * 1.2
			jump_count += 1

func boost_move_speed(multiplier: float) -> void:
	speed *= multiplier
	dash_speed *= multiplier

func boost_jump_height(multiplier: float) -> void:
	jump_velocity *= multiplier

func boost_attack_speed(multiplier: float) -> void:
	attack_combo_window *= (1.0 / multiplier)
	if animated_sprite:
		animated_sprite.speed_scale *= multiplier

func boost_damage(multiplier: float) -> void:
	current_attack_damage = base_attack_damage * multiplier
	current_special_attack_damage = base_special_attack_damage * multiplier

func boost_dash_distance(multiplier: float) -> void:
	dash_duration *= multiplier

func reset_move_speed() -> void:
	speed = 200.0
	dash_speed = 250.0

func reset_jump_height() -> void:
	jump_velocity = -450.0

func reset_attack_speed() -> void:
	attack_combo_window = 0.5
	if animated_sprite:
		animated_sprite.speed_scale = 1.0

func reset_damage() -> void:
	current_attack_damage = base_attack_damage
	current_special_attack_damage = base_special_attack_damage
	rage_stack = 0

func reset_dash_distance() -> void:
	dash_duration = 0.3

func disable_charge_attack() -> void:
	active_effects.erase("charge_attack_movement")
	
	is_charging = false
	charge_time = 0.0
	charge_damage_multiplier = 1.0
	saved_charge_multiplier = 1.0
	max_charge_bonus = 1.0
	current_charge_rate = 0.15
	charge_start_timer = 0.0
	is_charge_ready = false
	
	if effect_manager:
		effect_manager.stop_charge_effect()

func _update_rage_damage() -> void:
	var total_bonus = rage_stack * rage_damage_bonus
	current_attack_damage = base_attack_damage * (1 + total_bonus)
	current_special_attack_damage = base_special_attack_damage * (1 + total_bonus)

func is_about_to_be_hit() -> bool:
	var hitbox = $Hitbox
	if not hitbox:
		return false
	
	var areas = hitbox.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		
		if parent and parent.is_in_group("enemy"):
			return true
		if area.is_in_group("enemy_attack") or area.is_in_group("enemy"):
			return true
		if area.get_collision_layer_value(3):
			return true
	
	return false

func start_ice_freeze_attack() -> void:
	current_attack_combo = 0
	
	if animated_sprite:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		animated_sprite.flip_h = direction_to_mouse.x < 0
		animated_sprite.play("attack1")
		
		if attack_area:
			attack_area.scale.x = -1 if animated_sprite.flip_h else 1
	
	if attack_area:
		attack_area.monitoring = true
	
	ice_freeze_timer = ice_freeze_cooldown
	
	if effect_manager:
		effect_manager.play_ice_effect()

func restore_health() -> void:
	current_health = max_health
	health_changed.emit(current_health)
	if effect_manager:
		effect_manager.play_heal_effect()

func restore_lives() -> void:
	has_revive_heart = true
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("restore_revive_heart"):
		ui.restore_revive_heart()

func _handle_ground_slam_input() -> void:
	if Input.is_action_just_pressed("ground_slam"):
		# print(f"[Player] Ground Slam Input: can_perform={can_perform_ground_slam}, not_on_floor={not is_on_floor()}, state={state_machine.current_state.name if state_machine and state_machine.current_state else 'N/A'}")
		print("[Player] Ground Slam Input: can_perform=%s, not_on_floor=%s, state=%s, jump_count=%s, max_jumps=%s" % [
			can_perform_ground_slam, 
			not is_on_floor(), 
			state_machine.current_state.name if state_machine and state_machine.current_state else "N/A",
			jump_count,
			max_jumps
		])
		
		if can_perform_ground_slam and not is_on_floor():
			if state_machine:
				if state_machine.states.has("groundslam"): 
					print("[Player] 執行地面衝擊")
					state_machine._transition_to(state_machine.states["groundslam"])
				else:
					printerr("[Player] Error: 'groundslam' state not found in StateMachine states dictionary!")
			else:
				printerr("[Player] Error: StateMachine node not found!")
		else:
			print("[Player] 不能執行地面衝擊: 條件不滿足")
			if is_on_floor():
				print("[Player] - 原因: 玩家在地面上")
			if not can_perform_ground_slam:
				print("[Player] - 原因: can_perform_ground_slam = false")

# Setter function for can_perform_ground_slam with logging
func set_can_ground_slam(value: bool) -> void:
	if can_perform_ground_slam != value: 
		var old_value = can_perform_ground_slam
		can_perform_ground_slam = value
		# print(f"[Player_set_can_ground_slam] Value changed from {old_value} to {can_perform_ground_slam}. Caller: {get_stack()[1] if get_stack().size() > 1 else 'Unknown'}")
		print("[Player_set_can_ground_slam] Value changed from %s to %s. Caller: %s" % [old_value, can_perform_ground_slam, get_stack()[1] if get_stack().size() > 1 else "Unknown"])

#region 輔助方法
func get_health_percentage() -> float:
	if max_health > 0:
		return float(current_health) / max_health
	return 0.0
#endregion
