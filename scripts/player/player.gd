extends CharacterBody2D

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
@export var jump_buffer_time = 0.1
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
@onready var jump_impact_area = $JumpImpactArea
@onready var state_machine = $StateMachine
@onready var metsys_node = $MetroidvaniaSystem
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight

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
var has_jump_impact := false

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

signal health_changed(new_health: int)
signal player_killed_enemy
signal died
signal gold_changed(new_gold: int)

signal effect_changed(effects: Dictionary)

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
	current_attack_damage = base_attack_damage
	current_special_attack_damage = base_special_attack_damage
	active_effects = {}
	emit_signal("effect_changed", active_effects)


func _physics_process(delta: float) -> void:

	if _handle_camera_mode(delta):
		return
		
	_update_global_timers(delta)

	var on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		_on_landed()
	was_on_floor = on_floor

	if metsys_node:
		metsys_node.set_player_position(global_position)

	if state_machine and state_machine.current_state:
		state_machine._physics_process(delta)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if is_camera_mode and event is InputEventMouseButton:
		_handle_camera_zoom(event)
		return
	
	if state_machine and state_machine.current_state:
		state_machine._input(event)

#endregion

#region 初始化系統
func _initialize_player() -> void:
	add_to_group("player")
	current_health = max_health
	gold = 0

func _setup_collisions() -> void:
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	
	var hitbox = $Hitbox
	if hitbox:
		hitbox.set_collision_layer_value(3, true)
		hitbox.set_collision_mask_value(4, true)
	
	if attack_area:
		attack_area.set_collision_layer_value(4, true)
		attack_area.set_collision_mask_value(3, true)

	if special_attack_area:
		special_attack_area.collision_layer = 0
		special_attack_area.collision_mask = 0
		
		special_attack_area.set_collision_layer_value(4, true)
		special_attack_area.set_collision_mask_value(3, true)

	if jump_impact_area:
		jump_impact_area.collision_layer = 0
		jump_impact_area.collision_mask = 0
		jump_impact_area.set_collision_mask_value(3, true)
		jump_impact_area.monitoring = false
		jump_impact_area.monitorable = true

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
	if is_invincible or (state_machine and state_machine.current_state is State_Dash):
		return
		
	current_health -= amount
	health_changed.emit(current_health)
	
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.reset_combo()
	
	if active_effects.has("rage") and rage_stack < rage_stack_limit:
		rage_stack += 1
		_update_rage_damage()
	
	if active_effects.has("thorns") and attacker != null:
		var real_attacker = attacker
		if attacker.has_method("get_shooter"):
			real_attacker = attacker.get_shooter()
		if real_attacker != null and real_attacker.has_method("take_damage"):
			real_attacker.take_damage(amount * 5.0)
	
	if current_health <= 0:
		if has_revive_heart:
			has_revive_heart = false
			current_health = float(max_health) / 2.0
			health_changed.emit(current_health)
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("use_revive_heart"):
				ui.use_revive_heart()
			set_invincible(2.0)
		else:
			if state_machine and state_machine.states.has("hurt"):
				state_machine._transition_to(state_machine.states["hurt"])
			else:
				
				set_physics_process(false)
				set_process_input(false)
				died.emit()
	else:
		if state_machine and state_machine.states.has("hurt"):
			state_machine._transition_to(state_machine.states["hurt"])
		else:
			
			set_invincible(invincible_duration)
	
	last_jump_was_wall_jump = false
	is_double_jumping_after_wall_jump = false

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
	jump_count = 0
	coyote_timer = coyote_time
	last_jump_was_wall_jump = false
	is_double_jumping_after_wall_jump = false

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
			
		"jump_impact":
			active_effects["jump_impact"] = true
			has_jump_impact = true
			max_jumps = 3
			
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
	active_effects.clear()
	has_dash_wave = false
	has_jump_impact = false
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
			if has_jump_impact:
				_create_jump_impact()
		elif jump_count < max_jumps:
			velocity.y = -JUMP_VELOCITY * 1.2
			jump_count += 1
			if has_jump_impact:
				_create_jump_impact(jump_count > 2)

func _create_jump_impact(is_double_jump: bool = false) -> void:
	if not effect_manager or not jump_impact_area:
		return
	
	hit_enemies.clear()
	
	var start_scale = Vector2(0.5, 0.5)
	var max_scale = Vector2(2.0, 2.0) if is_double_jump else Vector2(1.5, 1.5)
	var start_position = Vector2.ZERO
	var max_distance = 100.0 if is_double_jump else 60.0
	
	jump_impact_area.scale = start_scale
	jump_impact_area.position = start_position
	jump_impact_area.monitoring = true
	
	await get_tree().physics_frame
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(jump_impact_area, "scale", max_scale, 0.5)
	
	effect_manager.play_double_jump(animated_sprite.flip_h)
	
	var current_distance = 0.0
	var step = max_distance / 20.0
	
	for i in range(20):
		if not jump_impact_area.monitoring:
			jump_impact_area.monitoring = true
			await get_tree().physics_frame
			continue
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			jump_impact_area.global_position,
			jump_impact_area.global_position + Vector2(0, step),
			1
		)
		var result = space_state.intersect_ray(query)
		
		if not result:
			current_distance += step
			jump_impact_area.position.y = current_distance
		
		var areas = jump_impact_area.get_overlapping_areas()
		for area in areas:
			var enemy = area.get_parent()
			if enemy.is_in_group("enemy") and not hit_enemies.has(enemy):
				hit_enemies.append(enemy)
				
				var damage = current_attack_damage * (2.0 if is_double_jump else 1.0)
				enemy.take_damage(damage)
				
				if enemy.has_method("apply_knockback"):
					var direction = Vector2.UP + (Vector2.RIGHT if enemy.global_position.x > global_position.x else Vector2.LEFT)
					var force = Vector2(2000, -800) if is_double_jump else Vector2(1000, -400)
					enemy.apply_knockback(direction.normalized() * force)
		
		await get_tree().physics_frame
	
	await tween.finished
	
	jump_impact_area.monitoring = false
	jump_impact_area.scale = Vector2.ONE
	jump_impact_area.position = Vector2.ZERO

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
