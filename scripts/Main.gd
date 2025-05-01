extends Node2D

#region 節點引用
@onready var player = $Player
@onready var enemy_manager = preload("res://scenes/managers/EnemyManager.tscn").instantiate()
@onready var item_manager = preload("res://scenes/managers/ItemManager.tscn").instantiate()
@onready var ui = preload("res://scenes/ui/UI.tscn").instantiate()
@onready var loot_selection_ui = preload("res://scenes/ui/loot_selection_ui.tscn")
@onready var game_manager = preload("res://scenes/managers/GameManager.tscn").instantiate()

func _get_room_manager() -> Node:
	return get_node("/root/RoomManager")

func _enter_tree() -> void:
	await get_tree().process_frame

func _ready():
	if not is_in_group("main"):
		add_to_group("main")
	
	if not player:
		push_error("[Main] 錯誤：找不到玩家節點！")
		return
	
	# 連接玩家信號
	print("[Main] 正在連接玩家信號")
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
		print("[Main] 已連接玩家死亡信號")
	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	
	_pause_stack = 0
	get_tree().paused = false
	
	for node in get_tree().get_nodes_in_group("main"):
		if node != self:
			node.remove_from_group("main")
	add_to_group("main")
	
	var global_ui = get_node_or_null("/root/GlobalUi")
	if not global_ui:
		push_error("[Main] 錯誤：找不到GlobalUi自動加載節點")
		return
	
	var existing_enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if existing_enemy_manager:
		enemy_manager = existing_enemy_manager
	else:
		add_child(enemy_manager)
		enemy_manager.add_to_group("enemy_manager")
	
	var existing_item_manager = get_tree().get_first_node_in_group("item_manager")
	if existing_item_manager:
		item_manager = existing_item_manager
	else:
		add_child(item_manager)
		item_manager.add_to_group("item_manager")
	
	var existing_game_manager = get_tree().get_first_node_in_group("game_manager")
	if existing_game_manager:
		game_manager = existing_game_manager
	else:
		add_child(game_manager)
		game_manager.add_to_group("game_manager")
	
	add_child(ui)
	
	var new_loot_selection_ui = loot_selection_ui.instantiate()
	add_child(new_loot_selection_ui)
	new_loot_selection_ui.hide()
	
	global_ui.setup_inventory()
	
	_initialize_game()
	_setup_initial_room()
#endregion

#region 狀態變量
var screen_size: Vector2
var world_size: Vector2
var _pause_stack: int = 0
#endregion

#region 初始化
func _initialize_game():
	print("[Main] 開始初始化遊戲")
	_initialize_sizes()
	
	# 確保在這裡連接玩家信號
	if player:
		print("[Main] 正在連接玩家信號")
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
			print("[Main] 已連接玩家死亡信號")
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
			print("[Main] 已連接玩家生命值變化信號")
	else:
		push_error("[Main] 錯誤：初始化時找不到玩家節點")
	
	_connect_signals()

func _connect_signals():
	await get_tree().process_frame
	
	var room_manager = get_node("/root/RoomManager")
	if not room_manager:
		push_error("[Main] 錯誤：找不到 RoomManager")
		return
		
	if room_manager.has_signal("room_changed"):
		if not room_manager.is_connected("room_changed", _on_room_changed):
			room_manager.connect("room_changed", _on_room_changed)
	
	# 連接玩家信號
	if player:
		print("[Main] 正在連接玩家信號")
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
			print("[Main] 已連接玩家死亡信號")
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	else:
		push_error("[Main] 錯誤：找不到玩家節點")

func _initialize_sizes():
	screen_size = get_viewport_rect().size
	world_size = Vector2(1920, 1080)

func _setup_initial_room():
	var initial_room = load("res://scenes/rooms/Beginning1.tscn").instantiate()
	add_child(initial_room)
	
	_setup_player_position(initial_room)
	
	if enemy_manager:
		enemy_manager.spawn_enemies_for_room("Beginning1")
	else:
		push_error("[Main] 錯誤：找不到敵人管理器")

func _setup_player_position(room):
	if not player or not room:
		push_error("[Main] 錯誤：無法設置玩家位置，玩家或房間節點不存在")
		return
		
	var spawn_points = room.get_node_or_null("SpawnPoints")
	if not spawn_points:
		push_error("[Main] 錯誤：找不到SpawnPoints節點")
		return
		
	var left_spawn = spawn_points.get_node_or_null("LeftSpawn")
	if not left_spawn:
		push_error("[Main] 錯誤：找不到LeftSpawn節點")
		return
		
	player.global_position = left_spawn.global_position
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.visible = true

func _spawn_initial_enemies(room: Node) -> void:
	if enemy_manager and room:
		var enemy_spawn_points = room.get_node_or_null("EnemySpawnPoints")
		if enemy_spawn_points and enemy_spawn_points.get_child_count() > 0:
			for spawn_point in enemy_spawn_points.get_children():
				if spawn_point.name.begins_with("Spawn"):
					_spawn_enemy(spawn_point)
	else:
		push_error("[Main] 無法生成敵人：enemy_manager 或 room 不存在")
#endregion

#region 遊戲系統
func request_pause():
	_pause_stack += 1
	if _pause_stack > 0:
		get_tree().paused = true
		if enemy_manager and enemy_manager.has_method("stop_auto_spawn"):
			enemy_manager.stop_auto_spawn()

func request_unpause():
	_pause_stack = max(0, _pause_stack - 1)
	if _pause_stack == 0:
		get_tree().paused = false
		if enemy_manager and enemy_manager.has_method("start_auto_spawn"):
			enemy_manager.start_auto_spawn()

func _input(event):
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			request_unpause()
		else:
			request_pause()
	elif event.is_action_pressed("map"):
		_toggle_map()
	elif event.is_action_pressed("inventory"):
		var global_ui = get_node("/root/GlobalUi")
		if global_ui:
			if not get_tree().paused:
				request_pause()
			global_ui.toggle_inventory()
			get_viewport().set_input_as_handled()

func _toggle_pause():
	if get_tree().paused:
		request_unpause()
	else:
		request_pause()

func _toggle_map() -> void:
	var room_manager = _get_room_manager()
	if room_manager:
		if MetSys.is_map_visible():
			room_manager.hide_map()
		else:
			room_manager.show_map()

func _spawn_enemy(spawn_point: Node2D) -> void:
	if enemy_manager:
		var enemy_type = "archer"
		if spawn_point.name.contains("Boar"):
			enemy_type = "boar"
			
		var enemy = enemy_manager.enemy_scenes[enemy_type].instantiate()
		enemy.global_position = spawn_point.global_position
		
		enemy_manager.add_child(enemy)
		if not enemy in enemy_manager.current_enemies:
			enemy_manager.current_enemies.append(enemy)
		
		if not enemy.defeated.is_connected(enemy_manager._on_enemy_defeated):
			enemy.defeated.connect(enemy_manager._on_enemy_defeated.bind(enemy))

func _on_room_changed():
	var room_manager = _get_room_manager()
	if room_manager and room_manager.has_signal("room_changed"):
		await get_tree().process_frame
		
		for node in get_tree().get_nodes_in_group("main"):
			if node != self:
				node.remove_from_group("main")
		if not is_in_group("main"):
			add_to_group("main")
		
		for old_loot_ui in get_tree().get_nodes_in_group("loot_selection_ui"):
			if old_loot_ui and old_loot_ui.get_parent():
				old_loot_ui.get_parent().remove_child(old_loot_ui)
				old_loot_ui.queue_free()
		
		var new_loot_selection_ui = loot_selection_ui.instantiate()
		add_child(new_loot_selection_ui)
		new_loot_selection_ui.hide()
		
		if game_manager:
			if game_manager.get_parent() != self:
				if game_manager.get_parent():
					game_manager.get_parent().remove_child(game_manager)
				add_child(game_manager)
			game_manager.name = "game_manager"
			if not game_manager.is_in_group("game_manager"):
				game_manager.add_to_group("game_manager")
		
		if ui:
			var current_player = get_tree().get_first_node_in_group("player")
			if current_player:
				if ui.has_method("_connect_player"):
					ui._connect_player()

func _on_player_health_changed(new_health):
	if ui and game_manager:
		ui._on_player_health_changed(new_health)

func _on_player_died():
	print("[Main] 玩家死亡信號已接收")
	if game_manager:
		print("[Main] 正在調用 game_manager.game_over()")
		game_manager.game_over()
	else:
		print("[Main] 錯誤：找不到 game_manager")
#endregion

#region 遊戲管理
func start_new_game():
	if game_manager:
		game_manager.reset_game()

func save_game():
	var room_manager = _get_room_manager()
	if game_manager and room_manager:
		game_manager.save_game()
		room_manager.save_game_state()

func load_game():
	var room_manager = _get_room_manager()
	if game_manager and room_manager:
		game_manager.load_game()
		room_manager.load_game_state()

func set_music_volume(volume: float):
	if game_manager:
		game_manager.set_music_volume(volume)

func set_sfx_volume(volume: float):
	if game_manager:
		game_manager.set_sfx_volume(volume)
#endregion
