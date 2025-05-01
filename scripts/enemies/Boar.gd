extends CharacterBody2D

signal defeated

@export_group("Movement")
@export var move_speed = 200.0
@export var charge_speed_min = 300.0
@export var charge_speed_max = 500.0
@export var charge_acceleration = 150.0
@export var charge_distance = 200.0
@export var detection_range = 300.0
@export var jump_force = -150.0
@export var jump_attack_distance = 50.0
@export var jump_speed_boost = 1.5

@export_group("Combat")
@export var health = 1000
@export var damage = 20
@export var attack_cooldown = 1.5
@export var height_tolerance = 50.0
@export var invincible_time = 1.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var attack_timer = $AttackTimer
@onready var invincible_timer = Timer.new()

enum State {IDLE, MOVE, CHARGE, ATTACK, HURT, DIE}

var current_state = State.IDLE
var player: CharacterBody2D = null
var is_dying = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var initial_position = Vector2.ZERO
var current_speed = 0.0
var knockback_velocity = Vector2.ZERO
var knockback_resistance = 0.9
var can_attack = true
var is_invincible = false

func _ready():
	_initialize_enemy()
	_setup_collisions()
	_setup_components()
	_connect_signals()
	_setup_invincible_timer()
	initial_position = global_position

func _initialize_enemy():
	add_to_group("enemy")

func _setup_collisions():
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_layer_value(4, false)
	set_collision_layer_value(5, true)
	
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)
	set_collision_mask_value(5, false)
	
	if hitbox:
		hitbox.set_collision_layer_value(3, true)
		hitbox.set_collision_mask_value(4, true)
	
	if attack_area:
		attack_area.set_collision_layer_value(4, true)
		attack_area.set_collision_mask_value(3, true)
		attack_area.monitoring = false
	
	if detection_area:
		detection_area.set_collision_layer_value(1, false)
		detection_area.set_collision_mask_value(2, true)
		detection_area.monitoring = true

func _setup_components():
	if animated_sprite:
		animated_sprite.play("idle")
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func _connect_signals():
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)

func _setup_invincible_timer():
	invincible_timer.wait_time = invincible_time
	invincible_timer.one_shot = true
	add_child(invincible_timer)
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)

func _physics_process(delta):
	if is_dying:
		return
	
	velocity.y += gravity * delta
	
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 1000)
	else:
		match current_state:
			State.IDLE:
				idle_state(delta)
			State.MOVE:
				move_state(delta)
			State.CHARGE:
				charge_state(delta)
			State.ATTACK:
				attack_state(delta)
			State.HURT:
				hurt_state(delta)
			State.DIE:
				die_state(delta)
	
	move_and_slide()

func idle_state(_delta):
	velocity.x = 0
	if is_instance_valid(player):
		change_state(State.MOVE)
	elif randf() < _delta * 0.5:
		start_wander()

func start_wander():
	change_state(State.MOVE)
	velocity.x = move_speed * (1 if randf() > 0.5 else -1)
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
	await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
	if current_state == State.MOVE and not is_instance_valid(player):
		change_state(State.IDLE)

func move_state(_delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		var height_difference = abs(player.global_position.y - global_position.y)
		var distance = global_position.distance_to(player.global_position)
		var is_in_attack_range = distance <= charge_distance
		
		if height_difference < height_tolerance:
			velocity.x = direction.x * move_speed
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
			
			if is_in_attack_range and can_attack:
				current_speed = charge_speed_min
				change_state(State.CHARGE)
		else:
			velocity.x = 0
	else:
		if is_on_wall() or not _check_ground_ahead():
			velocity.x *= -1
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0

func attack_state(_delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * current_speed
		
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0
			animated_sprite.play("attack")

func charge_state(delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		var distance = global_position.distance_to(player.global_position)
		
		current_speed = move_toward(current_speed, charge_speed_max, charge_acceleration * delta)
		velocity.x = direction.x * current_speed
		
		if distance <= jump_attack_distance and is_on_floor():
			velocity.y = jump_force
			change_state(State.ATTACK)
		
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0
			animated_sprite.play("move")

func hurt_state(_delta):
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")
		var knockback_dir = -1 if animated_sprite.flip_h else 1
		velocity.x = knockback_dir * move_speed * 0.5

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
			word_system.handle_enemy_drops("Boar", global_position)

func change_state(new_state):
	if is_dying:
		return
	
	if new_state == State.CHARGE:
		can_attack = false
		attack_timer.start()
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			
			State.MOVE:
				animated_sprite.play("move")
			
			State.CHARGE:
				animated_sprite.play("move")
			
			State.ATTACK:
				animated_sprite.play("attack")
			
			State.HURT:
				animated_sprite.play("hurt")
			
			State.DIE:
				animated_sprite.play("die")

func _check_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(30 * sign(velocity.x), 0),
		global_position + Vector2(30 * sign(velocity.x), 50),
		1
	)
	var result = space_state.intersect_ray(query)
	return result != null

func take_damage(amount):
	if is_dying or is_invincible:
		return
	
	health -= amount
	is_invincible = true
	invincible_timer.start()
	
	if health <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func apply_knockback(knockback: Vector2):
	knockback_velocity = knockback * (1.0 - knockback_resistance)

func _on_animated_sprite_animation_finished():
	if current_state == State.HURT:
		if is_instance_valid(player):
			change_state(State.MOVE)
		else:
			change_state(State.IDLE)
	elif current_state == State.DIE:
		queue_free()
	elif current_state == State.ATTACK:
		change_state(State.MOVE)

func _on_animated_sprite_frame_changed():
	if current_state == State.ATTACK:
		attack_area.monitoring = animated_sprite.frame >= 2 and animated_sprite.frame <= 4

func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player = body
		change_state(State.MOVE)

func _on_detection_area_body_exited(body: Node2D):
	if body.is_in_group("player") and body == player:
		player = null
		change_state(State.IDLE)

func _on_attack_timer_timeout():
	can_attack = true

func _on_invincible_timer_timeout():
	is_invincible = false
