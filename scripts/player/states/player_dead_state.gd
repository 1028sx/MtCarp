extends PlayerState

class_name PlayerDeadState


signal death_animation_truly_finished

var death_animation_finished: bool = false

func enter() -> void:
	player.velocity = Vector2.ZERO
	death_animation_finished = false
	
	# 立即禁用碰撞
	player.set_collision_layer_value(2, false)
	player.set_collision_mask_value(1, false)
	
	# 嘗試播放死亡動畫
	if player.animated_sprite and player.animated_sprite.sprite_frames:
		if player.animated_sprite.sprite_frames.has_animation("death"):
			player.animated_sprite.play("death")
			# 連接動畫完成信號
			if not player.animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
				player.animated_sprite.animation_finished.connect(_on_death_animation_finished)
			
			# 後備計時器：如果3秒後動畫還沒完成，就強制觸發
			var timer = get_tree().create_timer(3.0)
			timer.timeout.connect(_on_fallback_timer)
			return
		elif player.animated_sprite.sprite_frames.has_animation("hurt"):
			player.animated_sprite.play("hurt")
			player.animated_sprite.speed_scale = 0.5
			# 連接動畫完成信號
			if not player.animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
				player.animated_sprite.animation_finished.connect(_on_death_animation_finished)
			return
	
	# 如果沒有動畫，直接觸發死亡完成
	_trigger_death_completion()

func _on_death_animation_finished():
	if player.animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
		player.animated_sprite.animation_finished.disconnect(_on_death_animation_finished)
	_trigger_death_completion()

func _on_fallback_timer():
	_trigger_death_completion()

func _trigger_death_completion():
	if death_animation_finished:
		return  # 防止重複觸發
	
	death_animation_finished = true
	death_animation_truly_finished.emit()
	
	# 開始淡出效果
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
