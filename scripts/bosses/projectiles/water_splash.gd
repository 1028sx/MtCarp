extends Area2D

class_name WaterSplash_projectile

@export var damage: float = 15.0
@export var lifetime: float = 5.0
@export var splash_gravity: float = 980.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var velocity: Vector2 = Vector2.ZERO
var lifetime_timer: float = 0.0
var is_active: bool = false
var has_hit_player: bool = false

func _ready():
	# 設置信號連接
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	
	# 加入BOSS衍生物組（統一清理用）
	add_to_group("giantfish_spawnables")
	
	# 播放出現動畫
	if animated_sprite and animated_sprite.sprite_frames.has_animation("appear"):
		animated_sprite.play("appear")
		animated_sprite.animation_finished.connect(_on_appear_finished)
	else:
		_start_default_behavior()

func launch(initial_velocity: Vector2):
	"""BOSS調用的發射函數"""
	velocity = initial_velocity
	lifetime_timer = 0.0
	is_active = true

func _on_appear_finished():
	animated_sprite.animation_finished.disconnect(_on_appear_finished)
	_start_default_behavior()

func _start_default_behavior():
	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
	is_active = true

func _physics_process(delta: float):
	if not is_active:
		return
		
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		_destroy()
		return
	
	# 拋物線運動：水平速度保持恆定，垂直速度受重力影響
	velocity.y += splash_gravity * delta
	global_position += velocity * delta
	
	# 檢查地面碰撞
	_check_ground_collision()

func _check_ground_collision():
	# 使用射線檢測地面碰撞
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 10)
	)
	query.collision_mask = 1  # Environment層
	
	var result = space_state.intersect_ray(query)
	if result and velocity.y > 0:  # 只在下降時檢測
		_destroy()

func _on_body_entered(body: Node2D):
	if not is_active:
		return
		
	# 檢查是否撞到玩家
	if body.has_method("take_damage") and not has_hit_player:
		body.take_damage(damage)
		has_hit_player = true
		# 不銷毀，繼續飛行
		return

func _on_area_entered(area: Area2D):
	if not is_active:
		return
		
	# 如果玩家有受傷區域（Area2D）
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and not has_hit_player:
		parent.take_damage(damage)
		has_hit_player = true
		# 不銷毀，繼續飛行

func _on_screen_exited():
	_destroy()

func _destroy():
	if not is_active:
		return
		
	is_active = false
	
	# 停止運動
	velocity = Vector2.ZERO
	
	# 播放消失動畫
	if animated_sprite and animated_sprite.sprite_frames.has_animation("disappear"):
		animated_sprite.play("disappear")
		animated_sprite.animation_finished.connect(_on_destroy_finished)
	else:
		_on_destroy_finished()

func _on_destroy_finished():
	queue_free()

# SpawnableManager 類型檢測
func get_spawnable_type() -> String:
	return "water_splash"

# 統一清理接口
func cleanup():
	_destroy()

func reset():
	"""物件池重置函數"""
	velocity = Vector2.ZERO
	lifetime_timer = 0.0
	is_active = false
	has_hit_player = false
	visible = true
