extends Area2D

@onready var animated_sprite = $AnimatedSprite2D

var damage := 50.0
var knockback_force := Vector2(2000, -200)
var hit_enemies := {}
var hit_cooldown := 0.1
var speed := 400.0
var move_direction := Vector2.RIGHT

func _ready() -> void:
	await get_tree().process_frame
	
	collision_layer = 0
	collision_mask = 0
	
	set_collision_layer_value(4, true)
	set_collision_mask_value(3, true)
	
	move_direction = Vector2.RIGHT.rotated(rotation)
	
	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.flip_h = rotation > 0
	
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += move_direction * speed * delta
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var enemies_to_remove = []
	for enemy in hit_enemies.keys():
		if current_time - hit_enemies[enemy] >= hit_cooldown:
			enemies_to_remove.append(enemy)
	
	for enemy in enemies_to_remove:
		hit_enemies.erase(enemy)

func set_damage(value: float) -> void:
	damage = value

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if not enemy.is_in_group("enemy"):
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if enemy in hit_enemies and current_time - hit_enemies[enemy] < hit_cooldown:
		return
		
	hit_enemies[enemy] = current_time
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	if enemy.has_method("apply_knockback"):
		var knockback_direction = Vector2.RIGHT if scale.x > 0 else Vector2.LEFT
		enemy.apply_knockback(knockback_direction * knockback_force)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "idle":
		animated_sprite.play("end")
	elif animated_sprite.animation == "end":
		queue_free()
