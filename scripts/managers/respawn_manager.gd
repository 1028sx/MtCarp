extends Node

signal respawn_point_activated(respawn_point: RespawnPoint)
signal player_respawned(position: Vector2)

var registered_respawn_points: Array[RespawnPoint] = []
var active_respawn_point: RespawnPoint = null
var respawn_position: Vector2 = Vector2.ZERO
var respawn_room: String = ""

func _ready() -> void:
	add_to_group("respawn_manager")
	name = "RespawnManager"
	
	# 確保在場景樹中的優先級
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_respawn_point(respawn_point: RespawnPoint) -> void:
	if respawn_point not in registered_respawn_points:
		registered_respawn_points.append(respawn_point)
		
		# 連接信號
		if not respawn_point.activated.is_connected(_on_respawn_point_activated):
			respawn_point.activated.connect(_on_respawn_point_activated)

func unregister_respawn_point(respawn_point: RespawnPoint) -> void:
	var index = registered_respawn_points.find(respawn_point)
	if index >= 0:
		registered_respawn_points.remove_at(index)
		
		# 斷開信號
		if respawn_point.activated.is_connected(_on_respawn_point_activated):
			respawn_point.activated.disconnect(_on_respawn_point_activated)

func set_active_respawn_point(respawn_point: RespawnPoint) -> void:
	# 停用所有其他重生點
	for rp in registered_respawn_points:
		if rp != respawn_point and is_instance_valid(rp):
			rp.deactivate()
	
	# 設定新的活躍重生點
	active_respawn_point = respawn_point
	
	if active_respawn_point:
		respawn_position = active_respawn_point.get_respawn_position()
		respawn_room = active_respawn_point.get_room_name()
		
		# 保存重生點數據
		save_respawn_data()
		
		respawn_point_activated.emit(respawn_point)

func _on_respawn_point_activated(respawn_point: RespawnPoint) -> void:
	set_active_respawn_point(respawn_point)

func get_respawn_position() -> Vector2:
	if active_respawn_point and is_instance_valid(active_respawn_point):
		return active_respawn_point.get_respawn_position()
	return respawn_position

func get_respawn_room() -> String:
	if active_respawn_point and is_instance_valid(active_respawn_point):
		return active_respawn_point.get_room_name()
	return respawn_room

func has_active_respawn_point() -> bool:
	return active_respawn_point != null and is_instance_valid(active_respawn_point)

func respawn_player() -> void:
	if not has_active_respawn_point():
		push_warning("RespawnManager: 沒有活躍的重生點")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("RespawnManager: 找不到玩家")
		return
	
	# 獲取重生位置和房間
	var spawn_pos = get_respawn_position()
	var spawn_room = get_respawn_room()
	
	# 檢查是否需要切換房間
	var current_room = ""
	if get_node_or_null("/root/MetSys"):
		var metsys = get_node("/root/MetSys")
		if metsys.has_method("get_current_room_name"):
			current_room = metsys.get_current_room_name()
	
	if current_room != spawn_room and spawn_room != "" and spawn_room != "Unknown":
		# 需要切換到重生點所在的房間
		_respawn_in_different_room(spawn_room, spawn_pos)
	else:
		# 在當前房間重生
		_respawn_in_current_room(player, spawn_pos)
	
	# 立即開始淡入
	var transition_screen = get_node_or_null("/root/TransitionScreen")
	if transition_screen and transition_screen.has_method("fade_from_black"):
		transition_screen.fade_from_black()

func _respawn_in_current_room(player: Node, position: Vector2) -> void:
	# 強制重置物理狀態
	player.velocity = Vector2.ZERO
	
	# 設置重生位置
	player.global_position = position
	
	# 等待一幀確保物理更新
	await get_tree().process_frame
	
	# 重置玩家狀態
	if player.has_method("reset_state"):
		player.reset_state()
	
	if player.has_method("restore_health"):
		player.restore_health()
	
	# 確保玩家不在牆內 - 如果在牆內則向上移動
	var space_state = get_tree().root.world_2d.direct_space_state
	var query = PhysicsRayQueryParameters2D.create(position, position + Vector2(0, -64))
	query.collision_mask = 1  # 只檢測環境碰撞層
	var result = space_state.intersect_ray(query)
	if result:
		# 如果上方有碰撞，嘗試向上調整位置
		player.global_position.y = result.position.y - 64
	
	# 重置遊戲狀態
	get_tree().paused = false
	if get_node_or_null("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("resume_game"):
			game_manager.resume_game()
		if game_manager.has_method("cleanup_game_over_screen"):
			game_manager.cleanup_game_over_screen()
	
	player_respawned.emit(position)

func _respawn_in_different_room(room_name: String, position: Vector2) -> void:
	# 設定重生標記，讓新場景知道要在重生點位置生成玩家
	set_meta("pending_respawn", true)
	set_meta("respawn_position", position)
	
	# 通過 MetSys 切換房間
	if get_node_or_null("/root/MetSys"):
		var metsys = get_node("/root/MetSys")
		if metsys.has_method("change_room"):
			metsys.change_room(room_name)
		else:
			push_error("RespawnManager: MetSys 沒有 change_room 方法")
	
	# 延遲處理重生
	await get_tree().create_timer(0.1).timeout
	_complete_respawn_after_room_change()

func _complete_respawn_after_room_change() -> void:
	if not has_meta("pending_respawn"):
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var spawn_pos = get_meta("respawn_position", Vector2.ZERO)
		_respawn_in_current_room(player, spawn_pos)
	
	# 清理元數據
	remove_meta("pending_respawn")
	remove_meta("respawn_position")

func save_respawn_data() -> void:
	var save_data = {
		"respawn_position": respawn_position,
		"respawn_room": respawn_room,
		"has_active_point": has_active_respawn_point()
	}
	
	# 保存到文件或遊戲狀態
	if get_node_or_null("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("set_respawn_data"):
			game_manager.set_respawn_data(save_data)

func load_respawn_data() -> void:
	if get_node_or_null("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("get_respawn_data"):
			var save_data = game_manager.get_respawn_data()
			if save_data:
				respawn_position = save_data.get("respawn_position", Vector2.ZERO)
				respawn_room = save_data.get("respawn_room", "")

func clear_all_respawn_points() -> void:
	for rp in registered_respawn_points:
		if is_instance_valid(rp):
			rp.deactivate()
	
	registered_respawn_points.clear()
	active_respawn_point = null
	respawn_position = Vector2.ZERO
	respawn_room = ""
