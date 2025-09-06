extends "res://scripts/enemies/base/enemy_ai_base.gd"

# 預載入狀態類別
const IdleState = preload("res://scripts/enemies/base/states/common/enemy_idle_state.gd")
const WanderState = preload("res://scripts/enemies/base/states/common/enemy_wander_state.gd")
const HurtState = preload("res://scripts/enemies/base/states/common/enemy_hurt_state.gd")
const ChaseState = preload("res://scripts/enemies/chicken/states/chicken_chase_state.gd")
const JumpState = preload("res://scripts/enemies/chicken/states/chicken_jump_state.gd")
const FallState = preload("res://scripts/enemies/chicken/states/chicken_fall_state.gd")
const AttackState = preload("res://scripts/enemies/chicken/states/chicken_attack_state.gd")
const DeadState = preload("res://scripts/enemies/chicken/states/chicken_dead_state.gd")

#region 導出屬性 (覆寫或新增)
@export_group("小雞特有屬性")
@export var jump_cooldown: float = 2.0 # 跳躍冷卻時間 (秒)

@export_group("Components")
@export var jump_obstacle_raycast_path: NodePath # 用於跳躍障礙物檢測
#endregion

#region 節點引用
# 大部分的節點引用 (animated_sprite, detection_area, etc.) 已經在 EnemyAIBase 中定義
# 我們只需要引用那些 EnemyAIBase 不知道的節點
@onready var attack_area_right: Area2D = $AttackAreaRight
@onready var attack_area_left: Area2D = $AttackAreaLeft
@onready var jump_obstacle_raycast: RayCast2D = get_node_or_null(jump_obstacle_raycast_path)

# 獲取當前活動的攻擊區域
func get_current_attack_area() -> Area2D:
	# 根據精靈的翻轉狀態選擇正確的攻擊區域
	if animated_sprite and animated_sprite.flip_h:
		return attack_area_left
	else:
		return attack_area_right
#endregion

#region 狀態變量
var is_frozen := false
var frozen_timer := 0.0

# 共享的計時器
var jump_cooldown_timer: Timer
#endregion


func _ready() -> void:
	super._ready() # 非常重要：確保父類的 _ready() 被呼叫
	
	# 調整移動速度為兩倍（從預設50.0到100.0）
	move_speed = 100.0
	
	# 創建並配置計時器
	jump_cooldown_timer = Timer.new()
	jump_cooldown_timer.wait_time = jump_cooldown
	jump_cooldown_timer.one_shot = true
	add_child(jump_cooldown_timer)
	
	# 連接動畫幀變化信號
	if animated_sprite:
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)
	
	# 連接攻擊區域信號
	if attack_area_right:
		if not attack_area_right.area_entered.is_connected(_on_attack_area_area_entered):
			attack_area_right.area_entered.connect(_on_attack_area_area_entered)
		if not attack_area_right.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area_right.body_entered.connect(_on_attack_area_body_entered)
		
		# 初始時禁用攻擊區域監測
		attack_area_right.monitoring = false
	
	if attack_area_left:
		if not attack_area_left.area_entered.is_connected(_on_attack_area_area_entered):
			attack_area_left.area_entered.connect(_on_attack_area_area_entered)
		if not attack_area_left.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area_left.body_entered.connect(_on_attack_area_body_entered)
		
		# 初始時禁用攻擊區域監測
		attack_area_left.monitoring = false
	
	# 初始化並註冊所有狀態
	_initialize_states()
	
	# 設定初始狀態
	change_state("Idle")


func _initialize_states() -> void:
	"""初始化並註冊所有狀態。"""
	add_state("Idle", IdleState.new())
	add_state("Wander", WanderState.new())
	
	# 將共享資源注入狀態
	var chase_state_instance = ChaseState.new()
	chase_state_instance.jump_cooldown_timer = jump_cooldown_timer
	add_state("Chase", chase_state_instance)

	add_state("Jump", JumpState.new())
	add_state("Fall", FallState.new())
	add_state("Attack", AttackState.new())
	add_state("Hurt", HurtState.new())
	add_state("Dead", DeadState.new())


# EnemyAIBase 的 _physics_process 會自動呼叫當前狀態的 process_physics
# 我們不再需要在主腳本中寫 _physics_process


#region 動畫名稱覆寫
func _get_idle_animation() -> String: return "idle"
func _get_walk_animation() -> String: return "move" # 原本是 move
func _get_attack_animation() -> String: return "attack"
func _get_hurt_animation() -> String: return "hurt"
func _get_death_animation() -> String: return "die"
func _get_jump_animation() -> String: return "jump"
func _get_fly_animation() -> String: return "fly" # 用於下落/飛行
#endregion


#region 核心功能覆寫
func take_damage(amount: float, attacker: Node) -> void:
	if current_state_name == "Dead":
		return
	
	if is_frozen:
		unfreeze()
		amount = int(float(amount) * 1.5) # 冰凍時受到1.5倍傷害
	
	# 現在呼叫父類的方法來處理生命值和狀態切換
	super.take_damage(amount, attacker)


# _on_death 的邏輯已經被移到 ChickenDeadState 中，以保持主腳本的整潔
# 父類的 _on_death 負責處理禁用物理等通用邏輯

#endregion


#region 信號處理
# 大部分的信號回調，如 _on_detection_area_body_entered, _on_animation_finished
# 都已經在 EnemyAIBase 中被處理，並會將事件轉發給當前的狀態物件。
# 我們只需要處理那些 EnemyAIBase 不知道的特定邏輯。

# AttackState 現在會透過 on_animation_frame_changed 來處理攻擊幀
# 所以不再需要 _on_animated_sprite_frame_changed

# AttackArea 的碰撞現在由 AttackState 處理，但我們需要確保 attack_area 的信號連接到狀態
func _on_attack_area_area_entered(area: Area2D) -> void:
	# 將事件轉發給當前狀態
	if current_state and current_state.has_method("on_attack_area_entered"):
		current_state.on_attack_area_entered(area)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(touch_damage)
	# 將事件轉發給當前狀態
	if current_state and current_state.has_method("on_attack_area_body_entered"):
		current_state.on_attack_area_body_entered(body)

func _on_animation_frame_changed() -> void:
	# 將動畫幀變化事件轉發給當前狀態
	if current_state and current_state.has_method("on_animation_frame_changed"):
		current_state.on_animation_frame_changed(animated_sprite.frame)
#endregion 

#region 小雞特有功能
func freeze(duration: float = 1.0) -> void:
	if current_state_name == "Dead":
		return
		
	is_frozen = true
	frozen_timer = duration
	set_physics_process(false) # 完全凍結物理
	
	if animated_sprite:
		animated_sprite.pause()
	
	modulate = Color(0.7, 0.9, 1.0, 1.0)

func unfreeze() -> void:
	if not is_frozen:
		return
		
	is_frozen = false
	frozen_timer = 0.0
	set_physics_process(true)
	
	if animated_sprite:
		animated_sprite.play()
	
	modulate = Color.WHITE
#endregion 
