extends Node

signal initialization_complete

var screen_size: Vector2
var world_size: Vector2

var ui_system: Node
var input_manager: Node
var room_system: Node

# 房間重入冷卻系統
var room_exit_times: Dictionary = {}
const ROOM_REENTRY_COOLDOWN: float = 10.0

# 向上房間轉換推力系統
const UPWARD_BOOST_FORCE: float = 500.0
const MIN_REQUIRED_VELOCITY: float = 500.0
var previous_room_coords: Vector2i = Vector2i.MAX

func _ready():
	# 使用autoload系統，不需要手動實例化
	ui_system = get_node("/root/UISystem")
	input_manager = preload("res://scripts/managers/input_manager.gd").new()
	room_system = get_node("/root/RoomSystem")
	
	add_child(input_manager)

func initialize_game(main_node: Node, player: Node):
	_initialize_sizes()
	_initialize_metsys()
	
	input_manager.initialize_pause_system()
	
	await ui_system.setup_ui(main_node, player)
	
	if player:
		_connect_player_signals(player)
	
	initialization_complete.emit()

func _initialize_sizes():
	screen_size = get_viewport().get_visible_rect().size
	world_size = Vector2(1920, 1080)

func _initialize_metsys():
	if MetSys and MetSys.save_data == null:
		MetSys.set_save_data({})

func _connect_player_signals(player: Node):
	if not player.health_changed.is_connected(ui_system.on_player_health_changed):
		player.health_changed.connect(ui_system.on_player_health_changed)

func initialize_room_with_player(player: Node, map: Node):
	# 向上房間轉換推力輔助
	_apply_upward_boost_if_needed(player)
	
	if player and map:
		if player.get_parent():
			player.get_parent().remove_child(player)
		map.add_child(player)

	await get_tree().process_frame
	room_system.setup_camera_limits(player, map)
	
	_spawn_room_entities()
	
	# 更新房間座標記錄
	_update_room_coords()

func _spawn_room_entities():
	var current_room_name = MetSys.get_current_room_name()
	
	# 檢查房間重入冷卻
	if _is_room_in_reentry_cooldown(current_room_name):
		return  # 跳過敵人生成
	
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system:
		combat_system.spawn_all_enemies_and_bosses_for_room(current_room_name)

func _is_room_in_reentry_cooldown(room_name: String) -> bool:
	"""檢查房間是否在重入冷卻期間"""
	if not room_exit_times.has(room_name):
		return false
		
	var current_time = Time.get_ticks_msec() / 1000.0
	var exit_time = room_exit_times[room_name]
	return (current_time - exit_time) < ROOM_REENTRY_COOLDOWN

func record_room_exit(room_name: String):
	"""記錄房間退出時間"""
	room_exit_times[room_name] = Time.get_ticks_msec() / 1000.0

func _apply_upward_boost_if_needed(player: Node):
	"""向上房間轉換時給予推力輔助"""
	if not player or previous_room_coords == Vector2i.MAX:
		return
	
	var current_coords = _get_current_room_coords()
	if current_coords == Vector2i.MAX:
		return
	
	# 檢查是否為向上轉換（Y座標越小代表越上方）
	if current_coords.y < previous_room_coords.y:
		# 檢查玩家是否需要推力輔助
		if player.velocity.y > -MIN_REQUIRED_VELOCITY:
			player.velocity.y = -UPWARD_BOOST_FORCE

func _get_current_room_coords() -> Vector2i:
	# 獲取當前房間在地圖中的座標
	if not MetSys or not MetSys.current_room:
		return Vector2i.MAX
	
	var room_instance = MetSys.current_room
	if room_instance and room_instance.cells.size() > 0:
		var cell = room_instance.cells[0]
		return Vector2i(cell.x, cell.y)
	
	return Vector2i.MAX

func _update_room_coords():
	# 更新房間座標記錄
	previous_room_coords = _get_current_room_coords()

func get_ui_system() -> Node:
	return ui_system

func get_input_manager() -> Node:
	return input_manager

func get_room_system() -> Node:
	return room_system

func get_screen_size() -> Vector2:
	return screen_size

func get_world_size() -> Vector2:
	return world_size