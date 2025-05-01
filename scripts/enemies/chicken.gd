extends CharacterBody2D

signal defeated

#region 導出屬性
@export var move_speed = 500.0  # 移動速度提高到500
@export var detection_range = 200.0  # 檢測範圍
@export var health = 50  # 基礎血量
@export var damage = 5  # 基礎傷害
@export var attack_cooldown = 0.5  # 攻擊冷卻時間
@export var jump_force = -250.0  # 跳躍力度
@export var max_fall_speed = 1000.0  # 最大落下速度
@export var jump_cooldown = 1.0  # 跳躍冷卻時間
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var attack_timer = $AttackTimer
#endregion

#region 狀態變量
enum State {IDLE, MOVE, ATTACK, HURT, DIE, JUMP, FLY}

var current_state = State.IDLE
var player: CharacterBody2D = null
var is_dying = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var knockback_velocity = Vector2.ZERO
var knockback_resistance = 0.5  # 較低的擊退抗性
var can_jump = true
var jump_timer = 0.0
var is_frozen := false
var frozen_timer := 0.0
var frozen_duration := 1.0  # 一般敵人的冰凍時間為1秒
#endregion

#region 初始化
func _ready():
	_initialize_enemy()
	_setup_collisions()
	_setup_components()
	_connect_signals()

func _initialize_enemy():
	add_to_group("enemy")

func _setup_collisions():
	# 設置小雞本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(5, true)   # 設為敵人專用層
	
	# 設置小雞的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	
	# 設置小雞的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置小雞的攻擊區域
	if attack_area:
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域
		attack_area.monitoring = false
	
	# 設置小雞的檢測區域
	if detection_area:
		detection_area.set_collision_mask_value(2, true)    # 檢測玩家層

func _setup_components():
	if animated_sprite:
		animated_sprite.play("idle")
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true

func _connect_signals():
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_area_entered)
		attack_area.body_entered.connect(_on_attack_area_body_entered)
#endregion

#region 主要更新循環
func _physics_process(delta):
	if is_dying:
		return
	
	if is_frozen:
		frozen_timer -= delta
		if frozen_timer <= 0:
			unfreeze()
		return
	
	# 應用正常重力，不再減緩
	velocity.y += gravity * delta
	
	# 只在下落時檢查是否需要播放飛行動畫
	if velocity.y > 0:  # 正在下落
		if animated_sprite and animated_sprite.animation != "fly":
			animated_sprite.play("fly")
	
	# 處理跳躍冷卻
	if not can_jump:
		jump_timer += delta
		if jump_timer >= jump_cooldown:
			can_jump = true
			jump_timer = 0.0
	
	# 處理擊退
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 1000)
	else:
		match current_state:
			State.IDLE:
				idle_state(delta)
			State.MOVE:
				move_state(delta)
			State.ATTACK:
				attack_state(delta)
			State.HURT:
				hurt_state(delta)
			State.DIE:
				die_state(delta)
			State.JUMP:
				jump_state(delta)
			State.FLY:
				fly_state(delta)
	
	move_and_slide()
#endregion

#region AI狀態系統
func idle_state(_delta):
	velocity.x = 0
	if is_instance_valid(player):
		change_state(State.MOVE)
	elif randf() < _delta * 0.3:  # 較低的徘徊機率
		start_wander()

func start_wander():
	change_state(State.MOVE)
	velocity.x = move_speed * (1 if randf() > 0.5 else -1)
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	if current_state == State.MOVE and not is_instance_valid(player):
		change_state(State.IDLE)

func move_state(_delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		var distance = global_position.distance_to(player.global_position)
		var height_difference = player.global_position.y - global_position.y
		
		if distance <= 50:  # 攻擊距離
			change_state(State.ATTACK)
		else:
			velocity.x = direction.x * move_speed
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
			
			# 根據高度差決定是否跳躍
			if height_difference < -50 and can_jump and is_on_floor():  # 玩家在上方
				change_state(State.JUMP)
			elif height_difference > 50 and not is_on_floor():  # 玩家在下方
				change_state(State.FLY)
	else:
		if is_on_wall() or not _check_ground_ahead():
			velocity.x *= -1
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0

func attack_state(_delta):
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "attack":
		animated_sprite.play("attack")

func hurt_state(_delta):
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")

func die_state(_delta):
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
			word_system.handle_enemy_drops("Chicken", global_position)

func jump_state(_delta):
	if can_jump and is_on_floor():
		velocity.y = jump_force
		can_jump = false
		jump_timer = 0.0
		if animated_sprite:
			animated_sprite.play("jump")
	change_state(State.MOVE)

func fly_state(_delta):
	if is_on_floor():
		change_state(State.MOVE)
	elif animated_sprite and animated_sprite.animation != "fly":
		animated_sprite.play("fly")

func change_state(new_state):
	if is_dying:
		return
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			State.MOVE:
				animated_sprite.play("move")
			State.ATTACK:
				animated_sprite.play("attack")
			State.HURT:
				animated_sprite.play("hurt")
			State.DIE:
				animated_sprite.play("die")
			State.JUMP:
				animated_sprite.play("jump")
			State.FLY:
				animated_sprite.play("fly")

func _check_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(20 * sign(velocity.x), 0),
		global_position + Vector2(20 * sign(velocity.x), 30),
		1
	)
	var result = space_state.intersect_ray(query)
	return result != null
#endregion

#region 戰鬥系統
func take_damage(amount):
	if is_dying:
		return
	
	if is_frozen:
		unfreeze()
		amount = int(float(amount) * 1.5)
	
	health -= amount
	if health <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func apply_knockback(knockback: Vector2):
	knockback_velocity = knockback * (1.0 - knockback_resistance)
#endregion

#region 信號處理
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		if current_state == State.IDLE:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player = null
		change_state(State.IDLE)

func _on_animated_sprite_animation_finished():
	if animated_sprite:
		match animated_sprite.animation:
			"attack":
				if attack_area:
					attack_area.monitoring = false
				change_state(State.MOVE)
			"hurt":
				if current_state == State.HURT:
					change_state(State.MOVE)
			"die":
				queue_free()
			"jump":
				if not is_on_floor():
					change_state(State.FLY)
				else:
					change_state(State.MOVE)

func _on_animated_sprite_frame_changed():
	if animated_sprite and animated_sprite.animation == "attack":
		var current_frame = animated_sprite.frame
		if current_frame == 3:
			if attack_area:
				attack_area.monitoring = true
		else:
			if attack_area:
				attack_area.monitoring = false

func _on_attack_area_area_entered(area):
	var body = area.get_parent()
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
#endregion 

func freeze(duration: float = 1.0) -> void:
	if is_dying:
		return
		
	is_frozen = true
	frozen_timer = duration
	
	# 暫停當前動畫
	if animated_sprite:
		animated_sprite.pause()
	
	# 改變顏色為淡藍色
	modulate = Color(0.7, 0.9, 1.0, 1.0)

func unfreeze() -> void:
	if not is_frozen:
		return
		
	is_frozen = false
	frozen_timer = 0.0
	
	# 恢復動畫
	if animated_sprite:
		animated_sprite.play()
	
	# 恢復原本顏色
	modulate = Color.WHITE 
