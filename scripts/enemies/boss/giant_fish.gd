extends "res://scripts/enemies/boss/boss_base.gd"

class_name GiantFish

#region 行動名稱常量
const ACTION_IDLE = "Idle"
const ACTION_SIDE_MOVE_ATTACK = "SideMoveAttack" 
const ACTION_JUMP_ATTACK = "JumpAttack"        
const ACTION_TAIL_SWIPE_ATTACK = "TailSwipeAttack"
const ACTION_BUBBLE_ATTACK = "BubbleAttack"
#endregion

#region 巨魚特有狀態
enum GiantFishState {
	IDLE = BossBase.BossState.IDLE,
	APPEAR = BossBase.BossState.APPEAR,
	MOVE = BossBase.BossState.MOVE, 
	HURT = BossBase.BossState.HURT,
	DEFEATED = BossBase.BossState.DEFEATED,
	PHASE_TRANSITION = BossBase.BossState.PHASE_TRANSITION,

	DIVE = BossBase.BossState.MAX_BOSS_STATES,
	SUBMERGED_MOVE,
	EMERGE_JUMP,
	# 擺尾攻擊狀態
	TAIL_SWIPE, 
	# 吐泡泡攻擊狀態
	BUBBLE_ATTACK_STATE, 
	# 左右移動攻擊狀態 (對應 ACTION_SIDE_MOVE_ATTACK)
	SIDE_MOVE_ATTACK_STATE 
}
#endregion

#region 預載入獨立場景
@export var water_splash_scene: PackedScene
@export var wave_scene: PackedScene
@export var bubble_scene: PackedScene

@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
#endregion

#region 巨魚特有屬性
@export_group("Giant Fish Behavior - Jump Attack")
@export var dive_duration: float = 1.0
@export var submerged_move_speed: float = 300.0
@export var submerged_move_timeout: float = 5.0
@export var emerge_jump_initial_y_velocity: float = -700.0
@export var emerge_jump_horizontal_speed: float = 150.0 
@export var emerge_jump_gravity_scale: float = 0.2
@export var emerge_jump_max_air_time: float = 3.0 
@export var emerge_jump_apex_hold_duration: float = 0.35
@export var emerge_jump_apex_gravity_scale: float = 0.1

@export_group("Giant Fish Behavior - Other Attacks")
@export var tail_swipe_duration: float = 1.5
@export var bubble_attack_duration: float = 1.0
@export var bubbles_per_attack_phase1: int = 5
@export var bubbles_per_attack_phase2: int = 7
@export var charge_speed_multiplier: float = 3.0

@export_group("Mercy Mechanism")
@export var mercy_period: float = 10.0
@export var max_aggression_reduction_factor: float = 0.7
#endregion

#region 狀態變量
var is_phase_two: bool = false
var damage_dealt_in_mercy_period: float = 0.0
var mercy_period_timer: float = 0.0
var current_aggression_factor: float = 1.0

var submerged_move_target_position: Vector2
var submerged_move_current_timer: float = 0.0
var _dive_state_timer: float = 0.0
var _bubble_attack_state_timer: float = 0.0
var _emerge_jump_air_timer: float = 0.0
var _is_at_jump_apex: bool = false
var _jump_apex_hold_timer: float = 0.0
var _previous_jump_velocity_y: float = 0.0
var _tail_swipe_state_timer: float = 0.0

var half_body_move_direction: int = 1
var half_body_moves_done: int = 0
var action_has_spawned_bubbles_in_phase2: bool = false

# 新增: 用於回歸中心邏輯的變數
var _map_edge_left_x: float = INF 
var _map_edge_right_x: float = -INF
var _map_width_calculated: bool = false
var _is_returning_to_center: bool = false
var _return_target_x: float = 0.0

# 權重系統變數
var available_actions: Array[Dictionary] = []
var last_action_execution_times: Dictionary = {}
var initial_max_health: float = 0.0
var consecutive_idle_count: int = 0
const MAX_CONSECUTIVE_IDLE: int = 2

# 新增一個旗標，用於判斷是否在受傷後應該立即反擊
var is_counter_attack_pending: bool = false
#endregion


func _ready() -> void:
	super._ready()
	initial_max_health = max_health
	can_be_interrupted = false
	current_state = GiantFishState.APPEAR 
	mercy_period_timer = mercy_period
	_gfb_initialize_available_actions()
	
	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = self.attack_cooldown 
		attack_cooldown_timer.timeout.connect(_on_idle_finished_and_decide_next_action)

	var current_time_init = Time.get_ticks_msec() / 1000.0
	for action_config in available_actions:
		var action_name = action_config.get("name")
		if action_name and action_name != ACTION_IDLE: 
			last_action_execution_times[action_name] = current_time_init - action_config.get("min_interval", 100.0) - 1.0


func _physics_process(delta: float) -> void:
	if current_state == GiantFishState.DEFEATED:
		return

	super._physics_process(delta)

	_update_mercy_mechanism(delta)

	match current_state:
		GiantFishState.IDLE:
			_process_idle_state(delta)
		GiantFishState.SIDE_MOVE_ATTACK_STATE:
			_giant_fish_side_move_attack_state(delta) 
		GiantFishState.DIVE:
			_giant_fish_dive_state(delta)
		GiantFishState.SUBMERGED_MOVE:
			_giant_fish_submerged_move_state(delta)
		GiantFishState.EMERGE_JUMP:
			_giant_fish_emerge_jump_state(delta)
		GiantFishState.TAIL_SWIPE: 
			_giant_fish_tail_swipe_state(delta) 
		GiantFishState.BUBBLE_ATTACK_STATE:
			_giant_fish_bubble_attack_state(delta) 
		GiantFishState.APPEAR, GiantFishState.MOVE, GiantFishState.HURT, GiantFishState.PHASE_TRANSITION:
			# Let superclass handle or add specific logic if any
			pass # Assuming super._physics_process handles the logic for these states if not overridden by specific _giant_fish_..._state_logic


#region 狀態處理函式
func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	if not is_on_floor():
		velocity.y += gravity * delta

func _on_idle_finished_and_decide_next_action() -> void:
	if current_state == GiantFishState.IDLE:
		_gfb_calculate_and_select_next_action()


func _giant_fish_side_move_attack_state(_delta: float):
	var current_charge_speed = move_speed * charge_speed_multiplier

	if _is_returning_to_center:
		velocity.x = half_body_move_direction * current_charge_speed
		if ( (half_body_move_direction > 0 and global_position.x >= _return_target_x) or
			 (half_body_move_direction < 0 and global_position.x <= _return_target_x) or
			 abs(global_position.x - _return_target_x) < 15.0 ):
			_change_state(GiantFishState.IDLE)
			return
	elif is_on_wall():
		var current_hit_x = global_position.x
		
		if half_body_move_direction < 0: # 向左撞牆
			_map_edge_left_x = current_hit_x
		else: # 向右撞牆
			_map_edge_right_x = current_hit_x

		if _map_edge_left_x != INF and _map_edge_right_x != -INF and _map_edge_left_x < _map_edge_right_x:
			_map_width_calculated = true


		velocity.x = 0 
		half_body_moves_done += 1

		var max_moves = 2 
		if is_phase_two:
			max_moves = 4 

		if is_phase_two and not action_has_spawned_bubbles_in_phase2:
			_spawn_bubbles_for_action()
			action_has_spawned_bubbles_in_phase2 = true
		
		if half_body_moves_done >= max_moves:
			_is_returning_to_center = true
			
			if _map_width_calculated:
				var map_width = _map_edge_right_x - _map_edge_left_x
				var center_x = _map_edge_left_x + map_width / 2.0
				var offset_range = map_width * 0.25
				
				var target_min_x: float
				var target_max_x: float
				
				var new_direction_of_return = -half_body_move_direction # Direction BOSS will move for returning
				
				if new_direction_of_return > 0: # Returning towards RIGHT
					if current_phase == 1:
						# Phase 1, returning RIGHT: Target in RIGHT half of random zone
						target_min_x = center_x + 0.01 
						target_max_x = center_x + offset_range
					else: # current_phase == 2
						# Phase 2, returning RIGHT: Target in LEFT half of random zone
						target_min_x = center_x - offset_range
						target_max_x = center_x - 0.01
				else: # new_direction_of_return < 0: Returning towards LEFT
					if current_phase == 1:
						# Phase 1, returning LEFT: Target in LEFT half of random zone
						target_min_x = center_x - offset_range
						target_max_x = center_x - 0.01
					else: # current_phase == 2
						# Phase 2, returning LEFT: Target in RIGHT half of random zone
						target_min_x = center_x + 0.01
						target_max_x = center_x + offset_range
						
				_return_target_x = randf_range(target_min_x, target_max_x)
			else:
				if target_player and is_instance_valid(target_player):
					_return_target_x = global_position.x + sign(target_player.global_position.x - global_position.x) * (move_speed * 0.5) # Move a bit towards player
				else:
					_return_target_x = global_position.x + (-half_body_move_direction * (move_speed * 0.5)) 

			half_body_move_direction *= -1 # Reverse direction to move towards _return_target_x
			if animated_sprite: animated_sprite.flip_h = half_body_move_direction < 0
			action_has_spawned_bubbles_in_phase2 = false
			return 
		else:
			half_body_move_direction *= -1
			if animated_sprite: animated_sprite.flip_h = half_body_move_direction < 0
			action_has_spawned_bubbles_in_phase2 = false

	if not _is_returning_to_center:
		velocity.x = half_body_move_direction * current_charge_speed


func _giant_fish_dive_state(_delta: float):
	_dive_state_timer += _delta
	if _dive_state_timer >= dive_duration:
		_change_state(GiantFishState.SUBMERGED_MOVE)


func _giant_fish_submerged_move_state(delta: float):
	if target_player:
		# Potentially re-evaluate target if player moves significantly, for now stick to the initial target.
		pass
	
	global_position = global_position.move_toward(submerged_move_target_position, submerged_move_speed * delta)
	submerged_move_current_timer += delta

	var dist_to_target = global_position.distance_to(submerged_move_target_position)

	if dist_to_target < 10.0 or submerged_move_current_timer >= submerged_move_timeout:
		_prepare_emerge_jump()


func _giant_fish_emerge_jump_state(delta: float):
	_emerge_jump_air_timer += delta

	var current_gravity_scale = emerge_jump_gravity_scale

	# Apex detection and hold logic
	var was_rising = _previous_jump_velocity_y < -1.0 # Check if it was clearly rising
	var is_now_falling_or_still = velocity.y >= -1.0    # Check if it has started to fall or is near/at apex

	if not _is_at_jump_apex and was_rising and is_now_falling_or_still:
		_is_at_jump_apex = true
		_jump_apex_hold_timer = 0.0

	if _is_at_jump_apex:
		_jump_apex_hold_timer += delta
		if _jump_apex_hold_timer < emerge_jump_apex_hold_duration:
			current_gravity_scale = emerge_jump_apex_gravity_scale
		else:
			_is_at_jump_apex = false # End apex hold

	# Apply gravity based on the determined scale
	velocity.y += gravity * current_gravity_scale * delta
	
	# Update previous velocity for next frame's apex detection
	_previous_jump_velocity_y = velocity.y

	# Check for landing or timeout
	if is_on_floor():
		velocity.x = 0 
		_is_at_jump_apex = false
		_change_state(GiantFishState.IDLE)
		return
	elif _emerge_jump_air_timer >= emerge_jump_max_air_time:
		velocity.x = 0 
		velocity.y = 0 
		_is_at_jump_apex = false
		_change_state(GiantFishState.IDLE)
		return

func _giant_fish_tail_swipe_state(delta: float):
	_tail_swipe_state_timer += delta
	if _tail_swipe_state_timer >= tail_swipe_duration:
		_change_state(GiantFishState.IDLE)


func _giant_fish_bubble_attack_state(delta: float):
	_bubble_attack_state_timer += delta
	if _bubble_attack_state_timer >= bubble_attack_duration:
		_change_state(GiantFishState.IDLE)

#endregion

#region 攻擊準備/執行函式
func _prepare_jump_attack():
	if not target_player: 
		return
	submerged_move_target_position = Vector2(target_player.global_position.x, global_position.y)
	submerged_move_current_timer = 0.0
	_dive_state_timer = 0.0
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.DIVE)

func _prepare_tail_swipe_attack():
	action_has_spawned_bubbles_in_phase2 = false
	_tail_swipe_state_timer = 0.0
	_change_state(GiantFishState.TAIL_SWIPE)

func _prepare_bubble_attack():
	_spawn_bubbles_for_action()
	_bubble_attack_state_timer = 0.0
	_change_state(GiantFishState.BUBBLE_ATTACK_STATE)

func _prepare_idle():
	_change_state(GiantFishState.IDLE)

func _prepare_half_body_move():
	half_body_moves_done = 0
	
	_map_edge_left_x = INF 
	_map_edge_right_x = -INF
	_map_width_calculated = false
	_is_returning_to_center = false
	_return_target_x = 0.0
	
	if target_player and is_instance_valid(target_player):
		half_body_move_direction = 1 if target_player.global_position.x > global_position.x else -1
	else:
		half_body_move_direction = 1 if randf() > 0.5 else -1
	
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.SIDE_MOVE_ATTACK_STATE) 

func _prepare_emerge_jump():
	action_has_spawned_bubbles_in_phase2 = false

	if target_player and is_instance_valid(target_player):
		var direction_to_player = (target_player.global_position - global_position).normalized()
		velocity.x = direction_to_player.x * emerge_jump_horizontal_speed
		velocity.y = emerge_jump_initial_y_velocity 
	else:
		velocity.x = 0
		velocity.y = emerge_jump_initial_y_velocity

	_emerge_jump_air_timer = 0.0
	_is_at_jump_apex = false
	_previous_jump_velocity_y = emerge_jump_initial_y_velocity
	_change_state(GiantFishState.EMERGE_JUMP)

#endregion

#region 水花、波浪、泡泡的產生函式
func _spawn_water_splashes_at_point(point: Vector2, direction_is_left: bool):
	if not water_splash_scene:
		push_error("Water Splash Scene not set!")
		return

	var splash_count = 5 if is_phase_two else 3

	for i in range(splash_count):
		var splash = water_splash_scene.instantiate()
		get_tree().current_scene.add_child(splash)
		splash.global_position = point
		var horizontal_velocity_magnitude = (i + 1) * 50.0
		var launch_angle_degrees = 60.0 # Example: high arc
		var launch_angle_radians = deg_to_rad(launch_angle_degrees)
		
		var dir_x = -1.0 if direction_is_left else 1.0
		# For splashes going to both sides, you'd alternate dir_x or have two loops/calls
		# Assuming 'direction_is_left' means the *group* of splashes goes left or right from a central point.
		# If it means the fish is facing left and splashes go opposite, adjust dir_x.
		# For simplicity, let's assume splashes spread: half left, half right relative to 'point'
		# This part needs clarification based on desired effect. The ORIGINAL_README was more detailed.
		# Reverting to a simpler model where 'direction_is_left' determines the general direction from the point
		
		# Let's assume the WaterSplash scene itself has logic to move based on some initial velocity property
		if splash.has_method("launch"):
			var velocity_vector = Vector2(cos(launch_angle_radians) * horizontal_velocity_magnitude * dir_x, 
										  -sin(launch_angle_radians) * horizontal_velocity_magnitude)
			splash.launch(velocity_vector)
		else:
			push_warning("WaterSplash scene is missing a 'launch' method.")


func _spawn_wave():
	if not wave_scene:
		push_error("Wave Scene not set!")
		return


func _spawn_bubbles_for_action():
	if not bubble_scene:
		push_error("Bubble Scene not set!")
		return

	var bubble_count = bubbles_per_attack_phase2 if is_phase_two else bubbles_per_attack_phase1
	
	var spawn_point_node = $BubbleSpawnPoint
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position

	for i in range(bubble_count):
		var bubble = bubble_scene.instantiate()
		get_tree().current_scene.add_child(bubble)
		bubble.global_position = spawn_pos
		if bubble.has_method("initialize_bubble"):
			bubble.initialize_bubble()

#endregion

#region 仁慈機制與階段轉換
func _update_mercy_mechanism(delta: float):
	mercy_period_timer -= delta
	if mercy_period_timer <= 0:
		mercy_period_timer = mercy_period
		if damage_dealt_in_mercy_period == 0:
			current_aggression_factor = maxf(current_aggression_factor * 0.8, max_aggression_reduction_factor)
		else:
			current_aggression_factor = 1.0
		
		damage_dealt_in_mercy_period = 0


func take_damage(damage: float, attacker: Node, _knockback_info: Dictionary = {}) -> void:
	if current_state == GiantFishState.APPEAR:
		return

	super.take_damage(damage, attacker)

	if current_health <= 0:
		return

	damage_dealt_in_mercy_period += damage
	
	if current_health <= max_health / 2 and not is_phase_two:
		if current_state != GiantFishState.PHASE_TRANSITION:
			print_debug("[Phase] Health below threshold. Triggering Phase Transition.")
			_change_state(GiantFishState.PHASE_TRANSITION)

#endregion

#region 狀態改變
func _change_state(new_state: int) -> void:
	# 為了避免在日誌中看到重複的狀態切換（例如 HURT -> HURT），增加此判斷
	if current_state == new_state:
		return
		
	var old_state_name = "UNKNOWN"
	var new_state_name = "UNKNOWN"
	var old_state_idx = GiantFishState.values().find(current_state)
	var new_state_idx = GiantFishState.values().find(new_state)

	if old_state_idx != -1: old_state_name = GiantFishState.keys()[old_state_idx]
	if new_state_idx != -1: new_state_name = GiantFishState.keys()[new_state_idx]
	
	print_debug("[State Change] %s -> %s" % [old_state_name, new_state_name])

	# 將狀態設定的權力完全交給父類別，子類別不再重複設定
	super._change_state(new_state)

	# 移除子類別中重複的狀態設定，這是導致狀態混亂的根源
	# previous_state = current_state  <- REMOVED
	# current_state = new_state     <- REMOVED
	
	match new_state:
		GiantFishState.IDLE:
			velocity = Vector2.ZERO
			if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
				attack_cooldown_timer.start()
				
		GiantFishState.DIVE:
			velocity = Vector2.ZERO
			
		GiantFishState.DEFEATED:
			_on_defeated()
			
		GiantFishState.PHASE_TRANSITION:
			is_phase_two = true
			current_phase = 2
			
		GiantFishState.SIDE_MOVE_ATTACK_STATE:
			can_be_interrupted = false
			
		GiantFishState.EMERGE_JUMP:
			can_be_interrupted = true
			
	var animation_name = get_current_animation_name()
	if animation_name and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif animation_name:
		printerr("Animation not found for state %s (tried '%s')" % [GiantFishState.keys()[GiantFishState.values().find(new_state)], animation_name])

#endregion

#region Boss特有邏輯的覆寫或擴展
func _on_defeated():
	set_physics_process(false)
	if collision_shape_node:
		collision_shape_node.disabled = true
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
	velocity = Vector2.ZERO
	if animated_sprite and animated_sprite.sprite_frames.has_animation("defeat"):
		animated_sprite.play("defeat")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout 
	
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("on_boss_defeated"):
		game_manager.on_boss_defeated(self.name)
	
	queue_free()

#endregion

#region 行動選擇與權重計算 (重要邏輯)

func _gfb_initialize_available_actions() -> void: 
	available_actions = [
		# 行動字典結構:
		# {
		# "name": String (行動的唯一標識),
		# "function_name": String (實際執行此行動的函數名，在 _prepare_action_by_state 中使用),
		# "base_weight": float (基礎權重),
		# "min_interval": float (最小觸發間隔，秒),
		# "phases": Array[int] (允許執行的階段, e.g., [1, 2]),
		# "conditions": Dictionary (其他觸發條件，例如與玩家的距離、Boss血量百分比等)
		# Optional: "disabled_by_action": String (如果上一個動作是這個，則禁用此動作)
		# "is_counter_attack": bool (此招式是否可用於反擊)
		# }

		# 空閒狀態 (通常權重較低，作為後備)
		{"name": ACTION_IDLE, "function_name": "_prepare_idle", "base_weight": 0.05, "min_interval": 0.0, "phases": [1, 2], "conditions": {}, "is_counter_attack": false},
		
		# 左右移動衝撞 (階段一、二) - 設為反擊招式
		{"name": ACTION_SIDE_MOVE_ATTACK, "function_name": "_prepare_half_body_move", "base_weight": 1.0, "min_interval": 5.0, "phases": [1, 2], "conditions": {"min_player_dist": 250.0, "max_player_dist": 1200.0}, "is_counter_attack": true},
		
		# 跳躍攻擊 (階段一、二) - 不設為反擊招式
		{"name": ACTION_JUMP_ATTACK, "function_name": "_prepare_jump_attack", "base_weight": 0.8, "min_interval": 6.0, "phases": [1, 2], "conditions": {"min_player_dist": 150.0, "max_player_dist": 800.0}, "is_counter_attack": false},
		
		# 擺尾掀起波浪 (階段一、二) - 設為反擊招式
		{"name": ACTION_TAIL_SWIPE_ATTACK, "function_name": "_prepare_tail_swipe_attack", "base_weight": 0.7, "min_interval": 4.0, "phases": [1, 2], "conditions": {"max_player_dist": 400.0}, "is_counter_attack": true},
		
		# 吐泡泡攻擊 (階段一特有) - 可被打斷，不設為反擊招式
		{"name": ACTION_BUBBLE_ATTACK, "function_name": "_prepare_bubble_attack", "base_weight": 0.6, "min_interval": 4.0, "phases": [1], "conditions": {"min_player_dist": 150.0, "max_player_dist": 600.0}, "is_counter_attack": false}
	]
	
	# 初始化 last_action_execution_times，確保所有動作在遊戲開始時都可以立即執行（如果條件允許）
	var current_time = Time.get_ticks_msec() / 1000.0
	for action_config in available_actions:
		var action_name = action_config.get("name")
		if action_name: # 確保 action_name 存在
			last_action_execution_times[action_name] = current_time - action_config.get("min_interval", 100.0) - 1.0 # 減去一個較大的間隔以允許首次執行


func _gfb_calculate_and_select_next_action() -> void: 
	if not is_instance_valid(target_player):
		_prepare_action_by_state(ACTION_IDLE)
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var weighted_actions: Array[Dictionary] = []
	var total_weight: float = 0.0

	print_debug("--- [AI Decision] Phase: %d, PlayerDist: %.2f, HP: %.2f%% ---" % [current_phase, global_position.distance_to(target_player.global_position) if target_player else -1.0, (current_health / initial_max_health) * 100.0 if initial_max_health > 0 else -1.0])

	for action_config in available_actions:
		var action_name: String = action_config.get("name")
		var base_weight: float = action_config.get("base_weight", 0.0)
		var min_interval: float = action_config.get("min_interval", 0.0)

		if action_name == ACTION_IDLE and consecutive_idle_count >= MAX_CONSECUTIVE_IDLE:
			continue

		var _retrieved_phases_value = action_config.get("phases")
		var allowed_phases: Array[int] = []

		if _retrieved_phases_value != null and _retrieved_phases_value is Array:
			for item in _retrieved_phases_value:
				if item is int:
					allowed_phases.append(item)
				else:
					printerr("Warning: Non-integer found in 'phases' array for action '", action_config.get("name"), "'. Item: ", item)

		var conditions: Dictionary = action_config.get("conditions", {})
		
		var time_since_last_execution = current_time - last_action_execution_times.get(action_name, -INF)
		
		if time_since_last_execution < min_interval:
			continue

		if not allowed_phases.has(current_phase):
			continue

		var conditions_met = true
		var condition_adjustment_factor = 1.0

		if conditions.has("min_player_dist"):
			var dist_to_player = global_position.distance_to(target_player.global_position)
			if dist_to_player < conditions.get("min_player_dist"):
				conditions_met = false
			elif dist_to_player < conditions.get("min_player_dist") * 1.5:
				condition_adjustment_factor *= 1.2


		if conditions.has("max_player_dist"):
			var dist_to_player = global_position.distance_to(target_player.global_position)
			if dist_to_player > conditions.get("max_player_dist"):
				conditions_met = false
			elif dist_to_player > conditions.get("max_player_dist") * 0.8:
				condition_adjustment_factor *= 1.2


		if conditions.has("boss_health_percent_below"):
			if (current_health / initial_max_health) * 100.0 >= conditions.get("boss_health_percent_below"):
				conditions_met = false
		
		if conditions.has("boss_health_percent_above"):
			if (current_health / initial_max_health) * 100.0 <= conditions.get("boss_health_percent_above"):
				conditions_met = false
		
		if conditions_met:
			var current_action_weight = base_weight * condition_adjustment_factor * current_aggression_factor
			weighted_actions.append({"name": action_name, "weight": current_action_weight})
			total_weight += current_action_weight


	if weighted_actions.is_empty():
		var fallback_actions = [ACTION_JUMP_ATTACK, ACTION_TAIL_SWIPE_ATTACK]
		var selected_fallback = fallback_actions[randi() % fallback_actions.size()]
		print_debug("[AI Decision] No actions qualified. Forcing fallback action: '%s'" % selected_fallback)
		_prepare_action_by_state(selected_fallback)
		return

	var random_roll = randf() * total_weight
	var cumulative_weight = 0.0
	var selected_action_name = ACTION_IDLE

	var qualified_actions_log = ""
	for wa in weighted_actions:
		qualified_actions_log += "  - %s (W: %.2f)" % [wa.get("name"), wa.get("weight")]
	print_debug("[AI Decision] Qualified Actions:\n%s" % qualified_actions_log)


	for action_data in weighted_actions:
		cumulative_weight += action_data.get("weight", 0.0)
		if random_roll <= cumulative_weight:
			selected_action_name = action_data.get("name")
			break
	
	print_debug("[AI Decision] Selected Action: '%s' (Roll: %.2f / TotalW: %.2f)" % [selected_action_name, random_roll, total_weight])
	_prepare_action_by_state(selected_action_name)


func _prepare_action_by_state(action_name: String) -> void:
	if action_name == ACTION_IDLE:
		consecutive_idle_count += 1
	else:
		consecutive_idle_count = 0

	var action_config = null
	for config_loop_var in available_actions:
		if config_loop_var.get("name") == action_name:
			action_config = config_loop_var
			break

	if not action_config:
		printerr("[GFB _prepare_action_by_state] Error: Action config not found for '", action_name, "'. Defaulting to IDLE.")
		action_name = ACTION_IDLE
		for config_fallback_loop_var in available_actions:
			if config_fallback_loop_var.get("name") == ACTION_IDLE:
				action_config = config_fallback_loop_var
				break
	
	if not action_config:
		printerr("[GFB _prepare_action_by_state] CRITICAL Error: IDLE action config also not found! Cannot prepare any action.")
		_change_state(GiantFishState.IDLE)
		if attack_cooldown_timer and attack_cooldown_timer.is_stopped(): 
			attack_cooldown_timer.start()
		return

	var function_to_call_name = action_config.get("function_name")

	if function_to_call_name == null or not self.has_method(function_to_call_name):
		printerr("[GFB _prepare_action_by_state] Error: Method '", str(function_to_call_name), "' not found for action '", action_name, "' or function_name is null. Defaulting to IDLE state.")
		_change_state(GiantFishState.IDLE)
		if attack_cooldown_timer and attack_cooldown_timer.is_stopped(): 
			attack_cooldown_timer.start()
		return

	call(function_to_call_name)
	
	last_action_execution_times[action_name] = Time.get_ticks_msec() / 1000.0

#endregion

#region 打斷與反擊
func _on_interrupted(_attack_name: String) -> void:
	is_counter_attack_pending = true
	print_debug("[Interrupt] Action '%s' was interrupted. Counter-attack is pending." % _attack_name)

func _execute_counter_attack() -> void:
	if not is_counter_attack_pending:
		return
	
	is_counter_attack_pending = false

	var counter_actions = []
	for action in available_actions:
		if action.get("is_counter_attack", false):
			counter_actions.append(action.name)
	
	if counter_actions.is_empty():
		printerr("[GFB] _execute_counter_attack was called, but no actions are flagged as counter-attacks!")
		_change_state(GiantFishState.IDLE)
		return

	var selected_counter = counter_actions[randi() % counter_actions.size()]
	
	print_debug("[Interrupt] Executing counter-attack with action: '%s'" % selected_counter)

	last_action_execution_times[selected_counter] = 0
	
	call_deferred("_prepare_action_by_state", selected_counter)

#endregion

#region 動畫、信號回調與父類函式覆寫

# 動畫播放完畢時的回調
func _on_animation_finished() -> void:
	if current_state == BossBase.BossState.HURT and is_counter_attack_pending:
		_execute_counter_attack()
		return

	super._on_animation_finished()

func _is_state_duration_handled_manually(state: int) -> bool:
	return state in [
		GiantFishState.SIDE_MOVE_ATTACK_STATE,
		GiantFishState.DIVE,
		GiantFishState.SUBMERGED_MOVE,
		GiantFishState.EMERGE_JUMP,
		GiantFishState.TAIL_SWIPE,
		GiantFishState.BUBBLE_ATTACK_STATE,
		GiantFishState.PHASE_TRANSITION # 階段轉換本身也應手動控制
	]

func _is_state_an_attack(state: int) -> bool:
	return state in [
		GiantFishState.SIDE_MOVE_ATTACK_STATE,
		GiantFishState.DIVE,
		GiantFishState.SUBMERGED_MOVE,
		GiantFishState.EMERGE_JUMP,
		GiantFishState.TAIL_SWIPE,
		GiantFishState.BUBBLE_ATTACK_STATE
	] or super._is_state_an_attack(state)

func get_current_animation_name() -> String:
	match current_state:
		GiantFishState.TAIL_SWIPE:
			return "tail_swipe"
		GiantFishState.BUBBLE_ATTACK_STATE:
			return "bubble_attack"
		GiantFishState.SIDE_MOVE_ATTACK_STATE:
			return "move"
		GiantFishState.DIVE:
			return "dive_in"
		GiantFishState.SUBMERGED_MOVE:
			return "dive_move"
		GiantFishState.EMERGE_JUMP:
			return "emerge_jump"
		_:
			return super.get_current_animation_name()
#endregion
