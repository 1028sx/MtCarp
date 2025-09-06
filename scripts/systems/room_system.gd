extends Node

# 房間系統 - 整合攝影機管理、房間管理和重生點管理功能

static var instance: Node = null

# 房間和攝影機信號
signal room_changed

# 重生點管理信號
signal respawn_point_activated(point: RespawnPoint)
signal player_respawned(position: Vector2)
signal respawn_system_enabled

# 重生點管理數據
var registered_respawn_points: Array[RespawnPoint] = []
var active_respawn_point: RespawnPoint = null
var respawn_position: Vector2 = Vector2.ZERO
var respawn_room: String = ""
var respawn_system_unlocked: bool = false
var _respawn_in_progress: bool = false

static func get_instance() -> Node:
	if instance == null:
		push_error("[RoomSystem] 錯誤：實例不存在")
	return instance

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if instance == null:
		instance = self
		add_to_group("persistent")
		add_to_group("room_system")
	else:
		call_deferred("queue_free")
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

# 房間管理功能 (來自 RoomManager)
func get_current_room() -> String:
	return MetSys.get_current_room_name()

func get_room_type(_room: String) -> String:
	# 所有房間類型現在由MetSys管理
	return "normal"

# 攝影機管理功能 (來自 CameraManager)
func setup_camera_limits(player: Node, map: Node) -> void:
	if not is_instance_valid(player) or not is_instance_valid(map):
		return
	
	var camera = player.get_node_or_null("Camera2D")
	if not is_instance_valid(camera):
		return
	
	var room_instance = MetSys.get_current_room_instance()
	if not is_instance_valid(room_instance):
		room_instance = map.get_node_or_null("RoomInstance")
	
	if is_instance_valid(room_instance) and room_instance.has_method("adjust_camera_limits"):
		if room_instance.has_method("get_size"):
			room_instance.adjust_camera_limits(camera)
	else:
		_set_fallback_camera_limits(camera)

func _set_fallback_camera_limits(camera: Camera2D) -> void:
	camera.limit_left = 0
	camera.limit_top = 0 
	camera.limit_right = 1920
	camera.limit_bottom = 1080

func setup_player_position(player: Node, map: Node):
	if not player or not map:
		return
	
	await get_tree().process_frame
	
	var room_instance = MetSys.get_current_room_instance()
	if not is_instance_valid(room_instance):
		room_instance = map.get_node_or_null("RoomInstance")
	
	if is_instance_valid(room_instance) and room_instance.has_method("get_size"):
		var room_size = room_instance.get_size()
		var initial_position = Vector2(room_size.x / 2, room_size.y - 96)
		player.position = initial_position
	else:
		var cell_size = MetSys.settings.in_game_cell_size
		var initial_position = Vector2(cell_size.x / 2, cell_size.y - 96)
		player.position = initial_position
	
	var camera = player.get_node_or_null("Camera2D")
	if camera:
		camera.force_update_scroll()
	
	setup_camera_limits(player, map)

# 整合的房間和攝影機設定
func setup_room_and_camera(player: Node, map: Node) -> void:
	await setup_player_position(player, map)
	setup_camera_limits(player, map)
	
	# 發出房間變更信號
	room_changed.emit()

# 便利方法：同時設定房間和攝影機
func initialize_room(player: Node, map: Node) -> void:
	if not is_instance_valid(player) or not is_instance_valid(map):
		return
	
	await setup_room_and_camera(player, map)

# ==============================================================================
# 重生點管理功能 (整合自 RespawnManager)
# ==============================================================================

func register_respawn_point(point: RespawnPoint) -> void:
	if point not in registered_respawn_points:
		registered_respawn_points.append(point)
		
		# 連接信號
		if not point.activated.is_connected(_on_respawn_point_activated):
			point.activated.connect(_on_respawn_point_activated)

func unregister_respawn_point(point: RespawnPoint) -> void:
	var index = registered_respawn_points.find(point)
	if index >= 0:
		registered_respawn_points.remove_at(index)
		
		# 斷開信號
		if point.activated.is_connected(_on_respawn_point_activated):
			point.activated.disconnect(_on_respawn_point_activated)

func set_active_respawn_point(point: RespawnPoint) -> void:
	# 停用所有其他重生點
	for rp in registered_respawn_points:
		if rp != point and is_instance_valid(rp):
			rp.deactivate()
	
	# 設定新的活躍重生點
	active_respawn_point = point
	
	if active_respawn_point:
		respawn_position = active_respawn_point.get_respawn_position()
		respawn_room = active_respawn_point.get_room_name()
		
		respawn_point_activated.emit(point)

func _on_respawn_point_activated(point: RespawnPoint) -> void:
	set_active_respawn_point(point)

func get_respawn_position() -> Vector2:
	if active_respawn_point and is_instance_valid(active_respawn_point):
		return active_respawn_point.get_respawn_position()
	return respawn_position

func get_respawn_room() -> String:
	if active_respawn_point and is_instance_valid(active_respawn_point):
		return active_respawn_point.get_room_name()
	return respawn_room

func has_active_respawn_point() -> bool:
	# 先檢查當前節點是否有效
	if active_respawn_point != null and is_instance_valid(active_respawn_point):
		return true
	
	# 如果節點無效，檢查是否有保存的重生數據
	return respawn_position != Vector2.ZERO and respawn_room != "" and respawn_room != "Unknown"

func respawn_player() -> void:
	# 防止重複觸發重生流程
	if _respawn_in_progress:
		return
		
	_respawn_in_progress = true
	
	var player = PlayerSystem.get_player()
	if not is_instance_valid(player):
		_respawn_in_progress = false
		push_error("無法重生：找不到玩家實例")
		return
	
	var target_position = get_respawn_position()
	var target_room = get_respawn_room()
	
	if target_position == Vector2.ZERO:
		_respawn_in_progress = false
		push_error("無法重生：沒有有效的重生位置")
		return
	
	# 如果需要切換房間
	if target_room != "" and target_room != get_current_room():
		_switch_to_respawn_room(target_room, target_position)
	else:
		_respawn_at_position(target_position)
	
	player_respawned.emit(target_position)
	_respawn_in_progress = false

func _switch_to_respawn_room(room_name: String, position: Vector2):
	var player = PlayerSystem.get_player()
	if not is_instance_valid(player):
		return
	
	# 通過MetSys切換房間
	if MetSys.has_method("change_room"):
		MetSys.change_room(room_name)
	
	# 設定玩家位置
	await get_tree().process_frame
	_respawn_at_position(position)

func _respawn_at_position(position: Vector2):
	var player = PlayerSystem.get_player()
	if not is_instance_valid(player):
		return
	
	# 重置玩家狀態
	if player.has_method("reset_for_respawn"):
		player.reset_for_respawn()
	
	# 設定位置
	player.global_position = position
	
	# 重置相關系統
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("reset_combo"):
		combat_system.reset_combo()
	
	# 確保攝影機更新
	var camera = player.get_node_or_null("Camera2D")
	if camera:
		camera.force_update_scroll()

func enable_respawn_system() -> void:
	if not respawn_system_unlocked:
		respawn_system_unlocked = true
		respawn_system_enabled.emit()

func is_respawn_system_enabled() -> bool:
	return respawn_system_unlocked

func clear_respawn_data() -> void:
	active_respawn_point = null
	respawn_position = Vector2.ZERO
	respawn_room = ""
	registered_respawn_points.clear()
