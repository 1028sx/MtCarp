extends CharacterBody2D

#region 導出屬性
@export var speed = 800.0
@export var damage = 10
@export var gravity_scale = 0.5
#endregion

#region 節點引用
@onready var hitbox = $HitBox
#endregion

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var shooter = null

#region 初始化
func _ready():
	_setup_collisions()

func _setup_collisions():
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_layer_value(4, false)
	set_collision_layer_value(5, false)
	
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)
	set_collision_mask_value(5, false)
	
	if hitbox:
		hitbox.set_collision_layer_value(4, true)
		hitbox.set_collision_mask_value(3, true)
		hitbox.set_collision_mask_value(1, false)
		hitbox.set_collision_mask_value(2, false)
		hitbox.set_collision_mask_value(4, false)
		hitbox.set_collision_mask_value(5, false)
#endregion

#region 主要功能
func initialize(direction: Vector2, source: Node = null):
	shooter = source
	rotation = direction.angle()
	velocity = direction * speed

func get_shooter() -> Node:
	return shooter

func _physics_process(delta):
	velocity.y += gravity * gravity_scale * delta
	
	rotation = velocity.angle()
	
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage, self)  # 修改：傳遞自身作為攻擊者
		# 無論碰到什麼都銷毀箭矢
		queue_free()
#endregion

#region 信號處理
func _on_hit_box_area_entered(area):
	# 只通過 HitBox 處理傷害
	var body = area.get_parent()
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, self)  # 修改：傳遞自身作為攻擊者
		queue_free()
#endregion
