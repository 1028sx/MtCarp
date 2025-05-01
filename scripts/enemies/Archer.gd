extends CharacterBody2D

# 正確宣告信號
signal defeated

#region 導出屬性
@export_group("Movement")
@export var move_speed = 150.0
@export var wander_time_min = 1.0
@export var wander_time_max = 3.0
@export var ideal_shooting_distance = 350.0
@export var shooting_range_tolerance = 50.0

@export_group("Combat")
@export var health = 300
@export var damage = 10
@export var knockback_resistance = 0.8
@export var minimum_attack_distance = 50.0
@export var maximum_attack_distance = 500.0
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var edge_check = $EdgeCheck
@onready var health_bar = $HealthBar
var arrow_scene = preload("res://scenes/enemies/Arrow.tscn")
#endregion

#region 狀態變量
enum State {IDLE, WANDER, MOVE, ATTACK, HURT, DIE}

# 基礎狀態
var current_state = State.IDLE
var target_player: CharacterBody2D = null
var is_dying = false

# 移動相關
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var wander_timer = 0.0
var wander_direction = Vector2.ZERO

# 擊退相關
var knockback_velocity = Vector2.ZERO

# 攻擊方向
var attack_direction := Vector2.ZERO
#endregion

#region 初始化系統
func _ready() -> void:
	_initialize_enemy()
	_setup_collisions()
	_setup_components()
	_connect_signals()
	
	# 設置邊緣檢測射線
	if not edge_check:
		edge_check = RayCast2D.new()
		add_child(edge_check)
	edge_check.position = Vector2(0, 0)  # 從腳下開始
	edge_check.target_position = Vector2(0, 100)  # 向下檢測100像素
	edge_check.enabled = true
	edge_check.collision_mask = 1  # 只檢測地形層

	# 初始化血量條
	if health_bar:
		health_bar.max_value = health
		health_bar.value = health
		health_bar.show()

func _initialize_enemy() -> void:
	add_to_group("enemy")

func _setup_collisions() -> void:
	# 設置弓箭手本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, true)   # 設為敵人專用層
	
	# 設置弓箭手的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置弓箭手的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置弓箭手的檢測區域（用於發現玩家）
	if detection_area:
		detection_area.collision_layer = 0  # 不設置任何碰撞層
		detection_area.set_collision_mask_value(2, true)    # 只檢測玩家層
		# 不設置地形層的碰撞遮罩，這樣就能穿牆檢測
	
	# 設置弓箭手的攻擊區域（用於檢測攻擊範圍）
	if attack_area:
		attack_area.collision_layer = 0  # 不設置任何碰撞層
		attack_area.set_collision_mask_value(1, true)    # 檢測地形層
		attack_area.set_collision_mask_value(2, true)    # 檢測玩家層

func _setup_components() -> void:
	if animated_sprite:
		animated_sprite.play("idle")
	
	if attack_timer:
		attack_timer.one_shot = true

func _connect_signals() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
#endregion

#region 主要更新循環
func _physics_process(delta: float) -> void:
	if is_dying:
		return
	
	# 應用重力
	velocity.y += gravity * delta
	
	# 處理擊退
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity  # 直接使用擊退速度
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 1000)
	else:
		# 正常的 AI 行為
		match current_state:
			State.IDLE:
				idle_state(delta)
			State.WANDER:
				wander_state(delta)
			State.MOVE:
				move_state()
			State.ATTACK:
				attack_state()
			State.HURT:
				hurt_state()
			State.DIE:
				die_state()
	
	move_and_slide()
#endregion

#region AI狀態系統
func idle_state(delta: float) -> void:
	velocity.x = 0
	if is_instance_valid(target_player):
		change_state(State.MOVE)
	elif randf() < delta * 0.5:
		start_wander()

func wander_state(delta: float) -> void:
	velocity.x = wander_direction.x * move_speed * 0.5
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
	
	wander_timer -= delta
	if wander_timer <= 0 or is_on_wall():
		change_state(State.IDLE)
	
	if is_instance_valid(target_player):
		change_state(State.MOVE)

func move_state() -> void:
	if is_instance_valid(target_player):
		var distance_to_player = global_position.distance_to(target_player.global_position)
		var direction = (target_player.global_position - global_position).normalized()
		
		var target_velocity = Vector2.ZERO
		var can_move = true  # 新增：用於判斷是否可以移動
		
		if distance_to_player < ideal_shooting_distance - shooting_range_tolerance:
			target_velocity.x = -direction.x * move_speed
		elif distance_to_player > ideal_shooting_distance + shooting_range_tolerance:
			target_velocity.x = direction.x * move_speed
		
		# 檢查是否會掉落或撞牆
		if target_velocity.x != 0:
			# 更新射線位置和方向
			edge_check.position = Vector2(sign(target_velocity.x) * 30, 0)
			edge_check.target_position = Vector2(sign(target_velocity.x) * 30, 100)
			
			# 如果檢測到碰撞，檢查碰撞點的位置來判斷是牆還是地板
			if edge_check.is_colliding():
				var collision_point = edge_check.get_collision_point()
				var collision_height = collision_point.y - global_position.y
				
				# 如果碰撞點在角色中心附近，認為是牆壁
				if abs(collision_height) < 30:
					can_move = false
			else:
				# 如果完全沒有檢測到碰撞，且在地面上，則不能移動
				if is_on_floor():
					can_move = false
		
		# 檢查是否可以攻擊
		var can_attack = distance_to_player >= minimum_attack_distance and \
						distance_to_player <= maximum_attack_distance and \
						attack_area and attack_area.has_overlapping_bodies()
		
		if can_attack and attack_timer.is_stopped():
			change_state(State.ATTACK)
			return
		
		# 根據是否可以移動來設置速度和動畫
		if can_move:
			velocity.x = target_velocity.x
			if animated_sprite and abs(velocity.x) > 0:
				animated_sprite.play("run")
		else:
			velocity.x = 0
			if animated_sprite:
				animated_sprite.play("idle")
		
		if animated_sprite:
			animated_sprite.flip_h = direction.x < 0
	else:
		change_state(State.IDLE)

func attack_state() -> void:
	velocity.x = 0
	if is_instance_valid(target_player) and animated_sprite and animated_sprite.animation != "attack":
		# 計算彈道補償
		var target_pos = target_player.global_position
		var distance = global_position.distance_to(target_pos)
		
		# 根據距離計算下墜補償
		var height_compensation = distance * 0.2  # 每單位距離補償0.2單位高度
		target_pos.y += height_compensation  # 向下調整目標點
		
		# 計算攻擊方向
		attack_direction = (target_pos - global_position).normalized()
		animated_sprite.flip_h = attack_direction.x < 0
		animated_sprite.play("attack")

func hurt_state() -> void:
	# 保持擊退速度
	velocity = knockback_velocity
	
	# 只有在受傷動畫播放完成後才會切換回移動狀態
	# 這個切換會在 _on_animated_sprite_animation_finished 中處理
	# 所以這裡不需要手動切換狀態

func die_state() -> void:
	velocity.x = 0
	if not is_dying:
		is_dying = true
		defeated.emit()
		
		# 添加擊殺計數
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.enemy_killed()
		
		if animated_sprite:
			animated_sprite.play("die")
			
		# 使用 WordSystem 處理掉落
		var word_system = get_tree().get_first_node_in_group("word_system")
		if word_system:
			word_system.handle_enemy_drops("Archer", global_position)

func start_wander() -> void:
	change_state(State.WANDER)
	wander_timer = randf_range(wander_time_min, wander_time_max)
	wander_direction = Vector2(randf_range(-1, 1), 0).normalized()

func change_state(new_state: State) -> void:
	if is_dying:
		return
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			State.WANDER, State.MOVE:
				animated_sprite.play("run")
			State.ATTACK:
				# 重置攻擊方向
				if is_instance_valid(target_player):
					attack_direction = (target_player.global_position - global_position).normalized()
					animated_sprite.flip_h = attack_direction.x < 0
				animated_sprite.play("attack")
			State.HURT:
				animated_sprite.play("hurt")
			State.DIE:
				animated_sprite.play("die")
#endregion

#region 戰鬥系統
func shoot_arrow() -> void:
	if is_instance_valid(target_player):
		var arrow = arrow_scene.instantiate()
		# 計算箭矢生成位置（在弓箭手前方30像素）
		var spawn_offset = attack_direction * 30
		arrow.global_position = global_position + spawn_offset
		arrow.initialize(attack_direction, self)
		get_parent().add_child(arrow)

func take_damage(amount: float) -> void:
	if is_dying:
		return
	
	health -= amount
	
	# 更新血量條
	if health_bar:
		health_bar.value = health
	
	if health <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func apply_knockback(knockback: Vector2) -> void:
	# 直接設置擊退速度，不需要考慮當前速度
	knockback_velocity = knockback * (1.0 - knockback_resistance)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target_player = body
		if current_state == State.IDLE or current_state == State.WANDER:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		target_player = null
		change_state(State.IDLE)

func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite:
		match animated_sprite.animation:
			"attack":
				shoot_arrow()  # 發射箭矢
				attack_timer.start()  # 啟動計時器
				change_state(State.MOVE)  # 返回移動狀態
			"hurt":
				change_state(State.MOVE)
			"die":
				queue_free()
#endregion
