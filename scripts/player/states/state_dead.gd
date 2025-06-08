extends PlayerState

class_name state_dead


signal death_animation_truly_finished

func enter() -> void:
	player.velocity = Vector2.ZERO
	
	var animation_played = false
	if player.animated_sprite:
		if player.animated_sprite.sprite_frames.has_animation("death"):
			player.animated_sprite.play("death")
			animation_played = true
			await player.animated_sprite.animation_finished
		elif player.animated_sprite.sprite_frames.has_animation("hurt"):
			player.animated_sprite.play("hurt")
			player.animated_sprite.speed_scale = 0.5
			animation_played = true
			await player.animated_sprite.animation_finished
	
	if not animation_played:
		await get_tree().create_timer(0.1).timeout
	
	death_animation_truly_finished.emit()

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
