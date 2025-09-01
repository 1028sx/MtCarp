extends PlayerState

class_name PlayerDeadState


signal death_animation_truly_finished

var death_animation_finished: bool = false
var has_respawn_point: bool = false

func enter() -> void:
	player.velocity = Vector2.ZERO
	death_animation_finished = false
	
	# 檢查復活心邏輯
	if player.has_revive_heart:
		_handle_revive_heart()
		return
	
	# 檢查是否有重生點
	_check_respawn_point()
	
	# 碰撞設定由編輯器處理，不在腳本中修改
	
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
	
	# 根據是否有重生點決定後續處理
	if has_respawn_point:
		# 有重生點：TransitionScreen 淡出已經開始，直接發信號重生
		player.player_fully_died.emit()
	else:
		# 沒有重生點：執行玩家淡出效果，完成後發信號進入 Game Over
		var tween = player.create_tween()
		tween.tween_property(player, "modulate", Color(1, 1, 1, 0), 2.0)
		tween.tween_callback(func(): 
			player.visible = false
			player.player_fully_died.emit()
		)

func exit() -> void:
	# 碰撞設定由編輯器處理，不在腳本中設定
	# 視覺效果重置由 reset_state() 處理，避免重複
	if player.animated_sprite:
		player.animated_sprite.speed_scale = 1.0

func process_physics(_delta: float) -> void:
	pass

func process_input(_event: InputEvent) -> void:
	pass

func get_transition() -> PlayerState:
	return null

# 處理復活心邏輯
func _handle_revive_heart() -> void:
	player.has_revive_heart = false
	player.current_health = float(player.max_health) / 2.0
	player.health_changed.emit(player.current_health)
	
	var ui = player.get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("use_revive_heart"):
		ui.use_revive_heart()
	
	player.set_invincible(2.0)
	
	# 恢復物理和輸入處理
	player.set_physics_process(true)
	player.set_process_input(true)
	
	# 退出死亡狀態，回到正常狀態
	if state_machine and state_machine.states.has("idle"):
		state_machine._transition_to(state_machine.states["idle"])

# 檢查重生點並開始轉場效果
func _check_respawn_point() -> void:
	var respawn_manager = player.get_node_or_null("/root/RespawnManager")
	if respawn_manager and respawn_manager.has_active_respawn_point():
		has_respawn_point = true
		
		# 立即開始 TransitionScreen 淡出（0.5秒）
		var transition_screen = player.get_node_or_null("/root/TransitionScreen")
		if transition_screen and transition_screen.has_method("fade_to_black"):
			transition_screen.fade_to_black()
	else:
		has_respawn_point = false
