extends "res://scripts/enemies/base/flying_enemy_base.gd"

#region 導出屬性 (覆寫或新增)
@export_group("攻擊行為")
@export var dive_attack_damage: int = 15
#endregion

#region 節點與變數
@onready var standing_collision_shape: CollisionShape2D = $StandingCollisionShape
@onready var flying_collision_shape: CollisionShape2D = $FlyingCollisionShape
@onready var attack_area_right: Area2D = $AttackAreaRight
@onready var attack_area_left: Area2D = $AttackAreaLeft

# 獲取當前活動的攻擊區域
func get_current_attack_area() -> Area2D:
	# 根據翻轉狀態選擇正確的攻擊區域
	if animated_sprite and animated_sprite.flip_h:
		return attack_area_left
	else:
		return attack_area_right
#endregion


func _ready() -> void:
	super._ready()
	
	_initialize_states()
	
	if is_instance_valid(animated_sprite):
		animated_sprite.animation_changed.connect(set_collision_shape_state)
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)
		set_collision_shape_state()
	else:
		push_warning("SmallBird: 找不到 AnimatedSprite2D 節點！形狀切換將無法運作。")
	
	# 連接攻擊區域信號
	if attack_area_right:
		attack_area_right.area_entered.connect(_on_attack_area_area_entered)
		attack_area_right.body_entered.connect(_on_attack_area_body_entered)
		# 初始時禁用攻擊區域監測
		attack_area_right.monitoring = false
	
	if attack_area_left:
		attack_area_left.area_entered.connect(_on_attack_area_area_entered)
		attack_area_left.body_entered.connect(_on_attack_area_body_entered)
		# 初始時禁用攻擊區域監測
		attack_area_left.monitoring = false
	
	# 重新指向SmallBird特定的攻擊冷卻計時器節點
	attack_cooldown_timer = $AttackCooldownTimer
	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = 2.0
		attack_cooldown_timer.one_shot = true
	
	change_state("GroundPatrol")


func set_collision_shape_state() -> void:
	"""
	根據當前的動畫名稱，啟用對應的主要物理碰撞體，並禁用另一個。
	"""
	if not is_instance_valid(animated_sprite):
		return

	var animation_name = animated_sprite.animation
	
	if animation_name.begins_with("sit"):
		standing_collision_shape.set_deferred("disabled", false)
		flying_collision_shape.set_deferred("disabled", true)
	else:
		standing_collision_shape.set_deferred("disabled", true)
		flying_collision_shape.set_deferred("disabled", false)
	
	if is_node_ready():
		update_shared_shapes()


func _initialize_states() -> void:
	"""初始化並註冊所有狀態。"""
	add_state("GroundPatrol", SmallBirdGroundPatrolState.new())
	add_state("Takeoff", SmallBirdTakeoffState.new())
	add_state("Landing", SmallBirdLandingState.new())
	add_state("AirCombat", SmallBirdAirCombatState.new())
	add_state("Hurt", SmallBirdHurtState.new())
	add_state("Dead", EnemyDeadState.new())


#region 動畫名稱覆寫
func _get_idle_animation() -> String: return "idle"
func _get_walk_animation() -> String: return "walk"
func _get_fly_animation() -> String: return "fly"
func _get_soar_animation() -> String: return "soar"
func _get_attack_animation() -> String: return "attack_air"
func _get_hurt_animation() -> String: return "hurt"
func _get_death_animation() -> String: return "die"
func _get_fall_animation() -> String: return "fall"
func _get_takeoff_animation() -> String: return "takeoff"
func _get_land_animation() -> String: return "land"
#endregion


func _on_detection_area_body_entered(body: Node) -> void:
	super._on_detection_area_body_entered(body)
	# 讓當前狀態自己處理玩家檢測

func _on_detection_area_body_exited(body: Node) -> void:
	super._on_detection_area_body_exited(body)
	# 讓當前狀態自己處理玩家離開


func take_damage(amount: float, _attacker: Node) -> void:
	if current_state_name == "Dead":
		return
		
	health -= amount
	
	if health <= 0:
		change_state("Dead")
	else:
		change_state("Hurt")


#region 攻擊區域信號處理
func _on_attack_area_area_entered(area: Area2D) -> void:
	# 將事件轉發給當前狀態
	if current_state and current_state.has_method("on_attack_area_entered"):
		current_state.on_attack_area_entered(area)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(dive_attack_damage, self)
	
	# 將事件轉發給當前狀態
	if current_state and current_state.has_method("on_attack_area_body_entered"):
		current_state.on_attack_area_body_entered(body)

func _on_animation_frame_changed() -> void:
	# 將動畫幀變化事件轉發給當前狀態
	if current_state and current_state.has_method("on_animation_frame_changed"):
		current_state.on_animation_frame_changed(animated_sprite.frame)

func _on_animation_finished() -> void:
	# 將動畫完成事件轉發給當前狀態
	if current_state and current_state.has_method("on_animation_finished"):
		current_state.on_animation_finished()
#endregion
