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
				collider.take_damage(damage)
		queue_free()
#endregion

#region 信號處理
func _on_hit_box_area_entered(area):
	var body = area.get_parent()
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
#endregion
