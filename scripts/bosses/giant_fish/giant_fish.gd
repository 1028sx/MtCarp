extends "res://scripts/bosses/boss_base.gd"

class_name GiantFish

#region 行動名稱常量
const ACTION_IDLE = "Idle"
const ACTION_SIDE_MOVE_ATTACK = "SideMoveAttack" 
const ACTION_JUMP_ATTACK = "JumpAttack"        
const ACTION_TAIL_SWIPE_ATTACK = "TailSwipeAttack"
const ACTION_BUBBLE_ATTACK = "BubbleAttack"
const ACTION_REPOSITION = "Reposition" # 新增：重新佈局動作
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
	SIDE_MOVE_ATTACK_STATE,
	# 新增：重新佈局狀態
	REPOSITION_STATE 
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
@export var reposition_speed_multiplier: float = 1.5 # 新增：重新佈局時的移動速度

@export_group("Giant Fish Behavior - Phase Transition")
@export var phase_transition_duration: float = 2.0 

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
var _phase_transition_timer: float = 0.0
var _reposition_duration: float = 0.0 # 新增：重新佈局計時器

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
var last_action_name: String = "" # 新增：記錄上一個執行的動作
var initial_max_health: float = 0.0
var consecutive_idle_count: int = 0
const MAX_CONSECUTIVE_IDLE: int = 2

# 新增一個旗標，用於判斷是否在受傷後應該立即反擊
var is_counter_attack_pending: bool = false

# 連招系統變數
var is_in_combo: bool = false
var combo_library: Dictionary = {}
var current_combo: Array = []
var current_combo_action_index: int = 0
const COMBO_START_CHANCE: float = 0.4 # 40% 的機率在待機時嘗試發動連招
#endregion


func _ready() -> void:
	super._ready()
	initial_max_health = max_health
	can_be_interrupted = false
	current_state = GiantFishState.APPEAR 
	mercy_period_timer = mercy_period
	_gfb_initialize_available_actions()
	_gfb_initialize_combo_library()
	
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
		GiantFishState.PHASE_TRANSITION:
			_giant_fish_phase_transition_state(delta)
		GiantFishState.REPOSITION_STATE:
			_giant_fish_reposition_state(delta)
		GiantFishState.APPEAR, GiantFishState.MOVE, GiantFishState.HURT:
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
			_gfb_on_action_finished()
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
		_gfb_on_action_finished()
		return
	elif _emerge_jump_air_timer >= emerge_jump_max_air_time:
		velocity.x = 0 
		velocity.y = 0 
		_is_at_jump_apex = false
		_gfb_on_action_finished()
		return

func _giant_fish_tail_swipe_state(delta: float):
	_tail_swipe_state_timer += delta
	if _tail_swipe_state_timer >= tail_swipe_duration:
		_gfb_on_action_finished()


func _giant_fish_bubble_attack_state(delta: float):
	_bubble_attack_state_timer += delta
	if _bubble_attack_state_timer >= bubble_attack_duration:
		_gfb_on_action_finished()

func _giant_fish_phase_transition_state(delta: float):
	_phase_transition_timer += delta
	# 在這裡可以加入無敵、特效等邏輯
	if _phase_transition_timer >= phase_transition_duration:
		# 階段轉換演出結束，正式開始P2的連招
		print_debug("[GiantFish AI] Phase transition duration finished. Starting 'PhaseTransitionOpener' combo.")
		_start_combo("PhaseTransitionOpener")

func _giant_fish_reposition_state(_delta: float) -> void:
	# (此為預留空位，邏輯將在後續步驟中填充)
	pass
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

func _prepare_reposition() -> void:
	# (此為預留空位，邏輯將在後續步驟中填充)
	pass

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

#region 連招系統核心函式 (新)
func _gfb_initialize_combo_library() -> void:
	# 定義 BOSS 的所有連招組合
	# 鍵 (Key) 是連招的名稱，值 (Value) 是一個包含動作常量的陣列
	
	# 連招 A: 壓迫與突襲 (將玩家逼到角落後，發動突襲)
	combo_library["PressureCombo"] = {
		"actions": [ACTION_SIDE_MOVE_ATTACK, ACTION_JUMP_ATTACK],
		"condition": func(): return _is_player_in_corner()
	}
	
	# 連招 B: 近身作戰 (結合近距離的甩尾和遠程的泡泡)
	combo_library["CloseQuartersCombo"] = {
		"actions": [ACTION_TAIL_SWIPE_ATTACK, ACTION_BUBBLE_ATTACK],
		"condition": func(): return _is_player_close(250.0)
	}
	
	# 連招 C: 階段轉換專用 (一個更具威脅性的組合，作為 P2 的開場)
	combo_library["PhaseTransitionOpener"] = {
		"actions": [ACTION_JUMP_ATTACK, ACTION_TAIL_SWIPE_ATTACK],
		"condition": func(): return true # P2開場必定執行，無特殊條件
	}
	
	print_debug("[ComboSystem] Combo library initialized with %d combos." % combo_library.size())


func _start_combo(combo_name: String) -> void:
	if not combo_library.has(combo_name):
		printerr("[ComboSystem] Attempted to start non-existent combo: ", combo_name)
		_change_state(GiantFishState.IDLE)
		return
	
	print_debug("[ComboSystem] Starting combo: ", combo_name)
	is_in_combo = true
	current_combo = combo_library[combo_name]["actions"]
	current_combo_action_index = 0
	_execute_next_combo_action()

func _execute_next_combo_action() -> void:
	if not is_in_combo or current_combo_action_index >= current_combo.size():
		_end_combo()
		return

	var next_action_name = current_combo[current_combo_action_index]
	print_debug("[ComboSystem] Executing combo action %d: %s" % [current_combo_action_index + 1, next_action_name])
	
	current_combo_action_index += 1
	_prepare_action_by_state(next_action_name)

func _end_combo() -> void:
	if not is_in_combo:
		return
	
	print_debug("[ComboSystem] Combo finished.")
	is_in_combo = false
	current_combo = []
	current_combo_action_index = 0
	_change_state(GiantFishState.IDLE) # 連招結束後返回待機

func _gfb_on_action_finished() -> void:
	"""
	一個動作（如揮尾、衝刺）完成後被呼叫。
	用來決定是繼續連招的下一步，還是轉換到待機狀態。
	"""
	if is_in_combo:
		_execute_next_combo_action()
	else:
		_change_state(GiantFishState.IDLE)
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

#region 輔助函式 (新)

func _is_player_in_corner(corner_threshold_percent: float = 0.2) -> bool:
	"""檢查玩家是否被逼到地圖角落。"""
	if not is_instance_valid(target_player) or not _map_width_calculated:
		return false
	
	var map_width = _map_edge_right_x - _map_edge_left_x
	if map_width <= 0: return false
	
	var corner_threshold_pixels = map_width * corner_threshold_percent
	var player_x = target_player.global_position.x
	
	return player_x < _map_edge_left_x + corner_threshold_pixels or \
		   player_x > _map_edge_right_x - corner_threshold_pixels


func _is_player_close(distance: float) -> bool:
	"""檢查玩家與 BOSS 的距離是否小於指定值。"""
	if not is_instance_valid(target_player):
		return false
	return global_position.distance_to(target_player.global_position) <= distance


func _get_player_context() -> Dictionary:
	"""
	收集關於玩家的即時戰術資訊，供 AI 決策系統使用。
	這是為了解決 AI 權重計算系統無法獲取玩家資訊的潛在錯誤。
	"""
	if not is_instance_valid(target_player):
		return {"is_valid": false}
		
	var distance = global_position.distance_to(target_player.global_position)
	
	# 定義與 AI 邏輯一致的距離閾值
	var close_threshold = 300.0
	var far_threshold = 600.0
	
	var context = {
		"is_valid": true,
		"distance": distance,
		"is_close": distance <= close_threshold,
		"is_far": distance >= far_threshold,
		"is_in_corner": _is_player_in_corner(),
		"position": target_player.global_position
	}
	return context
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
	# 恢復對 super.take_damage 的呼叫，以修復打斷和血條信號問題
	# 並且只傳遞父類別需要的參數
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
func _reset_state_specific_variables() -> void:
	# 重置計時器
	_dive_state_timer = 0.0
	_bubble_attack_state_timer = 0.0
	_tail_swipe_state_timer = 0.0
	submerged_move_current_timer = 0.0
	_emerge_jump_air_timer = 0.0
	_jump_apex_hold_timer = 0.0
	
	# 重置旗標和計數器
	_is_at_jump_apex = false
	_is_returning_to_center = false
	half_body_moves_done = 0
	action_has_spawned_bubbles_in_phase2 = false

	# 重置其他變數
	_previous_jump_velocity_y = 0.0

func _change_state(new_state: int) -> void:
	if current_state == new_state:
		return
		
	# 最終修復：使用 .find_key() 來安全、正確地獲取 enum 的名稱
	var old_state_name = GiantFishState.find_key(current_state)
	if old_state_name == null: old_state_name = "UNKNOWN (%d)" % current_state
	
	var new_state_name = GiantFishState.find_key(new_state)
	if new_state_name == null: new_state_name = "UNKNOWN (%d)" % new_state

	print("[GiantFish AI] State Change: %s -> %s" % [old_state_name, new_state_name])

	# 核心修復：只在父類別認識該狀態時才呼叫 super._change_state
	# 這樣可以防止父類別處理它不認識的子類別狀態，從而避免狀態混亂
	if new_state in BossBase.BossState.values():
		super._change_state(new_state)
	else:
		# 如果是子類別特有的狀態，則手動在子類別中設定
		previous_state = current_state
		current_state = new_state

	self._reset_state_specific_variables()
	
	match new_state:
		GiantFishState.IDLE:
			velocity = Vector2.ZERO
			if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
				attack_cooldown_timer.start()
			# 核心修復：確保每次返回待機狀態時，都重置無敵狀態，使其變為可受傷
			vulnerable = true
			is_invincible = false
			can_be_interrupted = true
				
		GiantFishState.DIVE:
			velocity = Vector2.ZERO
			
		GiantFishState.DEFEATED:
			_on_defeated()
			
		GiantFishState.PHASE_TRANSITION:
			is_phase_two = true
			current_phase = 2
			_phase_transition_timer = 0.0
			can_be_interrupted = false
			
			# 動態設定轉場時間，使其與動畫長度同步
			if animated_sprite and animated_sprite.sprite_frames.has_animation("phase_transition"):
				# 修正：使用正確的公式（總幀數 / 播放速度）來計算動畫總時長
				var frame_count = animated_sprite.sprite_frames.get_frame_count("phase_transition")
				var speed = animated_sprite.sprite_frames.get_animation_speed("phase_transition")
				if speed > 0:
					self.phase_transition_duration = frame_count / speed
					print_debug("[GiantFish AI] Phase transition duration dynamically set to animation length: %.2f sec" % self.phase_transition_duration)
				else:
					printerr("'phase_transition' animation speed is 0. Falling back to default duration.")
			else:
				# 如果真的找不到動畫，使用預設值以防崩潰
				printerr("Could not find 'phase_transition' animation. Falling back to default duration.")
			
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
		{"name": ACTION_IDLE, 			"function_name": "_prepare_idle", 			"weight": 0.1, "min_cooldown": 0.5, "is_utility": true},
		{"name": ACTION_REPOSITION, 	"function_name": "_prepare_reposition", 	"weight": 0.5, "min_cooldown": 6.0, "is_utility": true},
		{"name": ACTION_SIDE_MOVE_ATTACK, "function_name": "_prepare_half_body_move", 	"weight": 1.0, "min_cooldown": 8.0, "tags": ["aggressive"]},
		{"name": ACTION_JUMP_ATTACK, 		"function_name": "_prepare_jump_attack", 		"weight": 1.0, "min_cooldown": 10.0, "tags": ["aggressive", "far_range"]},
		{"name": ACTION_TAIL_SWIPE_ATTACK, "function_name": "_prepare_tail_swipe_attack", "weight": 1.0, "min_cooldown": 6.0, "tags": ["close_range"]},
		{"name": ACTION_BUBBLE_ATTACK, 	"function_name": "_prepare_bubble_attack", 	"weight": 0.8, "min_cooldown": 5.0, "tags": []}
	]
	
	# 初始化 last_action_execution_times，確保所有動作在遊戲開始時都可以立即執行（如果條件允許）
	var current_time = Time.get_ticks_msec() / 1000.0
	for action_config in available_actions:
		var action_name = action_config.get("name")
		if action_name: # 確保 action_name 存在
			last_action_execution_times[action_name] = current_time - action_config.get("min_cooldown", 100.0) - 1.0 # 減去一個較大的間隔以允許首次執行


func _gfb_calculate_and_select_next_action() -> void:
	if current_state != GiantFishState.IDLE and not is_counter_attack_pending:
		return

	if is_in_combo:
		# 如果正在執行連招，則不應由計時器觸發新的獨立動作決策
		print_debug("[GiantFish AI] In combo, skipping normal action selection.")
		return

	var player_context = _get_player_context()

	# --- 策略性連招決策 ---
	var potential_combos = []
	for combo_name in combo_library.keys():
		var combo_info = combo_library[combo_name]
		if combo_info.get("condition", func(): return false).call():
			potential_combos.append(combo_name)
	
	if not potential_combos.is_empty():
		var selected_combo = potential_combos[randi() % potential_combos.size()]
		# 檢查連招的第一個動作是否可用
		var first_action_name = combo_library[selected_combo]["actions"][0]
		var current_time = Time.get_ticks_msec() / 1000.0
		var last_time = last_action_execution_times.get(first_action_name, 0.0)
		var config = available_actions.filter(func(a): return a.name == first_action_name)[0]
		
		if current_time - last_time >= config.get("min_cooldown", 0.0):
			print_debug("[GiantFish AI] Condition met for combo: %s. Starting." % selected_combo)
			_start_combo(selected_combo)
			return

	# --- 單一行動決策邏輯 ---
	var action_scores: Dictionary = {}
	var total_score: float = 0.0
	var debug_strings: Array[String] = []
	var current_time = Time.get_ticks_msec() / 1000.0

	for action_config in available_actions:
		var action_name = action_config.get("name")
		var score = float(action_config.get("weight", 0.0))
		var reason = "Base:%.2f" % score

		# 1. 硬性條件過濾 (冷卻)
		var min_cooldown = action_config.get("min_cooldown", 0.0)
		var time_since_last = current_time - last_action_execution_times.get(action_name, -999.0)
		if time_since_last < min_cooldown:
			continue

		# 2. 動態權重調整
		# A. 柔性冷卻 & 最近使用懲罰
		if last_action_name == action_name:
			score *= 0.25 # 大幅降低剛用過的招式的權重
			reason += "*0.25(LastUsed)"
		else:
			# 剛脫離冷卻期的招式，權重較低，隨時間線性恢復
			var time_over_cooldown = time_since_last - min_cooldown
			var recovery_factor = clamp(time_over_cooldown / 5.0, 0.3, 1.0) # 5秒內恢復到100%權重
			score *= recovery_factor
			reason += "*%.2f(CooldownRecovery)" % recovery_factor

		# B. 基於血量的攻擊性
		var health_percent = current_health / initial_max_health
		if health_percent < 0.5 and action_config.get("tags", []).has("aggressive"):
			score *= 1.5 # 血量低於50%，攻擊性招式權重增加
			reason += "*1.5(LowHealth)"
		
		# C. 根據玩家距離
		if player_context.is_valid:
			if player_context.is_close and action_config.get("tags", []).has("close_range"):
				score *= 2.0; reason += "*2.0(PlayerClose)"
			if player_context.is_far and action_config.get("tags", []).has("far_range"):
				score *= 2.0; reason += "*2.0(PlayerFar)"
		
		# D. 避免連續待機
		if consecutive_idle_count >= 1 and action_config.get("is_utility", false):
			score *= 0.1 # 如果上次是待機，大幅降低工具性招式（包括待機）的權重
			reason += "*0.1(AvoidIdle)"

		action_scores[action_name] = score
		total_score += score
		debug_strings.append("- '%s' score: %.2f (%s)" % [action_name, score, reason])

	# ... (與之前類似的選擇邏輯)
	if total_score <= 0:
		_prepare_action_by_state(ACTION_IDLE) # 如果沒招可用，就待機
		return

	var random_value = randf() * total_score
	var cumulative_score: float = 0.0
	var selected_action: String = ""

	for action_name in action_scores.keys():
		cumulative_score += action_scores[action_name]
		if random_value <= cumulative_score:
			selected_action = action_name
			break
	
	if selected_action.is_empty(): selected_action = action_scores.keys()[0]

	print("\n[GiantFish AI] --- Action Decision ---")
	print("Player Context: " + str(player_context))
	for s in debug_strings: print(s)
	print("=> Selected Action: %s" % selected_action)

	if selected_action == ACTION_IDLE:
		consecutive_idle_count += 1
	else:
		consecutive_idle_count = 0

	last_action_name = selected_action # 記錄本次執行的動作
	_prepare_action_by_state(selected_action)


func _prepare_action_by_state(action_name: String) -> void:
	last_action_execution_times[action_name] = Time.get_ticks_msec() / 1000.0
	match action_name:
		ACTION_IDLE:
			_prepare_idle()
		ACTION_REPOSITION:
			_prepare_reposition()
		ACTION_SIDE_MOVE_ATTACK:
			_prepare_half_body_move()
		ACTION_JUMP_ATTACK:
			_prepare_jump_attack()
		ACTION_TAIL_SWIPE_ATTACK:
			_prepare_tail_swipe_attack()
		ACTION_BUBBLE_ATTACK:
			_prepare_bubble_attack()
		_:
			printerr("[GFB _prepare_action] Error: Unknown action '%s'" % action_name)
			_change_state(GiantFishState.IDLE)


func _is_state_an_attack(state: int) -> bool:
	return state in [
		GiantFishState.EMERGE_JUMP,
		GiantFishState.TAIL_SWIPE,
		GiantFishState.BUBBLE_ATTACK_STATE,
		GiantFishState.REPOSITION_STATE
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
		GiantFishState.PHASE_TRANSITION:
			# 修正為正確的動畫名稱
			return "phase_transition"
		GiantFishState.REPOSITION_STATE:
			return "move" 
		_:
			return super.get_current_animation_name()
#endregion
