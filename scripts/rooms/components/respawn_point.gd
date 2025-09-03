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
	
	# 連接信號
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 設定初始狀態
	_setup_visual_state()
	_setup_interaction_prompt()
	
	# 向重生管理器註冊並檢查是否應該是活躍狀態
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager:
		respawn_manager.register_respawn_point(self)
		
		# 檢查當前重生點是否應該是活躍的
		_check_if_should_be_active(respawn_manager)

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

func _check_if_should_be_active(respawn_manager) -> void:
	# 檢查這個重生點是否是當前活躍的重生點
	if respawn_manager.has_active_respawn_point():
		var current_room = get_room_name()
		var current_position = global_position
		
		# 比較當前重生點的房間和位置
		var active_room = respawn_manager.get_respawn_room()
		var active_position = respawn_manager.get_respawn_position()
		
		# 如果房間匹配且位置接近，則應該是活躍狀態
		if current_room == active_room and current_position.distance_to(active_position) < 50.0:
			is_activated = true
			_setup_visual_state()  # 重新設置視覺狀態

func _input(event: InputEvent) -> void:
	if can_interact and not is_activated:
		if event.is_action_pressed("interact"):
			_activate_respawn_point()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = true
		if not is_activated:
			_show_interaction_prompt()
		
		# 儲存玩家引用用於治療請求
		if not has_meta("current_player"):
			set_meta("current_player", body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = false
		_hide_interaction_prompt()
		
		# 清除玩家引用
		if has_meta("current_player"):
			remove_meta("current_player")

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
	
	# 直接呼叫玩家的治療方法
	if has_meta("current_player"):
		var player_body = get_meta("current_player")
		if player_body and player_body.has_method("start_healing"):
			player_body.start_healing("respawn_point")
	
	# 設定為啟動狀態
	is_activated = true
	_setup_visual_state()
	_hide_interaction_prompt()
	
	# 播放重生點啟動動畫
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("activating"):
			animated_sprite.play("activating")
			await animated_sprite.animation_finished
		animated_sprite.play("activated")
	
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
	spawn_pos.y -= 32  # 確保玩家重生在地面上方
	return spawn_pos

func get_room_name() -> String:
	# 優先使用 MetSys 獲取正確的房間名稱格式（包含路徑和副檔名）
	var metsys = get_node_or_null("/root/MetSys")
	if metsys and metsys.has_method("get_current_room_name"):
		var room_name = metsys.get_current_room_name()
		if room_name != "":
			return room_name
	
	# 後備方案：從父節點獲取房間名稱
	var room_node = get_parent()
	while room_node:
		if room_node.name.begins_with("Room") or room_node.name.begins_with("Beginning"):
			return room_node.name
		room_node = room_node.get_parent()
	
	return "Unknown"
