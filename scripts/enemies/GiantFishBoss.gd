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
	# GiantFishState.IDLE 和 BossState.IDLE 應該是相同的
	current_state = GiantFishState.IDLE 
	mercy_period_timer = mercy_period
	_initialize_available_actions() 


func _physics_process(delta: float) -> void:
	if current_state == GiantFishState.DEFEATED:
		return

	super._physics_process(delta)

	_update_mercy_mechanism(delta)

	match current_state:
		GiantFishState.IDLE:
			_giant_fish_idle_state(delta)
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
func _giant_fish_idle_state(delta: float):
	velocity.x = move_toward(velocity.x, 0, deceleration * delta)

	if not is_instance_valid(target_player) or \
		current_state == GiantFishState.APPEAR or \
		current_state == GiantFishState.PHASE_TRANSITION or \
		current_state == GiantFishState.HURT or \
		current_state == GiantFishState.DEFEATED:
		return

	if current_state == GiantFishState.IDLE and attack_cooldown_timer.is_stopped():
		var rand = randf()
		if rand < 0.3 * current_aggression_factor:
			_prepare_jump_attack()
		elif rand < 0.6 * current_aggression_factor:
			_prepare_tail_swipe_attack()
		elif rand < 0.8 * current_aggression_factor and not is_phase_two:
			_prepare_bubble_attack()
		else:
			_prepare_half_body_move()


func _giant_fish_side_move_attack_state(delta: float):
	if half_body_move_pause_timer > 0:
		half_body_move_pause_timer -= delta
		velocity.x = 0
		if half_body_move_pause_timer <=0:
			half_body_moves_done += 1
			var max_moves = 2 if is_phase_two else 1
			max_moves *= 2
			if half_body_moves_done >= max_moves:
				_change_state(GiantFishState.IDLE)
			else:
				half_body_move_direction *= -1
				if animated_sprite: animated_sprite.flip_h = half_body_move_direction < 0
		return

	velocity.x = half_body_move_direction * move_speed

	if is_on_wall():
		if is_phase_two and not action_has_spawned_bubbles_in_phase2:
			_spawn_bubbles_for_action()
			action_has_spawned_bubbles_in_phase2 = true
		
		half_body_move_pause_timer = half_body_move_pause_duration
		action_has_spawned_bubbles_in_phase2 = false


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
	if target_player:
		half_body_move_direction = 1 if target_player.global_position.x > global_position.x else -1
	else:
		half_body_move_direction = 1 if randf() > 0.5 else -1
	
	action_has_spawned_bubbles_in_phase2 = false
	_change_state(GiantFishState.MOVE)

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
			"base_weight": 15.0,
			"min_interval": 0.0,
			"conditions": []
		},
		{
			"name": ACTION_SIDE_MOVE_ATTACK,
			"state_to_enter": GiantFishState.SIDE_MOVE_ATTACK_STATE,
			"base_weight": 80.0,
			"min_interval": 8.0,
			"conditions": [
				{ "type": "player_distance", "min_dist": 700, "max_dist": INF, "modifier_type": "multiply", "value": 1.8 },
				{ "type": "player_distance", "min_dist": 500, "max_dist": 699, "modifier_type": "multiply", "value": 1.2 },
				{ "type": "current_phase", "phase": 2, "modifier_type": "add", "value": 10.0 },
			]
		},
		{
			"name": ACTION_JUMP_ATTACK,
			"state_to_enter": GiantFishState.DIVE,
			"base_weight": 100.0,
			"min_interval": 7.0,
			"conditions": [
				{ "type": "player_distance", "min_dist": 300, "max_dist": 700, "modifier_type": "multiply", "value": 1.6 },
				{ "type": "player_distance", "min_dist": 150, "max_dist": 299, "modifier_type": "multiply", "value": 0.7 },
				{ "type": "player_distance", "min_dist": 701, "max_dist": 1000, "modifier_type": "multiply", "value": 0.8 },
				{ "type": "current_phase", "phase": 2, "modifier_type": "add", "value": 30.0 },
			]
		},
		{
			"name": ACTION_TAIL_SWIPE_ATTACK,
			"state_to_enter": GiantFishState.TAIL_SWIPE,
			"base_weight": 110.0,
			"min_interval": 3.5,
			"conditions": [
				{ "type": "player_distance", "min_dist": 0, "max_dist": 250, "modifier_type": "multiply", "value": 1.7 },
				{ "type": "player_distance", "min_dist": 251, "max_dist": 400, "modifier_type": "multiply", "value": 1.1 },
				{ "type": "current_phase", "phase": 2, "modifier_type": "multiply", "value": 1.2 },
				{ "type": "boss_health_below_percent", "threshold": 0.4, "modifier_type": "add", "value": 20.0}
			]
		},
		{
			"name": ACTION_BUBBLE_ATTACK,
			"state_to_enter": GiantFishState.BUBBLE_ATTACK_STATE,
			"base_weight": 75.0,
			"min_interval": 8.0,
			"override_cooldown": 0.5,
			"conditions": [
				{ "type": "action_only_in_phase", "phase": 1 },
				{ "type": "player_distance", "min_dist": 100, "max_dist": 700, "modifier_type": "multiply", "value": 1.15 },
				{ "type": "random_chance", "chance": 0.6, "modifier_type": "multiply", "value": 1.2 }
			]
		}
	]

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

				"can_see_player":
					pass
				
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
