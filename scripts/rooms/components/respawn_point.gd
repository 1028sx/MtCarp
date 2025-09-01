extends Area2D

class_name RespawnPoint

signal activated(respawn_point: RespawnPoint)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_prompt: Label = $InteractionPrompt

var is_activated: bool = false
var can_interact: bool = false
var fade_tween: Tween

func _ready() -> void:
	add_to_group("respawn_points")
	
	# 設定碰撞層
	collision_layer = 0
	collision_mask = 2  # 玩家層
	
	# 連接信號
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 設定初始狀態
	_setup_visual_state()
	_setup_interaction_prompt()
	
	# 向重生管理器註冊
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager:
		respawn_manager.register_respawn_point(self)

func _setup_visual_state() -> void:
	if animated_sprite:
		if is_activated:
			animated_sprite.play("activated")
		else:
			animated_sprite.play("normal")

func _setup_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.text = "S鍵啟動重生點"
		interaction_prompt.modulate.a = 0.0
		interaction_prompt.visible = false

func _input(event: InputEvent) -> void:
	if can_interact and not is_activated:
		if event.is_action_pressed("interact"):
			_activate_respawn_point()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = true
		if not is_activated:
			_show_interaction_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = false
		_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	if interaction_prompt and not is_activated:
		interaction_prompt.visible = true
		
		if fade_tween:
			fade_tween.kill()
		
		fade_tween = create_tween()
		fade_tween.set_trans(Tween.TRANS_SINE)
		fade_tween.set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

func _hide_interaction_prompt() -> void:
	if interaction_prompt:
		if fade_tween:
			fade_tween.kill()
		
		fade_tween = create_tween()
		fade_tween.set_trans(Tween.TRANS_SINE)
		fade_tween.set_ease(Tween.EASE_IN)
		fade_tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.3)
		fade_tween.tween_callback(func(): interaction_prompt.visible = false)

func _activate_respawn_point() -> void:
	if is_activated:
		return
	
	# 獲取玩家引用
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 播放 healing 動畫
		if player.has_node("AniSprite2D"):
			var player_sprite = player.get_node("AniSprite2D")
			if player_sprite and player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("healing"):
				player_sprite.play("healing")
				# 等待動畫播放完成
				await player_sprite.animation_finished
				# 恢復到 idle 動畫
				player_sprite.play("idle")
		
		# 恢復滿血
		if player.has_method("restore_health"):
			player.restore_health()
	
	# 設定為激活狀態
	is_activated = true
	_setup_visual_state()
	_hide_interaction_prompt()
	
	# 播放重生點啟動動畫
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("activating"):
			animated_sprite.play("activating")
			await animated_sprite.animation_finished
		animated_sprite.play("activated")
	
	# 發出激活信號
	activated.emit(self)
	
	# 通知重生管理器
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager:
		respawn_manager.set_active_respawn_point(self)

func deactivate() -> void:
	if not is_activated:
		return
	
	is_activated = false
	_setup_visual_state()
	
	# 如果玩家還在區域內，重新顯示提示
	if can_interact:
		_show_interaction_prompt()

func get_respawn_position() -> Vector2:
	# 調整重生位置，避免玩家重生在地面以下
	var spawn_pos = global_position
	spawn_pos.y -= 32  # 向上偏移32像素，確保玩家重生在地面上方
	return spawn_pos

func get_room_name() -> String:
	# 嘗試從父節點獲取房間名稱
	var room_node = get_parent()
	while room_node:
		if room_node.name.begins_with("Room") or room_node.name.begins_with("Beginning"):
			return room_node.name
		room_node = room_node.get_parent()
	
	# 如果找不到，使用 MetSys 獲取當前房間
	var metsys = get_node_or_null("/root/MetSys")
	if metsys and metsys.has_method("get_current_room_name"):
		return metsys.get_current_room_name()
	
	return "Unknown"
