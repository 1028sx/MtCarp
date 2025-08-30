extends Area2D

class_name WaveProjectile

@export var move_speed: float = 200.0
@export var damage: float = 20.0
@export var lifetime: float = 6.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var knockback_force: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var lifetime_timer: float = 0.0
var is_active: bool = false
var has_hit_player: bool = false

func _ready():
	# 設置信號連接
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	
	# 播放出現動畫
	if animated_sprite and animated_sprite.sprite_frames.has_animation("appear"):
		animated_sprite.play("appear")
		animated_sprite.animation_finished.connect(_on_appear_finished)
	else:
		_start_default_behavior()

func initialize(direction: Vector2 = Vector2.RIGHT):
	"""BOSS調用的初始化函數"""
	move_direction = direction.normalized()
	lifetime_timer = 0.0
	is_active = true
	has_hit_player = false
	
	# 根據移動方向調整精靈朝向
	if animated_sprite:
		animated_sprite.flip_h = move_direction.x < 0
	

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
	
	# 簡單水平移動
	global_position += move_direction * move_speed * delta
	
	# 檢查牆壁碰撞
	_check_wall_collision()

func _on_body_entered(body: Node2D):
	if has_hit_player:
		return
		
	if body.has_method("take_damage"):
		_hit_target(body)

func _on_area_entered(area: Area2D):
	if has_hit_player:
		return
		
	# 如果玩家有受傷區域（Area2D）
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		_hit_target(parent)

func _check_wall_collision():
	# 檢測前方是否有牆壁
	var space_state = get_world_2d().direct_space_state
	var check_distance = 20.0
	var check_direction = Vector2(move_direction.x * check_distance, 0)
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + check_direction
	)
	query.collision_mask = 1  # Environment層
	
	var result = space_state.intersect_ray(query)
	if result:
		_destroy()

func _hit_target(target: Node):
	if has_hit_player:
		return
		
	has_hit_player = true
	
	# 對目標造成傷害並施加擊退效果
	if target.has_method("take_damage"):
		target.take_damage(damage, self)
	
	if target.has_method("apply_knockback"):
		var knockback_vector = move_direction.normalized() * knockback_force
		target.apply_knockback(knockback_vector)
	
	# 波浪命中後不立即消失，繼續移動一段時間
	# 這樣可以創造更有威脅性的攻擊

func _on_screen_exited():
	_destroy()

func _destroy():
	if not is_active:
		return
		
	is_active = false
	
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
	return "wave"

func reset():
	"""物件池重置函數"""
	lifetime_timer = 0.0
	is_active = false
	has_hit_player = false
	move_direction = Vector2.RIGHT
	visible = true
