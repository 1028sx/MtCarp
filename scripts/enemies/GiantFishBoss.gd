extends Boss

class_name GiantFishBoss

#region 行動名稱常量
const ACTION_IDLE = "Idle"
const ACTION_SIDE_MOVE_ATTACK = "SideMoveAttack" 
const ACTION_JUMP_ATTACK = "JumpAttack"        
const ACTION_TAIL_SWIPE_ATTACK = "TailSwipeAttack"
const ACTION_BUBBLE_ATTACK = "BubbleAttack"
#endregion

#region 巨魚特有狀態
enum GiantFishState {
	IDLE = BossState.IDLE,
	APPEAR = BossState.APPEAR,
	MOVE = BossState.MOVE, 
	HURT = BossState.HURT,
	DEFEATED = BossState.DEFEATED,
	PHASE_TRANSITION = BossState.PHASE_TRANSITION,

	_GIANT_FISH_SPECIFIC_STATES_START_ = BossState.MAX_BOSS_STATES, # 確保從父類最大值後開始
	# 跳躍攻擊子狀態
	DIVE = _GIANT_FISH_SPECIFIC_STATES_START_,
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
#endregion

#region 巨魚特有屬性
@export_group("Giant Fish Behavior")
@export var dive_duration: float = 1.0
@export var submerged_move_speed: float = 300.0
@export var submerged_move_timeout: float = 5.0
@export var emerge_jump_height: float = -500.0
@export var emerge_horizontal_speed: float = 100.0
@export var tail_swipe_duration: float = 1.5
@export var bubble_attack_duration: float = 1.0
@export var bubbles_per_attack_phase1: int = 5
@export var bubbles_per_attack_phase2: int = 7

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

var half_body_move_direction: int = 1
var half_body_moves_done: int = 0
var half_body_move_pause_timer: float = 0.0
var half_body_move_pause_duration: float = 1.0

var action_has_spawned_bubbles_in_phase2: bool = false

# 權重系統變數
var available_actions: Array[Dictionary] = []
var last_action_execution_times: Dictionary = {}
var initial_max_health: float = 0.0
#endregion


func _ready() -> void:
	super._ready()
	initial_max_health = max_health
	can_be_interrupted = false
	current_state = GiantFishState.IDLE 
	mercy_period_timer = mercy_period
	_initialize_available_actions() 
	
	# 設定基礎攻擊冷卻時間為1秒
	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = 1.0 

	# 初始化每個動作的上次執行時間，以確保min_interval在遊戲開始時正確運作
	var current_time_init = Time.get_ticks_msec() / 1000.0
	for action_config in available_actions:
		var action_name = action_config.get("name")
		if action_name and action_name != ACTION_IDLE: 
			last_action_execution_times[action_name] = current_time_init - action_config.get("min_interval", 100.0) - 1.0


func _physics_process(delta: float) -> void:
	# Print current state NAME at the beginning of every physics process
	var state_name = "UNKNOWN_STATE"
	var state_key_found = GiantFishState.keys()[GiantFishState.values().find(current_state)] if GiantFishState.values().has(current_state) else null
	if state_key_found:
		state_name = state_key_found
	else: # Fallback for states not in GiantFishState (e.g. raw int from BossState if enum values mismatch)
		state_key_found = BossState.keys()[BossState.values().find(current_state)] if BossState.values().has(current_state) else null
		if state_key_found:
			state_name = "BossState." + state_key_found # Indicate it's from BossState
		else:
			state_name = "RAW_INT_" + str(current_state)
	# print("[GFB _physics_process] Current State: ", state_name, ", Frame: ", Engine.get_physics_frames()) # Reduced verbosity

	if current_state == GiantFishState.DEFEATED:
		return

	# 日誌：super._physics_process 之前
	# if current_state == GiantFishState.SIDE_MOVE_ATTACK_STATE: # Reduced verbosity
		# print("[GFB _physics_process] Velocity BEFORE super._physics_process: ", velocity, ", State: SIDE_MOVE_ATTACK_STATE") # Reduced verbosity

	super._physics_process(delta)

	# 日誌：super._physics_process 之後
	# if current_state == GiantFishState.SIDE_MOVE_ATTACK_STATE: # Reduced verbosity
		# print("[GFB _physics_process] Velocity AFTER super._physics_process: ", velocity, ", State: SIDE_MOVE_ATTACK_STATE") # Reduced verbosity

	_update_mercy_mechanism(delta)

	match current_state:
		GiantFishState.IDLE:
			_process_idle_state(delta)
		GiantFishState.SIDE_MOVE_ATTACK_STATE: # Corrected enum usage
			_giant_fish_side_move_attack_state(delta) 
		GiantFishState.DIVE:
			_giant_fish_dive_state(delta)
		GiantFishState.SUBMERGED_MOVE:
			_giant_fish_submerged_move_state(delta)
		GiantFishState.EMERGE_JUMP:
			_giant_fish_emerge_jump_state(delta)
		GiantFishState.TAIL_SWIPE: 
			_giant_fish_tail_swipe_state(delta) 
		GiantFishState.BUBBLE_ATTACK_STATE: # Corrected enum usage
			_giant_fish_bubble_attack_state(delta) 
		# Ensure all other GiantFishState enum values inherited from BossState are handled by super or here if specific logic needed
		GiantFishState.APPEAR, GiantFishState.MOVE, GiantFishState.HURT, GiantFishState.PHASE_TRANSITION:
			# Let superclass handle or add specific logic if any
			pass # Assuming super._physics_process handles the logic for these states if not overridden by specific _giant_fish_..._state_logic


#region 狀態處理函式
func _process_idle_state(delta: float) -> void:
	# GiantFishBoss 自己的 IDLE 邏輯
	# print("[GFB _process_idle_state] Custom GFB IDLE logic executing. Frame: ", Engine.get_physics_frames()) # Reduced verbosity
	velocity.x = move_toward(velocity.x, 0, deceleration * delta) # 保持減速

	# DEBUG: Check target_player validity
	var is_player_valid = is_instance_valid(target_player)
	var current_state_name_for_check = "UNKNOWN"
	var state_key_idx = GiantFishState.values().find(current_state)
	if state_key_idx != -1:
		current_state_name_for_check = GiantFishState.keys()[state_key_idx]
	
	# Only log this debug print when IDLE and attack is on cooldown, to reduce spam when it's correctly waiting for cooldown.
	if current_state == GiantFishState.IDLE and not attack_cooldown_timer.is_stopped():
		print("[GFB IDLE DEBUG] PlayerValid: ", is_player_valid, ", IsAttacking: false (on cooldown), Frame: ", Engine.get_physics_frames())


	if not is_player_valid or \
		current_state == GiantFishState.APPEAR or \
		current_state == GiantFishState.PHASE_TRANSITION or \
		current_state == GiantFishState.HURT or \
		current_state == GiantFishState.DEFEATED:
		print("[GFB _process_idle_state] Invalid conditions for action selection (PlayerValid: ", is_player_valid, ", CurrentStateForCheck: ", current_state_name_for_check, "). Returning. Frame: ", Engine.get_physics_frames()) # Keep this useful log, now with more info
		return

	if attack_cooldown_timer.is_stopped():
		# print("[GFB _process_idle_state] Attack cooldown stopped. Calling _calculate_and_select_next_action().") # Reduced verbosity
		_calculate_and_select_next_action()
		var state_key_after_calc = GiantFishState.keys()[GiantFishState.values().find(current_state)] if GiantFishState.values().has(current_state) else "UNKNOWN (" + str(current_state) + ")"
		# print("[GFB _process_idle_state] After _calculate_and_select_next_action(), current_state is: ", state_key_after_calc) # Reduced verbosity
	# else: # Reduced verbosity
		# print("[GFB _process_idle_state] Attack cooldown is active (Time left: ", attack_cooldown_timer.time_left, ")") # Reduced verbosity
	
	# 注意：這裡不再呼叫 super._process_idle_state(delta) 
	# 因為父類的該方法會無條件在有 target_player 時轉換到 MOVE，這正是我們要避免的。
	# 我們希望攻擊選擇完全由 _calculate_and_select_next_action 控制。
	# 如果 _calculate_and_select_next_action 沒有改變狀態，BOSS 將保持 IDLE 直到冷卻結束可以再次選擇。

func _giant_fish_idle_state(delta: float):
	# 這個函式現在實際上被下面覆寫的 _process_idle_state 取代了
	# 為了清晰和避免混淆，我們可以考慮將其邏輯合併到 _process_idle_state
	# 或者確保 _physics_process 的 match current_state: GiantFishState.IDLE: 分支
	# 正確地呼叫 _process_idle_state(delta) 而不是 _giant_fish_idle_state(delta)
	# 目前日誌顯示 _physics_process 中 IDLE 狀態會呼叫 _giant_fish_idle_state(delta) -- Correction: it calls _process_idle_state
	# 我們需要將其改為呼叫 _process_idle_state(delta)
	
	# 暫時保留原有的日誌，以便觀察是否還會被意外呼叫
	# print("[GFB _giant_fish_idle_state] DEPRECATED? - Attack cooldown stopped. Calling _calculate_and_select_next_action(). Frame: ", Engine.get_physics_frames()) # Reduced verbosity
		_calculate_and_select_next_action() # 呼叫新的函式
		var state_key_after_calc = GiantFishState.keys()[GiantFishState.values().find(current_state)] if GiantFishState.values().has(current_state) else "UNKNOWN (" + str(current_state) + ")"
	# print("[GFB _giant_fish_idle_state] DEPRECATED? - After _calculate_and_select_next_action(), current_state is: ", state_key_after_calc) # Reduced verbosity


func _giant_fish_side_move_attack_state(delta: float):
	# print("[GFB SideMove State] Frame: ", Engine.get_physics_frames(), ", X: ", global_position.x, ", IsOnWall: ", is_on_wall(), ", VelX: ", velocity.x, ", Dir: ", half_body_move_direction, ", MovesDone: ", half_body_moves_done) # Reduced verbosity

	if is_on_wall():
		print("[GFB SideMove State] Wall HIT! X: ", global_position.x, ", Vel.x BEFORE effective zeroing: ", velocity.x, ", Dir: ", half_body_move_direction) # Keep
		velocity.x = 0 
		# print("[GFB SideMove State] Velocity.x AFTER set to 0 (Wall Hit): ", velocity.x) # Reduced verbosity
		half_body_moves_done += 1

		var max_moves = 2 
		if is_phase_two:
			max_moves = 4 

		if is_phase_two and not action_has_spawned_bubbles_in_phase2:
			_spawn_bubbles_for_action()
			action_has_spawned_bubbles_in_phase2 = true
		
		if half_body_moves_done >= max_moves:
			print("[GFB SideMove State] Max moves reached (", half_body_moves_done, "/", max_moves, "). Changing to IDLE.") # Keep
			_change_state(GiantFishState.IDLE)
			return # This return is correct, attack sequence is finished.
		else:
			print("[GFB SideMove State] Wall hit, turning around. Moves done: ", half_body_moves_done, "/", max_moves) # Keep
			half_body_move_direction *= -1
			if animated_sprite: animated_sprite.flip_h = half_body_move_direction < 0
		action_has_spawned_bubbles_in_phase2 = false
			# print("[GFB SideMove State] Velocity.x AFTER turn around (still should be 0 before next frame's move): ", velocity.x) # Reduced verbosity
			# REMOVED RETURN: No longer returning here, allow velocity to be set for new direction.
			# return 

	velocity.x = half_body_move_direction * move_speed * 4.0 
	# print("[GFB SideMove State] Velocity.x JUST AFTER assignment: ", velocity.x, ", move_speed: ", move_speed, ", dir: ", half_body_move_direction) # Reduced verbosity
	# print("[GFB SideMove State] Velocity AFTER Apply. vel.x: ", velocity.x, ", move_speed: ", move_speed, ", dir: ", half_body_move_direction, ", EffectiveSpeed: ", move_speed * 4.0) # Reduced verbosity


func _giant_fish_dive_state(_delta: float):
	pass


func _giant_fish_submerged_move_state(delta: float):
	if target_player:
		pass
	
	global_position = global_position.move_toward(submerged_move_target_position, submerged_move_speed * delta)
	submerged_move_current_timer += delta

	if global_position.distance_to(submerged_move_target_position) < 10.0 or submerged_move_current_timer >= submerged_move_timeout:
		_prepare_emerge_jump()


func _giant_fish_emerge_jump_state(_delta: float):
	if is_on_floor() and velocity.y >= 0:
		velocity.y = 0


func _giant_fish_tail_swipe_state(_delta: float):
	pass


func _giant_fish_bubble_attack_state(_delta: float):
	if is_phase_two:
		_change_state(GiantFishState.IDLE)
		return
	pass

#endregion

#region 攻擊準備/執行函式
func _prepare_jump_attack():
	if not target_player: return
	submerged_move_target_position = Vector2(target_player.global_position.x, global_position.y)
	submerged_move_current_timer = 0.0
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.DIVE)
	attack_cooldown_timer.start()

func _prepare_tail_swipe_attack():
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.TAIL_SWIPE)
	attack_cooldown_timer.start()

func _prepare_bubble_attack():
	if is_phase_two: return
	_change_state(GiantFishState.BUBBLE_ATTACK_STATE)
	attack_cooldown_timer.start()

func _prepare_half_body_move():
	half_body_moves_done = 0
	half_body_move_pause_timer = 0.0
	
	# 恢復根據玩家位置決定初始方向的邏輯
	if target_player and is_instance_valid(target_player):
		half_body_move_direction = 1 if target_player.global_position.x > global_position.x else -1
	else:
		# 如果沒有目標玩家，隨機一個方向
		half_body_move_direction = 1 if randf() > 0.5 else -1
	
	print("[GFB _prepare_half_body_move] Initializing. Direction set to: ", half_body_move_direction, " towards player (if exists).")
	
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.SIDE_MOVE_ATTACK_STATE) 
	print("[GFB _prepare_half_body_move] State CHANGED. current_state: ", GiantFishState.keys()[GiantFishState.values().find(current_state)] if GiantFishState.values().has(current_state) else current_state )

func _prepare_emerge_jump():
	action_has_spawned_bubbles_in_phase2 = false
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
		var horizontal_velocity = horizontal_velocity_magnitude * (-1 if direction_is_left else 1)
		var vertical_velocity = -300.0
		if splash.has_method("launch"):
			splash.launch(Vector2(horizontal_velocity, vertical_velocity))


func _spawn_wave():
	if not wave_scene:
		push_error("Wave Scene not set!")
		return

	var spawn_point_node = $WaveSpawnPoint
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	
	var wave = wave_scene.instantiate()
	get_tree().current_scene.add_child(wave)
	wave.global_position = spawn_pos
	var wave_direction = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT
	if wave.has_method("init_movement"):
		wave.init_movement(wave_direction)


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
		var damage_factor = clamp(damage_dealt_in_mercy_period / (max_health * 0.1), 0.0, 1.0)
		current_aggression_factor = 1.0 - (damage_factor * max_aggression_reduction_factor)
		
		damage_dealt_in_mercy_period = 0.0
		mercy_period_timer = mercy_period


func take_damage(amount: float, attacker: Node = null) -> void:
	if current_state == GiantFishState.DEFEATED : return

	if mercy_period_timer > 0:
		damage_dealt_in_mercy_period += amount

	super.take_damage(amount, attacker)

	if not is_phase_two and current_health <= max_health * 0.5:
		_enter_phase_two()


func _enter_phase_two():
	if is_phase_two: return
	is_phase_two = true
	current_phase = 2
	emit_signal("phase_changed", 2)
	print("Giant Fish Boss has entered Phase Two!")

#endregion

#region 狀態改變
func _change_state(new_state):
	var _old_state_name_gf = "UNKNOWN_GF_STATE"
	var old_state_idx = GiantFishState.values().find(current_state)
	if old_state_idx != -1:
		_old_state_name_gf = GiantFishState.keys()[old_state_idx]
	
	var _new_state_name_gf = "UNKNOWN_GF_STATE"
	var new_state_idx = GiantFishState.values().find(new_state)
	if new_state_idx != -1:
		_new_state_name_gf = GiantFishState.keys()[new_state_idx]
	
	print("[GFB _change_state] Attempting to change from '", _old_state_name_gf, "' (",current_state,") to '", _new_state_name_gf, "' (raw new_state: ", new_state, "). Frame: ", Engine.get_physics_frames())
	super._change_state(new_state)

	match current_state:
		GiantFishState.SUBMERGED_MOVE:
			submerged_move_current_timer = 0.0
			if target_player:
				submerged_move_target_position = Vector2(target_player.global_position.x, global_position.y)
		GiantFishState.IDLE:
			action_has_spawned_bubbles_in_phase2 = false
		GiantFishState.EMERGE_JUMP:
			velocity.y = emerge_jump_height
			_spawn_bubbles_if_phase_two_and_not_spawned()
		GiantFishState.TAIL_SWIPE:
			action_has_spawned_bubbles_in_phase2 = false
		GiantFishState.BUBBLE_ATTACK_STATE:
			if not is_phase_two:
				pass
			else:
				super._change_state(GiantFishState.IDLE)
		GiantFishState.HURT:
			pass
		GiantFishState.DEFEATED:
			pass
#endregion

#region 動畫回調
func _on_animation_finished():
	super._on_animation_finished()
	var completed_anim_name = ""
	if animated_sprite and animated_sprite.animation != null:
		completed_anim_name = animated_sprite.animation
	
	var handled_by_giant_fish = true
	match completed_anim_name:
		"dive_in":
			if current_state == GiantFishState.DIVE:
				_change_state(GiantFishState.SUBMERGED_MOVE)
			else: handled_by_giant_fish = false
		"emerge_jump":
			if current_state == GiantFishState.EMERGE_JUMP:
				_change_state(GiantFishState.IDLE)
				action_has_spawned_bubbles_in_phase2 = false
			else: handled_by_giant_fish = false
		"tail_swipe":
			if current_state == GiantFishState.TAIL_SWIPE:
				_change_state(GiantFishState.IDLE)
				action_has_spawned_bubbles_in_phase2 = false
			else: handled_by_giant_fish = false
		"bubble_attack":
			if current_state == GiantFishState.BUBBLE_ATTACK_STATE and not is_phase_two:
				_spawn_bubbles_for_action()
				_change_state(GiantFishState.IDLE)
			else: handled_by_giant_fish = false
		_:
			handled_by_giant_fish = false

	if not handled_by_giant_fish:
		pass
	else:
		pass

#endregion

#region 動畫名稱管理
func get_current_animation_name() -> String:
	match current_state:
		GiantFishState.IDLE:
			return "idle"
		GiantFishState.MOVE:
			return "move"
		GiantFishState.DIVE:
			return "dive_in"
		GiantFishState.SUBMERGED_MOVE:
			if target_player and is_instance_valid(target_player) and animated_sprite:
				if submerged_move_target_position.x < global_position.x:
					animated_sprite.flip_h = true
				else:
					animated_sprite.flip_h = false
			return "dive_move"
		GiantFishState.EMERGE_JUMP:
			return "emerge_jump"
		GiantFishState.TAIL_SWIPE:
			return "tail_swipe"
		GiantFishState.BUBBLE_ATTACK_STATE:
			if not is_phase_two:
				return "bubble_attack"
			else:
				return super.get_current_animation_name()
		GiantFishState.HURT:
			return "idle"
		GiantFishState.DEFEATED:
			return "defeat"

	var parent_animation = super.get_current_animation_name()
	if parent_animation != "" :
		return parent_animation
	else:
		return "idle"
#endregion

#region 輔助方法
func _spawn_bubbles_if_phase_two_and_not_spawned():
	if is_phase_two and not action_has_spawned_bubbles_in_phase2:
		_spawn_bubbles_for_action()
		action_has_spawned_bubbles_in_phase2 = true
	else:
		pass
#endregion

func _initialize_available_actions() -> void:
	available_actions = [
		{
			"name": ACTION_IDLE,
			"state_to_enter": GiantFishState.IDLE,
			"base_weight": 0.1, # IDLE的權重應非常低或不參與選擇 (原為5.0)
			"min_interval": 0.0,
			"conditions": []
		},
		{
			"name": ACTION_SIDE_MOVE_ATTACK, # 高頻/常用，主要看條件
			"state_to_enter": GiantFishState.SIDE_MOVE_ATTACK_STATE,
			"base_weight": 10000.0, # 臨時提高以確保選中 (原為120.0)
			"min_interval": 0.5, 
			"conditions": [
				{ "type": "player_distance", "min_dist": 0, "max_dist": 150, "modifier_type": "multiply", "value": 0.4 },   # 過近時降低權重
				{ "type": "player_distance", "min_dist": 151, "max_dist": 600, "modifier_type": "multiply", "value": 1.4 }, # 主要作戰距離
				{ "type": "player_distance", "min_dist": 601, "max_dist": INF, "modifier_type": "multiply", "value": 2.0 },  # 遠距離追擊
				{ "type": "current_phase", "phase": 2, "modifier_type": "add", "value": 30.0 }, # 二階段時更傾向衝刺
			]
		},
		{
			"name": ACTION_TAIL_SWIPE_ATTACK, # 高頻/常用，主要看條件
			"state_to_enter": GiantFishState.TAIL_SWIPE,
			"base_weight": 1.0, # 臨時降低 (原為110.0)
			"min_interval": 1.0, # 降低min_interval使其更頻繁
			"conditions": [
				{ "type": "player_distance", "min_dist": 0, "max_dist": 250, "modifier_type": "multiply", "value": 1.8 }, # 近戰核心
				{ "type": "player_distance", "min_dist": 251, "max_dist": 400, "modifier_type": "multiply", "value": 1.2 }, # 中近距離
				{ "type": "current_phase", "phase": 2, "modifier_type": "multiply", "value": 1.3 }, # 二階段強化
				{ "type": "boss_health_below_percent", "threshold": 0.4, "modifier_type": "add", "value": 25.0} # 低血量時更傾向使用
			]
		},
		{
			"name": ACTION_JUMP_ATTACK, # 低頻/大招，主要看時間
			"state_to_enter": GiantFishState.DIVE,
			"base_weight": 1.0, # 臨時降低 (原為70.0)
			"min_interval": 7.0, 
			"override_cooldown": 1.5, 
			"conditions": [
				{ "type": "player_distance", "min_dist": 300, "max_dist": 700, "modifier_type": "multiply", "value": 1.2 }, 
				{ "type": "current_phase", "phase": 2, "modifier_type": "add", "value": 30.0 },
			]
		},
		{
			"name": ACTION_BUBBLE_ATTACK, # 低頻/控場，主要看時間
			"state_to_enter": GiantFishState.BUBBLE_ATTACK_STATE,
			"base_weight": 1.0, # 臨時降低 (原為60.0)
			"min_interval": 10.0, 
			"override_cooldown": 1.0, 
			"conditions": [
				{ "type": "action_only_in_phase", "phase": 1 },
				{ "type": "random_chance", "chance": 0.7, "modifier_type": "multiply", "value": 1.1 } 
			]
		}
	]

	# 注意：下面這段 last_action_execution_times 的初始化邏輯已移至 _ready() 函式，
	# 以確保在 attack_cooldown_timer.wait_time 可能被修改後執行。
	# 保留此註釋作為記錄。

	# 原有的條件權重計算邏輯保持不變 (此循環用於靜態分析或早期版本，實際選擇在_calculate_and_select_next_action中)
	for action_config in available_actions:
		var current_action_weight: float = action_config.get("base_weight", 0.0)
		var action_name: String = action_config.get("name", "")

		if current_action_weight <= 0 or action_name == "":
			continue

		if current_action_weight <= 0:
			continue

		var conditions: Array = action_config.get("conditions", [])
		for condition_data in conditions:
			var condition_type: String = condition_data.get("type", "")
			var modifier_type: String = condition_data.get("modifier_type", "multiply")
			var condition_value = condition_data.get("value", 0.0)
			var condition_met: bool = false

			match condition_type:
				"player_distance":
					var min_dist: float = condition_data.get("min_dist", 0.0)
					var max_dist: float = condition_data.get("max_dist", INF)
					if target_player and is_instance_valid(target_player):
						var dist_sq: float = global_position.distance_squared_to(target_player.global_position)
						if dist_sq >= min_dist * min_dist and dist_sq <= max_dist * max_dist:
							condition_met = true
				
				"boss_health_below_percent":
					var threshold_percent: float = condition_data.get("threshold", 0.5)
					if get_health_percentage() < threshold_percent:
						condition_met = true
				
				"player_health_below_percent":
					var p_threshold_percent: float = condition_data.get("threshold", 0.5)
					if target_player and target_player.has_method("get_health_percentage"):
						if target_player.get_health_percentage() < p_threshold_percent:
							condition_met = true
							
				"current_phase":
					var required_phase: int = condition_data.get("phase", 1)
					if current_phase == required_phase:
						condition_met = true
						
				"action_only_in_phase":
					var allowed_phase: int = condition_data.get("phase", 1)
					if current_phase != allowed_phase:
						current_action_weight = 0.0
						break
					else:
						condition_met = true

				"random_chance":
					var chance: float = condition_data.get("chance", 0.5)
					if randf() < chance:
						condition_met = true
						
				_:
					push_warning("GiantFishBoss: Unknown condition type '%s' for action '%s'" % [condition_type, action_name])

			if current_action_weight <=0:
				break


			if condition_met:
				match modifier_type:
					"multiply":
						current_action_weight *= condition_value
					"add":
						current_action_weight += condition_value
					"set":
						current_action_weight = condition_value
					_:
						push_warning("GiantFishBoss: Unknown modifier type '%s' for action '%s'" % [modifier_type, action_name])
			
			if current_action_weight < 0 and modifier_type != "set":
				current_action_weight = 0.0


		if current_action_weight > 0:
			pass

func _prepare_action_by_state(state_enum_val: int):
	action_has_spawned_bubbles_in_phase2 = false

	var selected_action_config: Dictionary = {}
	for config in available_actions:
		if config.get("state_to_enter") == state_enum_val:
			selected_action_config = config
			break
	
	var state_name_to_prepare = GiantFishState.keys()[GiantFishState.values().find(state_enum_val)] if GiantFishState.values().has(state_enum_val) else "UNKNOWN_STATE_ENUM (" + str(state_enum_val) + ")"
	print("[GFB _prepare_action_by_state] Preparing GFB action for state: ", state_name_to_prepare)

	match state_enum_val:
		GiantFishState.SIDE_MOVE_ATTACK_STATE:
			_prepare_half_body_move()
		GiantFishState.DIVE: 
			_prepare_jump_attack()
		GiantFishState.TAIL_SWIPE:
			_prepare_tail_swipe_attack()
		GiantFishState.BUBBLE_ATTACK_STATE:
			_prepare_bubble_attack()
		_:
			push_warning("GiantFishBoss: _prepare_action_by_state called with unhandled state: " + str(state_enum_val))
			_change_state(GiantFishState.IDLE) 
			return

	if state_enum_val != GiantFishState.IDLE:
		var cooldown_duration = attack_cooldown
		if selected_action_config.has("override_cooldown"):
			cooldown_duration = selected_action_config.get("override_cooldown")
		attack_cooldown_timer.start(cooldown_duration)

func get_health_percentage() -> float: # Add this method for the boss itself
	if initial_max_health > 0: # Assuming initial_max_health is the true max, max_health might change in phases
		return current_health / initial_max_health
	return 0.0

#region 行為選擇邏輯 (Behavior Selection Logic)
func _calculate_and_select_next_action() -> void:
	# print("[GFB _calculate_and_select_next_action] CALLED. Frame: ", Engine.get_physics_frames()) # Reduced verbosity
	var weighted_actions: Array[Dictionary] = []
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if not target_player or not is_instance_valid(target_player):
		print("[GFB _calculate_and_select_next_action] No valid target_player. Resetting attack_cooldown_timer if stopped.")
		if attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.start(attack_cooldown) 
		return

	for action_config in available_actions:
		var action_name: String = action_config.get("name", "")
		if action_name == "" or action_name == ACTION_IDLE:
			continue

		var current_action_weight: float = float(action_config.get("base_weight", 0.0))
		var min_interval: float = float(action_config.get("min_interval", 0.0))
		var last_execution_time: float = float(last_action_execution_times.get(action_name, -INF))

		var debug_action_logs: String = "" # Keep var for potential future use, but don't print by default
		if action_name == ACTION_SIDE_MOVE_ATTACK:
			debug_action_logs += "[GFB CalcSelect] Evaluating " + action_name + ": BaseWeight=" + str(current_action_weight) + ", MinInterval=" + str(min_interval) + ", LastExec=" + str(last_execution_time) + ", CurrentTime=" + str(current_time)

		if current_time - last_execution_time < min_interval:
			# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += " -> Interval NOT met. Weight=0." # Reduced verbosity
			current_action_weight = 0.0
		# else: # Reduced verbosity
			# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += " -> Interval MET." # Reduced verbosity
		
		if current_action_weight <= 0:
			# if action_name == ACTION_SIDE_MOVE_ATTACK and debug_action_logs != "": print(debug_action_logs) # Reduced verbosity
			continue

		var conditions: Array = action_config.get("conditions", [])
		for condition_data in conditions:
			var condition_type: String = condition_data.get("type", "")
			var modifier_type: String = condition_data.get("modifier_type", "multiply")
			var condition_value_raw = condition_data.get("value") 
			var condition_met: bool = false
			var original_weight_before_condition = current_action_weight

			# Simplified condition evaluation for logging clarity when it's ACTION_SIDE_MOVE_ATTACK
			var dist_sq: float = -1.0
			if target_player and is_instance_valid(target_player):
				dist_sq = global_position.distance_squared_to(target_player.global_position)

			match condition_type:
				"player_distance":
					var min_dist: float = condition_data.get("min_dist", 0.0)
					var max_dist: float = condition_data.get("max_dist", INF)
					if dist_sq != -1.0 and dist_sq >= min_dist * min_dist and dist_sq <= max_dist * max_dist:
							condition_met = true
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (" + str(min_dist) + "-" + str(max_dist) + "), PlayerDistSq: " + str(dist_sq) + ", Met: " + str(condition_met) # Reduced verbosity
				
				"boss_health_below_percent":
					var threshold_percent: float = condition_data.get("threshold", 0.5)
					if get_health_percentage() < threshold_percent:
						condition_met = true
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (<" + str(threshold_percent*100) + "%), Met: " + str(condition_met) # Reduced verbosity
				
				"player_health_below_percent":
					var p_threshold_percent: float = condition_data.get("threshold", 0.5)
					if target_player and target_player.has_method("get_health_percentage"):
						if target_player.call("get_health_percentage") < p_threshold_percent:
							condition_met = true
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (<" + str(p_threshold_percent*100) + "%), Met: " + str(condition_met) # Reduced verbosity
							
				"current_phase":
					var required_phase: int = condition_data.get("phase", 1)
					if self.current_phase == required_phase:
						condition_met = true
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (==" + str(required_phase) + "), ActualPhase: " + str(self.current_phase) + ", Met: " + str(condition_met) # Reduced verbosity
						
				"action_only_in_phase":
					var allowed_phase: int = condition_data.get("phase", 1)
					if self.current_phase != allowed_phase:
						current_action_weight = 0.0 
					condition_met = (self.current_phase == allowed_phase) # for logging 'Met' status
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (phase " + str(allowed_phase) + "), ActualPhase: " + str(self.current_phase) + ", Met: " + str(condition_met) + ((" -> Weight=0" if not condition_met else "")) # Reduced verbosity
					if not condition_met: break 

				"random_chance":
					var chance: float = condition_data.get("chance", 0.5)
					if randf() < chance:
						condition_met = true
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: " + condition_type + " (" + str(chance*100) + "%), Met: " + str(condition_met) # Reduced verbosity
				_:
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += "\n  Cond: UNKNOWN TYPE '" + condition_type + "'" # Reduced verbosity
					push_warning("GiantFishBoss: 動作 '%s' 遇到未知條件類型 '%s'" % [action_name, condition_type])

			if current_action_weight <= 0: # Check if 'action_only_in_phase' zeroed it
				# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += " -> Weight became 0 due to condition. Breaking from conditions." # Reduced verbosity
				break 

			if condition_met:
				var mod_value_parsed: float = 0.0
				var valid_mod_value = false
				if typeof(condition_value_raw) == TYPE_FLOAT:
					mod_value_parsed = float(condition_value_raw)
					valid_mod_value = true
				elif typeof(condition_value_raw) == TYPE_INT:
					mod_value_parsed = float(condition_value_raw)
					valid_mod_value = true
				
				if valid_mod_value:
					match modifier_type:
						"multiply": current_action_weight *= mod_value_parsed
						"add": current_action_weight += mod_value_parsed
						"set": current_action_weight = mod_value_parsed
					# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += " -> Modified by " + modifier_type + " with " + str(mod_value_parsed) + ". NewWeight=" + str(current_action_weight) # Reduced verbosity
				# elif action_name == ACTION_SIDE_MOVE_ATTACK: # Reduced verbosity
					# debug_action_logs += " -> Invalid mod_value_raw: " + str(condition_value_raw) # Reduced verbosity
			
			if current_action_weight < 0.0 and modifier_type != "set":
				current_action_weight = 0.0
				# if action_name == ACTION_SIDE_MOVE_ATTACK: debug_action_logs += " -> Weight clamped to 0." # Reduced verbosity
		
		# if action_name == ACTION_SIDE_MOVE_ATTACK and debug_action_logs != "": print(debug_action_logs) # Reduced verbosity - Master toggle for the specific action's debug logs

		if current_action_weight > 0.0:
			weighted_actions.append({
				"name": action_name,
				"weight": current_action_weight,
				"state_to_enter": action_config.get("state_to_enter")
			})

	if weighted_actions.is_empty():
		print("[GFB _calculate_and_select_next_action] No valid actions in weighted_actions list. Boss will remain IDLE (or be handled by superclass).")
		if attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.start(attack_cooldown)
		return

	var total_weight: float = 0.0
	var action_list_for_log: Array = []
	for action_data in weighted_actions:
		total_weight += action_data.get("weight", 0.0)
		action_list_for_log.append(action_data.get("name") + ":" + str(action_data.get("weight")))
	
	print("[GFB _calculate_and_select_next_action] Weighted actions: ", action_list_for_log, ", TotalWeight: ", total_weight) # Keep

	if total_weight <= 0.0:
		print("[GFB _calculate_and_select_next_action] Total weight is zero or less. Boss will remain IDLE (or be handled by superclass).") # Keep
		if attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.start(attack_cooldown)
		return

	var random_pick: float = randf() * total_weight 
	var current_sum: float = 0.0
	var selected_action_data: Dictionary = {}

	for action_data in weighted_actions:
		current_sum += action_data.get("weight", 0.0)
		if random_pick <= current_sum: 
			selected_action_data = action_data
			break 
	
	if selected_action_data.is_empty():
		print("[GFB _calculate_and_select_next_action] ERROR: Weighted selection failed despite total_weight > 0.")
		if attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.start(attack_cooldown)
		return

	var state_to_enter = selected_action_data.get("state_to_enter")
	var action_to_log_name = selected_action_data.get("name")
	var state_to_enter_name = GiantFishState.keys()[GiantFishState.values().find(state_to_enter)] if GiantFishState.values().has(state_to_enter) else "UNKNOWN_STATE_ENUM (" + str(state_to_enter) + ")"

	print("[GFB _calculate_and_select_next_action] Selected action: '", action_to_log_name, "' -> To State: '", state_to_enter_name, "' (Raw state enum: ", state_to_enter, ")") # Keep

	if state_to_enter != null:
		last_action_execution_times[action_to_log_name] = current_time
		_prepare_action_by_state(state_to_enter)
	else:
		push_error("GiantFishBoss: 選定動作 '%s' 沒有定義 'state_to_enter'。" % action_to_log_name) # Keep
		if attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.start(attack_cooldown)

#endregion
