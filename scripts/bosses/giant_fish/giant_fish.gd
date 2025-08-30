extends "res://scripts/bosses/boss_base.gd"

class_name GiantFish

#region 常量定義
# 攻擊類型常量
const ACTION_IDLE = "Idle"
const ACTION_SIDE_MOVE_ATTACK = "SideMoveAttack" 
const ACTION_JUMP_ATTACK = "JumpAttack"        
const ACTION_TAIL_SWIPE_ATTACK = "TailSwipeAttack"
const ACTION_BUBBLE_ATTACK = "BubbleAttack"

# 平衡常量
const WATER_SPLASH_SPACING = 80.0
const PHASE_TWO_HEALTH_THRESHOLD = 0.5
const CLOSE_RANGE_DISTANCE = 250.0
const FAR_RANGE_DISTANCE = 600.0

# 攻擊冷卻時間
const ATTACK_COOLDOWNS = {
	ACTION_TAIL_SWIPE_ATTACK: 3.0,
	ACTION_BUBBLE_ATTACK: 4.0,
	ACTION_SIDE_MOVE_ATTACK: 6.0,
	ACTION_JUMP_ATTACK: 8.0
}

# 攻擊幀配置
const ATTACK_FRAMES = {
	"tail_swipe": {
		"attack_frame": 4       # 攻擊判定幀（生成波浪）
	},
	"bubble_attack": {
		"attack_frame": 3       # 泡泡發射幀
	},
	"move": {  # side_move_attack 對應的動畫名
		"attack_frame": 6       # 轉向波浪生成幀（衝撞過程中）
	},
	"emerge_jump": {
		"attack_frame": 2,      # 出水特效幀
		"land_effect_frame": 8  # 落地特效幀
	}
}
#endregion

#region 狀態定義
enum GiantFishState {
	IDLE = BossBase.BossState.IDLE,
	APPEAR = BossBase.BossState.APPEAR,
	MOVE = BossBase.BossState.MOVE, 
	HURT = BossBase.BossState.HURT,
	DEFEATED = BossBase.BossState.DEFEATED,
	PHASE_TRANSITION = BossBase.BossState.PHASE_TRANSITION,
	
	# Giant Fish 特有狀態
	DIVE = BossBase.BossState.MAX_BOSS_STATES,
	SUBMERGED_MOVE,
	EMERGE_JUMP,
	TAIL_SWIPE, 
	BUBBLE_ATTACK_STATE, 
	SIDE_MOVE_ATTACK_STATE,
}

#endregion

#region 導出屬性
@export_group("衍生物場景")
@export var water_splash_scene: PackedScene
@export var wave_scene: PackedScene
@export var bubble_scene: PackedScene

@export_group("Giant Fish Behavior")
@export var dive_duration: float = 1.0
@export var submerged_move_speed: float = 300.0
@export var submerged_move_timeout: float = 5.0
@export var emerge_jump_initial_y_velocity: float = -700.0
@export var emerge_jump_horizontal_speed: float = 150.0
@export var tail_swipe_duration: float = 1.5
@export var bubble_attack_duration: float = 1.0
@export var charge_speed_multiplier: float = 3.0

@export_group("攻擊配置")
@export var attack_interval_min: float = 2.0  # 最小攻擊間隔
@export var attack_interval_max: float = 3.5  # 最大攻擊間隔
@export var bubbles_per_attack_phase1: int = 5
@export var bubbles_per_attack_phase2: int = 7
#endregion

#region 節點引用
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
@onready var spawnable_manager: SpawnableManager
@onready var bubble_field_controller: BubbleFieldController
#endregion

#region 狀態變量
# 核心狀態
var is_phase_two: bool = false
var last_action: String = ""


# 連擊系統
var combo_count: int = 0
var max_combo_count: int = 2  # 第一階段最大2連，第二階段會變成3連
var combo_chance_phase1: float = 0.35  # 第一階段35%機率連擊
var combo_chance_phase2: float = 0.50  # 第二階段50%機率連擊
var is_in_combo: bool = false
var combo_interval: float = 0.8  # 連擊間隔（比正常恢復時間短）

# AI決策系統
var last_action_times: Dictionary = {}

# 跳躍攻擊相關
var submerged_move_target_position: Vector2
var submerged_move_current_timer: float = 0.0
var _dive_state_timer: float = 0.0
var _emerge_jump_air_timer: float = 0.0
var _is_at_jump_apex: bool = false
var _jump_apex_hold_timer: float = 0.0
var _previous_jump_velocity_y: float = 0.0

# 側身攻擊相關
var half_body_move_direction: int = 1
var half_body_moves_done: int = 0
var _map_edge_left_x: float = INF 
var _map_edge_right_x: float = -INF
var _map_width_calculated: bool = false
var _is_returning_to_center: bool = false
var _return_target_x: float = 0.0

# 其他攻擊計時器
var _tail_swipe_state_timer: float = 0.0
var _bubble_attack_state_timer: float = 0.0
var _phase_transition_timer: float = 0.0

# 攻擊間隔控制
var _attack_interval_timer: float = 0.0
var _can_attack: bool = true

# 防重複觸發系統
var _triggered_effects: Dictionary = {}  # 格式：{動畫名_幀號: true}
var _last_animation: String = ""
var _last_state: int = -1

var initial_max_health: float = 0.0
#endregion

func _ready() -> void:
	super._ready()

	# 初始化衍生物管理器
	spawnable_manager = SpawnableManager.new()
	add_child(spawnable_manager)
	
	# 初始化泡泡場地控制系統
	bubble_field_controller = BubbleFieldController.new()
	add_child(bubble_field_controller)
	bubble_field_controller.bubble_scene = bubble_scene
	bubble_field_controller.cooldown_time = 8.0
	bubble_field_controller.trigger_distance = 400.0
	
	# 初始化基本變量
	initial_max_health = max_health
	current_state = GiantFishState.APPEAR
	
	# 設置階段攻擊
	_setup_phase_attacks()
	
	# 初始化攻擊冷卻
	_initialize_attack_cooldowns()
	
	# 連接動畫幀變化信號
	if animated_sprite:
		animated_sprite.frame_changed.connect(_on_frame_changed)
	
	# 延遲初始化場地控制系統（等待target_player可用）
	call_deferred("_initialize_field_controller")
	
	# 設置共用碰撞形狀系統
	_setup_shared_collision_shapes()

func _physics_process(delta: float) -> void:
	if current_state == GiantFishState.DEFEATED:
		return

	super._physics_process(delta)
	
	# 階段轉換是最高優先級狀態，完全不可被打斷
	if current_state == GiantFishState.PHASE_TRANSITION:
		_giant_fish_phase_transition_state(delta)
		return  # 跳過所有其他處理
	
	# 處理攻擊間隔計時器
	if _attack_interval_timer > 0:
		_attack_interval_timer -= delta
		if _attack_interval_timer <= 0:
			_can_attack = true

	# 處理狀態邏輯
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
		# PHASE_TRANSITION 已在 _physics_process 開頭處理，具有最高優先級

#region 核心AI決策系統 - 簡化版本
func _setup_phase_attacks():
	# 第一階段：基礎攻擊（無跳躍攻擊）
	phase_attacks[1] = [
		ACTION_TAIL_SWIPE_ATTACK,
		ACTION_BUBBLE_ATTACK,
		ACTION_SIDE_MOVE_ATTACK
	]
	
	# 第二階段：移除泡泡攻擊（因為其他攻擊已經有很多泡泡效果），加入跳躍攻擊
	phase_attacks[2] = [
		ACTION_TAIL_SWIPE_ATTACK,
		ACTION_SIDE_MOVE_ATTACK,
		ACTION_JUMP_ATTACK
	]

func _initialize_attack_cooldowns():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for action in ATTACK_COOLDOWNS.keys():
		# 初始化為可立即使用
		last_action_times[action] = current_time - ATTACK_COOLDOWNS[action] - 1.0

func _initialize_field_controller():
	"""初始化場地控制系統"""
	if bubble_field_controller and target_player and spawnable_manager:
		bubble_field_controller.initialize(self, target_player, spawnable_manager)
		
		# 連接信號
		bubble_field_controller.field_control_triggered.connect(_on_field_control_triggered)
		bubble_field_controller.field_control_completed.connect(_on_field_control_completed)
	else:
		# 重試初始化
		call_deferred("_initialize_field_controller")

func select_next_action() -> String:
	var available = []
	var current_time = Time.get_ticks_msec() / 1000.0
	var phase_number = 2 if is_phase_two else 1
	
	# 簡單條件檢查：驗證冷卻時間和場景資源
	for action in phase_attacks[phase_number]:
		var last_time = last_action_times.get(action, 0.0)
		var cooldown = ATTACK_COOLDOWNS.get(action, 3.0)
		
		# 檢查冷卻時間
		if current_time - last_time < cooldown:
			continue
			
		# 檢查必需的場景資源
		var can_execute = true
		match action:
			ACTION_BUBBLE_ATTACK:
				can_execute = bubble_scene != null
			ACTION_JUMP_ATTACK:
				can_execute = water_splash_scene != null
			# 其他攻擊暫時不需要特殊資源檢查
		
		if can_execute:
			available.append(action)
	
	# 保底機制：確保總有可用攻擊
	if available.is_empty():
		available = [ACTION_TAIL_SWIPE_ATTACK]  # 基本攻擊
	
	# 防重複邏輯：避免連續兩次相同攻擊
	if last_action in available and available.size() > 1:
		available.erase(last_action)
	
	# 距離驅動優化：簡單的距離偏好
	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		available = _apply_distance_preference(available, distance)
	
	# 隨機選擇
	var selected = available[randi() % available.size()]
	
	# 記錄選擇
	last_action = selected
	last_action_times[selected] = current_time
	
	
	return selected

func _apply_distance_preference(available_actions: Array, distance: float) -> Array:
	# 如果只有一個選項，直接返回
	if available_actions.size() <= 1:
		return available_actions
	
	var preferred = []
	
	# 近距離偏好
	if distance < CLOSE_RANGE_DISTANCE:
		for action in available_actions:
			if action == ACTION_TAIL_SWIPE_ATTACK:
				preferred.append(action)
	
	# 遠距離偏好
	elif distance > FAR_RANGE_DISTANCE:
		for action in available_actions:
			if action in [ACTION_JUMP_ATTACK, ACTION_BUBBLE_ATTACK]:
				preferred.append(action)
	
	# 如果有偏好選項，返回偏好；否則返回原列表
	return preferred if not preferred.is_empty() else available_actions
#endregion


#region 連擊系統
func _should_trigger_combo() -> bool:
	"""判斷是否應該觸發連擊"""
	# 階段轉換狀態不觸發連擊
	if current_state == GiantFishState.PHASE_TRANSITION:
		return false
	
	# 已達到最大連擊數
	if combo_count >= max_combo_count:
		return false
	
	# 根據當前階段計算連擊機率
	var combo_chance = combo_chance_phase2 if is_phase_two else combo_chance_phase1
	
	# 隨機判斷是否觸發
	return randf() < combo_chance

func _trigger_combo():
	"""觸發連擊"""
	combo_count += 1
	is_in_combo = true
	
	# 較短的間隔後觸發下一次攻擊
	_can_attack = false
	_attack_interval_timer = combo_interval
	
	# 等待間隔結束後，_can_attack 會自動設為 true，觸發下一次攻擊
	
	
func _end_combo():
	"""結束連擊"""
	combo_count = 0
	is_in_combo = false

#endregion

#region 水花系統 - 精確實現
func spawn_water_splashes_emerge(spawn_point: Vector2):
	"""出水效果：較窄角度的向上噴濺"""
	_spawn_water_splash_pattern(spawn_point, "emerge")

func spawn_water_splashes_land(spawn_point: Vector2):
	"""入水效果：較寬角度的向外擴散"""
	_spawn_water_splash_pattern(spawn_point, "land")

func _spawn_water_splash_pattern(spawn_point: Vector2, effect_type: String):
	# 使用WaterSplashSpawnPoint節點位置
	var spawn_point_node = get_node_or_null("WaterSplashSpawnPoint")
	var center_pos = spawn_point
	if spawn_point_node:
		center_pos = spawn_point_node.global_position
	
	# 階段差異：二階段跳躍水花每邊+1顆（總共+2顆）
	var base_splash_count = bubbles_per_attack_phase2 if is_phase_two else bubbles_per_attack_phase1
	var splash_count = base_splash_count
	if is_phase_two:
		splash_count += 2  # 每邊+1顆，總共+2顆
	
	# 根據效果類型設置不同參數
	var angle_range: float
	var base_speed: float
	var vertical_speed: float
	
	match effect_type:
		"emerge":  # 出水：窄角度，強向上
			angle_range = 80.0  # -40°到+40°
			base_speed = 250.0
			vertical_speed = -400.0
		"land":    # 入水：寬角度，向外擴散
			angle_range = 140.0  # -70°到+70°
			base_speed = 350.0
			vertical_speed = -300.0
		_:
			angle_range = 120.0
			base_speed = 300.0
			vertical_speed = -350.0
	
	var start_angle = -angle_range / 2.0
	var angle_step = angle_range / (splash_count - 1) if splash_count > 1 else 0.0
	
	
	for i in range(splash_count):
		# 計算發射角度（度）
		var angle_deg = start_angle + i * angle_step
		var angle_rad = deg_to_rad(angle_deg)
		
		# 計算初始速度向量
		var horizontal_speed = base_speed * sin(angle_rad)
		var initial_velocity = Vector2(horizontal_speed, vertical_speed)
		
		# 在世界空間生成水花（使用場景樹根節點，避免跟隨BOSS移動）
		_spawn_independent_water_splash(center_pos, initial_velocity)

func _spawn_independent_water_splash(world_position: Vector2, initial_velocity: Vector2):
	"""在世界空間獨立生成水花，不跟隨BOSS移動"""
	if not water_splash_scene:
		return
		
	var splash = water_splash_scene.instantiate()
	if not splash:
		return
	
	# 添加到場景樹的根節點而非BOSS，確保獨立物理
	get_tree().current_scene.add_child(splash)
	splash.global_position = world_position
	
	# 設置視覺與碰撞分離的碰撞層
	_setup_independent_water_splash(splash, initial_velocity)

func _setup_independent_water_splash(splash: Node, initial_velocity: Vector2):
	"""設置獨立水花"""
	if not is_instance_valid(splash):
		return
	
	# 發射水花
	if splash.has_method("launch"):
		splash.launch(initial_velocity)

# 保留舊函數以兼容 spawnable_manager
func _setup_water_splash(splash: Node, splash_position: Vector2, initial_velocity: Vector2):
	if not is_instance_valid(splash):
		return
		
	splash.global_position = splash_position
	_setup_independent_water_splash(splash, initial_velocity)
#endregion

#region 攻擊準備函數
func _prepare_jump_attack():
	if not target_player or not water_splash_scene: 
		_change_state(GiantFishState.IDLE)
		return
	
	# 第二階段強化：跳躍前的泡泡預備
	if is_phase_two:
		_spawn_jump_prep_bubbles()
	
	# 二階段新增：遠距離跳躍模式
	var use_long_range_jump = is_phase_two and randf() < 0.5  # 50%機率使用遠距離跳躍
	
	if use_long_range_jump:
		# 遠距離跳躍：移動到地圖邊緣，然後跳向玩家
		var player_x = target_player.global_position.x
		var boss_x = global_position.x
		
		# 根據地圖邊界或預設距離確定遠距離位置
		var far_distance = 400.0  # 遠距離跳躍距離
		var target_x: float
		
		if player_x > boss_x:
			# 玩家在右側，BOSS移動到左遠方
			target_x = boss_x - far_distance
		else:
			# 玩家在左側，BOSS移動到右遠方
			target_x = boss_x + far_distance
		
		submerged_move_target_position = Vector2(target_x, global_position.y)
	else:
		# 標準跳躍：移動到玩家腳下起跳
		submerged_move_target_position = Vector2(target_player.global_position.x, global_position.y)
		
	submerged_move_current_timer = 0.0
	_dive_state_timer = 0.0
	_change_state(GiantFishState.DIVE)

func _prepare_tail_swipe_attack():
	_tail_swipe_state_timer = 0.0
	_change_state(GiantFishState.TAIL_SWIPE)

func _prepare_bubble_attack():
	if not bubble_scene:
		_change_state(GiantFishState.IDLE)
		return
	
	# 檢查是否使用場地控制模式
	var use_field_control = _should_use_field_control()
	
	if use_field_control and bubble_field_controller:
		var pattern = bubble_field_controller.select_field_control_pattern()
		if pattern != "" and bubble_field_controller.trigger_field_control(pattern):
			# 場地控制已觸發，直接返回IDLE狀態
			_change_state(GiantFishState.IDLE)
			return
	
	# 使用普通扇形泡泡攻擊（現在由動畫幀觸發）
	_bubble_attack_state_timer = 0.0
	_change_state(GiantFishState.BUBBLE_ATTACK_STATE)

func _should_use_field_control() -> bool:
	"""決定是否使用場地控制模式"""
	if not bubble_field_controller or bubble_field_controller.is_cooldown:
		return false
	
	if not target_player:
		return false
	
	var distance = global_position.distance_to(target_player.global_position)
	
	# 條件1：玩家距離過遠時優先使用場地控制
	if distance > 500.0:
		return true
	
	# 條件2：二階段時更頻繁使用場地控制
	var base_chance = 0.3 if is_phase_two else 0.2
	
	# 條件3：根據攻擊次數增加使用概率
	var attack_count = bubble_field_controller.trigger_count
	var bonus_chance = min(attack_count * 0.1, 0.3)
	
	var final_chance = base_chance + bonus_chance
	var use_field_control = randf() < final_chance
	
	
	return use_field_control

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
	
	# 第二階段強化：衝撞前的泡泡預備
	if is_phase_two:
		_spawn_charge_prep_bubbles()
	
	_change_state(GiantFishState.SIDE_MOVE_ATTACK_STATE)
#endregion


#region 泡泡生成
func _spawn_bubbles_for_action():
	
	if not bubble_scene:
		return

	if not spawnable_manager:
		return

	var bubble_count = bubbles_per_attack_phase2 if is_phase_two else bubbles_per_attack_phase1
	
	# 獲取生成點位置
	var spawn_point_node = get_node_or_null("BubbleSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	else:
		spawn_pos = global_position + Vector2(0, -50)

	# 扇形參數設置
	var angle_range = 120.0  # 總角度範圍
	var start_angle = -angle_range / 2.0
	var angle_step = angle_range / (bubble_count - 1) if bubble_count > 1 else 0.0
	
	# 確保BOSS面向玩家
	_face_target()
	

	# 0.1秒間隔連續生成泡泡，模擬吹泡泡效果
	for i in range(bubble_count):
		var angle_deg = start_angle + i * angle_step
		var direction = Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)))
		
		
		# 在世界空間獨立生成泡泡，不跟隨BOSS
		_spawn_independent_bubble(spawn_pos, direction)
		
		# 0.1秒間隔，模擬吹泡泡的連續效果
		if i < bubble_count - 1:  # 最後一個泡泡不需要等待
			await get_tree().create_timer(0.1).timeout
	

func _setup_bubble_with_direction(bubble: Node, spawn_pos: Vector2, direction: Vector2):
	"""設置帶方向的泡泡（用於扇形攻擊）"""
	
	if not is_instance_valid(bubble):
		return
		
	bubble.global_position = spawn_pos
	
	# 嘗試設置初始方向（如果泡泡支持）
	if bubble.has_method("initialize_with_direction"):
		bubble.initialize_with_direction(target_player, direction)
	elif bubble.has_method("initialize"):
		bubble.initialize(target_player)

func _setup_bubble(bubble: Node, spawn_pos: Vector2):
	"""設置標準泡泡（向後兼容）"""
	
	if not is_instance_valid(bubble):
		return
		
	bubble.global_position = spawn_pos
	
	# 泡泡場景應該有自己的腳本來處理行為
	if bubble.has_method("initialize"):
		bubble.initialize(target_player)
	

func _spawn_independent_bubble(world_position: Vector2, direction: Vector2):
	"""在世界空間獨立生成泡泡，不跟隨BOSS移動"""
	if not bubble_scene:
		return
		
	var bubble = bubble_scene.instantiate()
	if not bubble:
		return
	
	# 添加到場景樹的根節點而非BOSS，確保獨立物理
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = world_position
	
	# 設置泡泡運動方向和參數
	_setup_independent_bubble(bubble, direction)

func _setup_independent_bubble(bubble: Node, direction: Vector2):
	"""設置獨立泡泡"""
	if not is_instance_valid(bubble):
		return
	
	# 使用新的方向初始化函數
	if bubble.has_method("initialize_with_direction"):
		bubble.initialize_with_direction(target_player, direction)
	elif bubble.has_method("initialize"):
		bubble.initialize(target_player)

func _face_target():
	"""確保BOSS面向玩家"""
	if target_player and is_instance_valid(target_player) and animated_sprite:
		var direction_to_player = target_player.global_position.x - global_position.x
		animated_sprite.flip_h = direction_to_player < 0

func _spawn_charge_prep_bubbles():
	"""衝撞前預備：發射3個定向泡泡"""
	if not bubble_scene or not target_player or not is_instance_valid(target_player):
		return
	
	var bubble_count = 3
	var spawn_point_node = get_node_or_null("BubbleSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	else:
		spawn_pos = global_position + Vector2(0, -50)
	
	# 面向玩家
	_face_target()
	
	# 計算朝向玩家的方向
	var direction_to_player = (target_player.global_position - spawn_pos).normalized()
	
	# 生成3個泡泡：中間1個直射，左右各1個小角度偏移
	var angles = [-15.0, 0.0, 15.0]  # 左偏移15度、直射、右偏移15度
	
	for i in range(bubble_count):
		var angle_offset = deg_to_rad(angles[i])
		var direction = direction_to_player.rotated(angle_offset)
		
		# 在世界空間獨立生成泡泡
		_spawn_independent_bubble(spawn_pos, direction)
		
		# 短暫間隔，營造發射效果
		if i < bubble_count - 1:
			await get_tree().create_timer(0.1).timeout

func _spawn_jump_prep_bubbles():
	"""跳躍前預備：向左右散射泡泡"""
	if not bubble_scene:
		return
	
	var bubble_count = 4  # 左右各2個
	var spawn_point_node = get_node_or_null("BubbleSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	else:
		spawn_pos = global_position + Vector2(0, -50)
	
	# 左右散射角度：-45°, -22°, 22°, 45°
	var angles = [-45.0, -22.0, 22.0, 45.0]
	
	for i in range(bubble_count):
		var angle_rad = deg_to_rad(angles[i])
		var direction = Vector2(cos(angle_rad), sin(angle_rad))
		
		# 在世界空間獨立生成泡泡
		_spawn_independent_bubble(spawn_pos, direction)
		
		# 短暫間隔，營造發射效果
		if i < bubble_count - 1:
			await get_tree().create_timer(0.05).timeout

func _spawn_jump_emerge_bubbles():
	"""跳躍出水時左右散射泡泡"""
	if not bubble_scene:
		return
	
	var bubble_count = 6  # 左右各3個，更多泡泡
	var spawn_point_node = get_node_or_null("BubbleSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	else:
		spawn_pos = global_position + Vector2(0, -50)
	
	# 更廣的左右散射角度：-80°到+80°
	var angles = [-80.0, -50.0, -25.0, 25.0, 50.0, 80.0]
	
	
	for i in range(bubble_count):
		var angle_rad = deg_to_rad(angles[i])
		var direction = Vector2(cos(angle_rad), sin(angle_rad))
		
		# 在世界空間獨立生成泡泡
		_spawn_independent_bubble(spawn_pos, direction)
		
		# 更快的連射效果
		if i < bubble_count - 1:
			await get_tree().create_timer(0.03).timeout
	
#endregion

#region 波浪系統
func _spawn_waves_after_tail_swipe():
	# 開始生成波浪
	
	if not wave_scene:
		# 波浪場景未設置
		return

	if not spawnable_manager:
		return

	# 生成單個波浪，方向跟隨BOSS攻擊朝向
	var direction = Vector2.RIGHT if not animated_sprite or not animated_sprite.flip_h else Vector2.LEFT
	
	# 使用WaveSpawnPoint節點位置，如果沒有則使用BOSS位置
	var spawn_point_node = get_node_or_null("WaveSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	
	spawnable_manager.spawn_with_pool(
		wave_scene, 
		"wave",
		func(obj): _setup_wave(obj, spawn_pos, direction, true)
	)
	
	# 第二階段強化：召喚海浪時同時召喚2-3個泡泡
	if is_phase_two:
		_spawn_wave_bubbles(spawn_pos)
		
		# 0.5秒後生成第二波原始大小波浪
		await get_tree().create_timer(0.5).timeout
		spawnable_manager.spawn_with_pool(
			wave_scene, 
			"wave",
			func(obj): _setup_wave(obj, spawn_pos, direction, false)
		)
	

func _setup_wave(wave: Node, spawn_pos: Vector2, direction: Vector2, is_first_wave: bool = true):
	if not is_instance_valid(wave):
		return
		
	wave.global_position = spawn_pos
	
	var wave_scale: float
	if is_first_wave:
		wave_scale = 1.7 if is_phase_two else 1.0
	else:
		wave_scale = 1.0
	
	if wave.has_method("set_scale_multiplier"):
		wave.set_scale_multiplier(wave_scale)
	else:
		wave.scale = Vector2(wave_scale, wave_scale)  # 如果波浪不支持倍數設置，直接設置scale
	
	if wave.has_method("initialize"):
		wave.initialize(direction)

func _spawn_wave_bubbles(wave_pos: Vector2):
	"""海浪召喚時同時生成2-3個追蹤泡泡"""
	if not bubble_scene or not target_player or not is_instance_valid(target_player):
		return
	
	var bubble_count = randi_range(2, 3)  # 隨機2-3個泡泡
	
	
	# 計算泡泡生成位置（在波浪周圍）
	for i in range(bubble_count):
		var offset_x = randf_range(-100.0, 100.0)  # 水平隨機偏移
		var offset_y = randf_range(-50.0, 50.0)    # 垂直隨機偏移
		var bubble_pos = wave_pos + Vector2(offset_x, offset_y)
		
		# 計算朝向玩家的方向（帶有一定追蹤性）
		var direction_to_player = (target_player.global_position - bubble_pos).normalized()
		
		# 在世界空間獨立生成泡泡
		_spawn_independent_bubble(bubble_pos, direction_to_player)
		
		# 短暫間隔
		if i < bubble_count - 1:
			await get_tree().create_timer(0.15).timeout

func _spawn_charge_turn_wave():
	"""衝撞轉向時生成1.5倍大海浪"""
	if not wave_scene or not spawnable_manager:
		return
	
	# 根據當前轉向方向生成波浪
	var direction = Vector2.RIGHT if half_body_move_direction > 0 else Vector2.LEFT
	
	# 使用WaveSpawnPoint節點位置，如果沒有則使用BOSS位置
	var spawn_point_node = get_node_or_null("WaveSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	
	
	# 生成1.5倍大的波浪
	spawnable_manager.spawn_with_pool(
		wave_scene, 
		"wave",
		func(obj): _setup_enhanced_wave(obj, spawn_pos, direction, 1.5)
	)
	
func _setup_enhanced_wave(wave: Node, spawn_pos: Vector2, direction: Vector2, scale_multiplier: float):
	"""設置增強的波浪（可自定義倍數）"""
	if not is_instance_valid(wave):
		return
		
	wave.global_position = spawn_pos
	
	if wave.has_method("set_scale_multiplier"):
		wave.set_scale_multiplier(scale_multiplier)
	else:
		wave.scale = Vector2(scale_multiplier, scale_multiplier)
	
	if wave.has_method("initialize"):
		wave.initialize(direction)

func _spawn_jump_landing_waves():
	"""跳躍落地時生成雙向1.5倍大海浪"""
	if not wave_scene or not spawnable_manager:
		return
	
	# 使用WaveSpawnPoint節點位置，如果沒有則使用BOSS位置
	var spawn_point_node = get_node_or_null("WaveSpawnPoint")
	var spawn_pos = global_position
	if spawn_point_node:
		spawn_pos = spawn_point_node.global_position
	
	
	# 同時生成向左和向右的1.5倍大海浪
	spawnable_manager.spawn_with_pool(
		wave_scene, 
		"wave",
		func(obj): _setup_enhanced_wave(obj, spawn_pos, Vector2.LEFT, 1.5)
	)
	
	spawnable_manager.spawn_with_pool(
		wave_scene, 
		"wave", 
		func(obj): _setup_enhanced_wave(obj, spawn_pos, Vector2.RIGHT, 1.5)
	)
	

#endregion

#region 動畫映射
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
			return "phase_transition"
		_:
			return super.get_current_animation_name()
#endregion

#region 狀態處理函數（保留原有邏輯）
func _process_idle_state(delta: float) -> void:
	# 基礎追擊邏輯
	if target_player and is_instance_valid(target_player):
		var distance_to_player = global_position.distance_to(target_player.global_position)
		var direction_to_player = (target_player.global_position - global_position).normalized()
		
		# 面向玩家
		if animated_sprite:
			animated_sprite.flip_h = direction_to_player.x < 0
		
		# 檢查是否可以攻擊（使用新的間隔控制）
		if _can_attack:
			_start_attack()
		
		# 在合理距離內緩慢追擊
		if distance_to_player > 100.0:  # 保持一定距離
			velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed * 0.3, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	
	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta

func _start_attack():
	"""開始攻擊（基於動畫幀+間隔計時器）"""
	var selected_attack = select_next_action()
	current_attack = selected_attack
	
	# 設置攻擊間隔（不能再攻擊）
	_can_attack = false
	_attack_interval_timer = randf_range(attack_interval_min, attack_interval_max)
	
	# 直接執行攻擊
	match selected_attack:
		ACTION_TAIL_SWIPE_ATTACK:
			_prepare_tail_swipe_attack()
		ACTION_BUBBLE_ATTACK:
			_prepare_bubble_attack()
		ACTION_SIDE_MOVE_ATTACK:
			_prepare_half_body_move()
		ACTION_JUMP_ATTACK:
			_prepare_jump_attack()

func _giant_fish_side_move_attack_state(_delta: float):
	var current_charge_speed = move_speed * charge_speed_multiplier

	if _is_returning_to_center:
		velocity.x = half_body_move_direction * current_charge_speed
		if ( (half_body_move_direction > 0 and global_position.x >= _return_target_x) or
			 (half_body_move_direction < 0 and global_position.x <= _return_target_x) or
			 abs(global_position.x - _return_target_x) < 15.0 ):
			_on_action_finished()
			return
	elif is_on_wall():
		var current_hit_x = global_position.x
		
		if half_body_move_direction < 0:
			_map_edge_left_x = current_hit_x
		else:
			_map_edge_right_x = current_hit_x

		if _map_edge_left_x != INF and _map_edge_right_x != -INF and _map_edge_left_x < _map_edge_right_x:
			_map_width_calculated = true

		velocity.x = 0 
		half_body_moves_done += 1

		var max_moves = 2 
		if is_phase_two:
			max_moves = 4 
		
		if half_body_moves_done >= max_moves:
			_is_returning_to_center = true
			
			if _map_width_calculated:
				var map_width = _map_edge_right_x - _map_edge_left_x
				var center_x = _map_edge_left_x + map_width / 2.0
				var offset_range = map_width * 0.25
				
				var new_direction_of_return = -half_body_move_direction
				
				if new_direction_of_return > 0:
					if not is_phase_two:
						_return_target_x = randf_range(center_x + 0.01, center_x + offset_range)
					else:
						_return_target_x = randf_range(center_x - offset_range, center_x - 0.01)
				else:
					if not is_phase_two:
						_return_target_x = randf_range(center_x - offset_range, center_x - 0.01)
					else:
						_return_target_x = randf_range(center_x + 0.01, center_x + offset_range)
			else:
				if target_player and is_instance_valid(target_player):
					_return_target_x = global_position.x + sign(target_player.global_position.x - global_position.x) * (move_speed * 0.5)
				else:
					_return_target_x = global_position.x + (-half_body_move_direction * (move_speed * 0.5))

			half_body_move_direction *= -1
			if animated_sprite: 
				animated_sprite.flip_h = half_body_move_direction < 0
			return 
		else:
			half_body_move_direction *= -1
			if animated_sprite: 
				animated_sprite.flip_h = half_body_move_direction < 0
			
			# 第二階段強化：衝撞轉向時生成1.5倍大海浪
			if is_phase_two:
				_spawn_charge_turn_wave()

	if not _is_returning_to_center:
		velocity.x = half_body_move_direction * current_charge_speed

func _giant_fish_dive_state(_delta: float):
	_dive_state_timer += _delta
	if _dive_state_timer >= dive_duration:
		_change_state(GiantFishState.SUBMERGED_MOVE)

func _giant_fish_submerged_move_state(delta: float):
	global_position = global_position.move_toward(submerged_move_target_position, submerged_move_speed * delta)
	submerged_move_current_timer += delta

	var dist_to_target = global_position.distance_to(submerged_move_target_position)

	if dist_to_target < 10.0 or submerged_move_current_timer >= submerged_move_timeout:
		_prepare_emerge_jump()

func _prepare_emerge_jump():
	if target_player and is_instance_valid(target_player):
		var direction_to_player = (target_player.global_position - global_position).normalized()
		velocity.x = direction_to_player.x * emerge_jump_horizontal_speed
		velocity.y = emerge_jump_initial_y_velocity 
	else:
		velocity.x = 0
		velocity.y = emerge_jump_initial_y_velocity

	# 出水特效現在由動畫幀觸發

	_emerge_jump_air_timer = 0.0
	_is_at_jump_apex = false
	_previous_jump_velocity_y = emerge_jump_initial_y_velocity
	_change_state(GiantFishState.EMERGE_JUMP)

func _giant_fish_emerge_jump_state(delta: float):
	_emerge_jump_air_timer += delta

	var current_gravity_scale = 0.2
	var was_rising = _previous_jump_velocity_y < -1.0
	var is_now_falling_or_still = velocity.y >= -1.0

	if not _is_at_jump_apex and was_rising and is_now_falling_or_still:
		_is_at_jump_apex = true
		_jump_apex_hold_timer = 0.0

	if _is_at_jump_apex:
		_jump_apex_hold_timer += delta
		if _jump_apex_hold_timer < 0.35:
			current_gravity_scale = 0.1
		else:
			_is_at_jump_apex = false

	velocity.y += gravity * current_gravity_scale * delta
	_previous_jump_velocity_y = velocity.y

	if is_on_floor():
		# 落地特效現在由動畫幀觸發
		velocity.x = 0 
		_is_at_jump_apex = false
		_on_action_finished()
		return
	elif _emerge_jump_air_timer >= 3.0:
		velocity.x = 0 
		velocity.y = 0 
		_is_at_jump_apex = false
		_on_action_finished()
		return

func _giant_fish_tail_swipe_state(delta: float):
	_tail_swipe_state_timer += delta
	if _tail_swipe_state_timer >= tail_swipe_duration:
		# 擺尾攻擊結束（波浪生成已由動畫幀觸發）
		_on_action_finished()

func _giant_fish_bubble_attack_state(delta: float):
	_bubble_attack_state_timer += delta
	if _bubble_attack_state_timer >= bubble_attack_duration:
		_on_action_finished()

func _giant_fish_phase_transition_state(delta: float):
	_phase_transition_timer += delta
	if _phase_transition_timer >= 2.0:
		_on_action_finished()

func _on_action_finished():
	# 檢查是否觸發連擊
	if _should_trigger_combo():
		_trigger_combo()
	else:
		_end_combo()
		_change_state(GiantFishState.IDLE)

func _setup_shared_collision_shapes():
	"""設置共用碰撞形狀系統 - 讓 Hitbox 和 TouchDamageArea 共用相同形狀"""
	var main_collision = get_node_or_null("CollisionShape2D")
	if not main_collision:
		return
	
	var main_shape = main_collision.shape
	if not main_shape:
		return
	
	# 設置 Hitbox 共用相同形狀
	var hitbox_collision = get_node_or_null("Hitbox/CollisionShape2D")
	if hitbox_collision:
		hitbox_collision.shape = main_shape
	
	# 設置 TouchDamageArea 共用相同形狀
	var touch_damage_collision = get_node_or_null("TouchDamageArea/CollisionShape2D")
	if touch_damage_collision:
		touch_damage_collision.shape = main_shape
	

func _on_field_control_triggered(_pattern_name: String):
	"""場地控制觸發回調"""
	pass

func _on_field_control_completed(_pattern_name: String):
	"""場地控制完成回調"""
	pass

func _on_frame_changed():
	"""動畫幀變化處理（防重複觸發）"""
	if not animated_sprite:
		return
		
	var current_anim = animated_sprite.animation
	var current_frame = animated_sprite.frame
	
	# 檢測動畫或狀態切換，重置觸發記錄
	if current_anim != _last_animation or current_state != _last_state:
		_triggered_effects.clear()
		_last_animation = current_anim
		_last_state = current_state
	
	if not ATTACK_FRAMES.has(current_anim):
		return
		
	var config = ATTACK_FRAMES[current_anim]
	
	# 攻擊判定幀觸發特效（防重複）
	if config.has("attack_frame") and current_frame == config.attack_frame:
		var trigger_key = current_anim + "_attack_frame_" + str(config.attack_frame)
		if not _triggered_effects.has(trigger_key):
			_triggered_effects[trigger_key] = true
			_trigger_attack_effects(current_anim)
	
	# 落地特效幀處理（僅用於跳躍攻擊，防重複）
	if config.has("land_effect_frame") and current_frame == config.land_effect_frame:
		var trigger_key = current_anim + "_land_effect_frame_" + str(config.land_effect_frame)
		if not _triggered_effects.has(trigger_key):
			_triggered_effects[trigger_key] = true
			_trigger_land_effects(current_anim)
	

func _trigger_attack_effects(anim_name: String):
	"""觸發攻擊特效"""
	match anim_name:
		"tail_swipe":
			# 擺尾攻擊：生成波浪
			_spawn_waves_after_tail_swipe()
		"bubble_attack":
			# 泡泡攻擊：發射泡泡
			_spawn_bubbles_for_action()
		"move":
			# 側身攻擊：衝撞轉向時生成波浪（如果在第二階段）
			if is_phase_two:
				_spawn_charge_turn_wave()
		"emerge_jump":
			# 跳躍攻擊：出水時生成水花和泡泡
			spawn_water_splashes_emerge(global_position)
			if is_phase_two:
				_spawn_jump_emerge_bubbles()

func _trigger_land_effects(anim_name: String):
	"""觸發落地特效"""
	if anim_name == "emerge_jump":
		# 跳躍落地：生成水花和波浪
		spawn_water_splashes_land(global_position)
		if is_phase_two:
			_spawn_jump_landing_waves()

#endregion

#region 狀態變更
func _change_state(new_state: int) -> void:
	if current_state == new_state:
		return
	
	# 狀態切換時清除觸發記錄
	_triggered_effects.clear()
		
	var old_state_name = GiantFishState.find_key(current_state)
	if old_state_name == null: 
		old_state_name = "UNKNOWN (%d)" % current_state
	
	var new_state_name = GiantFishState.find_key(new_state)
	if new_state_name == null: 
		new_state_name = "UNKNOWN (%d)" % new_state


	if new_state in BossBase.BossState.values():
		super._change_state(new_state)
	else:
		previous_state = current_state
		current_state = new_state

	match new_state:
		GiantFishState.IDLE:
			velocity = Vector2.ZERO
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
			# 第二階段提升連擊能力
			max_combo_count = 3
			
		GiantFishState.SIDE_MOVE_ATTACK_STATE:
			can_be_interrupted = false
			
		GiantFishState.EMERGE_JUMP:
			can_be_interrupted = true
#endregion

#region 受傷和階段轉換
func take_damage(damage: float, attacker: Node, _knockback_info: Dictionary = {}) -> void:
	super.take_damage(damage, attacker)
	
	if current_health <= 0:
		return

	if current_health <= max_health * PHASE_TWO_HEALTH_THRESHOLD and not is_phase_two:
		if current_state != GiantFishState.PHASE_TRANSITION:
			_change_state(GiantFishState.PHASE_TRANSITION)

func _on_defeated():
	set_physics_process(false)
	if collision_shape_node:
		collision_shape_node.disabled = true
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
	velocity = Vector2.ZERO
	
	# 清理所有衍生物
	if spawnable_manager:
		spawnable_manager.cleanup_all()
	
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
