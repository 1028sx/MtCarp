extends CharacterBody2D

#region 導出屬性
@export var speed = 800.0
@export var damage = 10
@export var gravity_scale = 0.5  # 添加重力縮放係數
#endregion

#region 節點引用
@onready var hitbox = $HitBox
#endregion

# 添加重力變量
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var shooter = null  # 新增：保存發射者引用

#region 初始化
func _ready():
	_setup_collisions()

func _setup_collisions():
	# 箭矢本體的碰撞層設置
	set_collision_layer_value(1, false)  # 不與任何層碰撞
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_layer_value(4, false)
	set_collision_layer_value(5, false)
	
	# 設置碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形（第1層）
	set_collision_mask_value(2, true)    # 檢測玩家本體（第2層）
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)
	set_collision_mask_value(5, false)   # 不檢測弓箭手
	
	# 箭矢 HitBox 的碰撞層設置
	if hitbox:
		hitbox.set_collision_layer_value(4, true)   # 設為攻擊層
		hitbox.set_collision_mask_value(3, true)    # 檢測玩家的 Hitbox
		hitbox.set_collision_mask_value(1, false)
		hitbox.set_collision_mask_value(2, false)
		hitbox.set_collision_mask_value(4, false)
		hitbox.set_collision_mask_value(5, false)
#endregion

#region 主要功能
func initialize(direction: Vector2, source: Node = null):
	shooter = source  # 保存發射者
	rotation = direction.angle()
	velocity = direction * speed

func get_shooter() -> Node:
	return shooter

func _physics_process(delta):
	# 應用重力
	velocity.y += gravity * gravity_scale * delta
	
	# 根據速度更新箭矢的旋轉
	rotation = velocity.angle()
	
	# 移動箭矢
	var collision = move_and_collide(velocity * delta)
	
	# 檢查碰撞
	if collision:
		var collider = collision.get_collider()
		# 如果碰到玩家，造成傷害
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
