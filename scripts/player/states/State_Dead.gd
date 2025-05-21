extends PlayerState

class_name State_Dead

func enter() -> void:
	
	player.velocity = Vector2.ZERO
	
	if player.animated_sprite:
		player.animated_sprite.play("death")
		
		if not "death" in player.animated_sprite.sprite_frames.get_animation_names():
			player.animated_sprite.play("hurt")
			player.animated_sprite.speed_scale = 0.5
	
	player.set_collision_layer_value(2, false)
	player.set_collision_mask_value(1, false)
	
	var tween = player.create_tween()
	tween.tween_property(player, "modulate", Color(1, 1, 1, 0), 2.0)
	tween.tween_callback(func(): player.visible = false)

func exit() -> void:
	
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.modulate = Color(1, 1, 1, 1)
	player.visible = true
	
	if player.animated_sprite:
		player.animated_sprite.speed_scale = 1.0

func process_physics(_delta: float) -> void:
	pass

func process_input(_event: InputEvent) -> void:
	pass

func get_transition() -> PlayerState:
	return null

func on_animation_finished(_anim_name: String) -> void:
	pass 
