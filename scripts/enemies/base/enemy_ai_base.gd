extends CharacterBody2D

class_name EnemyAIBase

signal defeated

#region 導出屬性 (可在編輯器中調整)
@export_group("基本屬性")
@export var health: float = 100.0
@export var move_speed: float = 50.0
@export var acceleration: float = 500.0
@export var deceleration: float = 500.0
@export var gravity_scale: float = 1.0

@export_group("AI 行為")
@export var detection_range: float = 200.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 2.0
@export var wander_time_min: float = 2.0
@export var wander_time_max: float = 4.0

@export_group("傷害")
@export var touch_damage: float = 10.0
@export var hitbox_area: NodePath

#endregion

#region 節點引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var edge_check_right: RayCast2D = get_node_or_null("EdgeCheckRight")
@onready var edge_check_left: RayCast2D = get_node_or_null("EdgeCheckLeft")
@onready var touch_damage_area: Area2D = get_node_or_null("TouchDamageArea")
@onready var hitbox_node: Area2D = get_node_or_null(hitbox_area) if hitbox_area else null

var touch_damage_cooldown_timer: Timer
var source_shape_node: CollisionShape2D
#endregion

#region 狀態變量
var states: Dictionary = {}
var current_state_name: String = ""
var current_state: EnemyStateBase
var player: CharacterBody2D = null
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var zone_states: Dictionary = {}
#endregion


func _ready() -> void:
	_connect_signals()
	
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.one_shot = true

	touch_damage_cooldown_timer = Timer.new()
	touch_damage_cooldown_timer.name = "TouchDamageCooldownTimer"
	touch_damage_cooldown_timer.wait_time = 1.0
	touch_damage_cooldown_timer.one_shot = true
	add_child(touch_damage_cooldown_timer)
	
	_initialize_shape_sharing()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * gravity_scale * delta
	
	if current_state:
		current_state.process_physics(delta)
	
	move_and_slide()


#region 核心功能 (狀態機)
func add_state(state_name: String, state_object: EnemyStateBase) -> void:
	"""註冊一個狀態物件，並進行初始化。"""
	states[state_name] = state_object
	state_object.initialize(self)

func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("嘗試切換到不存在的狀態: %s" % new_state_name)
		return
	
	if current_state_name == new_state_name:
		return

	if current_state:
		current_state.on_exit()
	
	current_state_name = new_state_name
	current_state = states[new_state_name]
	current_state.on_enter()


func take_damage(amount: float, _attacker: Node) -> void:
	if current_state_name == "Dead":
		return
	
	health -= amount
	if health <= 0:
		change_state("Dead")
	else:
		change_state("Hurt")


func _on_death() -> void:
	set_physics_process(false)
	
	var current_shape = source_shape_node if is_instance_valid(source_shape_node) else CollisionShapeManager.find_active_shape(self)
	if is_instance_valid(current_shape):
		current_shape.set_deferred("disabled", true)

	if is_instance_valid(detection_area):
		detection_area.call_deferred("set", "monitoring", false)
	defeated.emit()
#endregion

#region 通用輔助函式 (供狀態物件呼叫)

func _update_sprite_flip() -> void:
	"""根據玩家位置或自身速度更新精靈的翻轉。"""
	var direction_to_flip: float = 0.0

	if is_instance_valid(player):
		direction_to_flip = player.global_position.x - global_position.x
	elif abs(velocity.x) > 1.0:
		direction_to_flip = velocity.x
	
	if abs(direction_to_flip) > 0.1:
		animated_sprite.flip_h = direction_to_flip < 0

func _post_physics_processing(_delta: float) -> void:
	"""
	在 move_and_slide 之後被狀態呼叫，用於處理需要精確物理狀態的邏輯。
	主要用於懸崖和牆壁檢測。
	"""
	var is_moving_right = velocity.x > 0.1
	var is_moving_left = velocity.x < -0.1

	var is_at_edge = false
	if is_moving_right and is_instance_valid(edge_check_right):
		is_at_edge = not edge_check_right.is_colliding()
	elif is_moving_left and is_instance_valid(edge_check_left):
		is_at_edge = not edge_check_left.is_colliding()

	if (is_on_wall_only() or is_at_edge) and (is_moving_left or is_moving_right):
		velocity.x = 0
#endregion


#region 動畫名稱覆寫 (供狀態物件呼叫)
func _get_idle_animation() -> String: return "idle"
func _get_walk_animation() -> String: return "walk"
func _get_attack_animation() -> String: return "attack"
func _get_hurt_animation() -> String: return "hurt"
func _get_hold_position_animation() -> String: return "idle"
func _get_death_animation() -> String: return "death"
#endregion

#region 信號連接與回調
func _connect_signals() -> void:
	if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	if is_instance_valid(touch_damage_area):
		if not touch_damage_area.body_entered.is_connected(_on_touch_damage_area_body_entered):
			touch_damage_area.body_entered.connect(_on_touch_damage_area_body_entered)


func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		if current_state:
			current_state.on_player_detected(body)

func _on_touch_damage_area_body_entered(body: Node) -> void:
	"""處理與玩家的物理接觸傷害，並包含冷卻機制。"""
	if not touch_damage_cooldown_timer.is_stopped() or not body.is_in_group("player"):
		return
	
	if body.has_method("take_damage"):
		body.take_damage(touch_damage, self)
		touch_damage_cooldown_timer.start()

func _on_detection_area_body_exited(body: Node) -> void:
	if body == player:
		player = null
		if current_state:
			current_state.on_player_lost(body)

func _on_animation_finished() -> void:
	if current_state:
		current_state.on_animation_finished()

#endregion 

#region 形狀共享 (使用統一的 CollisionShapeManager)

func _initialize_shape_sharing() -> void:
	source_shape_node = CollisionShapeManager.initialize_shape_sharing(self, hitbox_node, touch_damage_area)

func update_shared_shapes() -> void:
	source_shape_node = CollisionShapeManager.update_shared_shapes(self, hitbox_node, touch_damage_area, source_shape_node)

#endregion

#region 新增：通用區域管理
func register_zone(zone_name: String, area_node: Area2D) -> void:
	"""
	註冊一個自訂的 Area2D 區域，並自動連接其信號以追蹤玩家進出。
	子類 (如 archer.gd) 應在 _ready() 中呼叫此函式。
	"""
	if not is_instance_valid(area_node):
		push_warning("嘗試註冊一個無效的 Area2D 節點給區域 '%s'" % zone_name)
		return
		
	zone_states[zone_name] = false
	
	area_node.body_entered.connect(_on_custom_zone_body_toggled.bind(zone_name, true))
	area_node.body_exited.connect(_on_custom_zone_body_toggled.bind(zone_name, false))


func _on_custom_zone_body_toggled(body: Node, zone_name: String, is_inside: bool) -> void:
	"""當玩家進入或離開一個已註冊的自訂區域時，更新 zone_states。"""
	if body.is_in_group("player"):
		zone_states[zone_name] = is_inside


func is_in_zone(zone_name: String) -> bool:
	"""
	提供給狀態物件的接口，用來查詢玩家當前是否在某個已註冊的區域內。
	"""
	return zone_states.get(zone_name, false)
  
#endregion 
