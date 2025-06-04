extends Node2D

#region 節點引用
@onready var player = $Player
@onready var enemy_manager = preload("res://scenes/managers/EnemyManager.tscn").instantiate()
@onready var item_manager = preload("res://scenes/managers/ItemManager.tscn").instantiate()
@onready var ui = preload("res://scenes/ui/UI.tscn").instantiate()
@onready var loot_selection_ui = preload("res://scenes/ui/loot_selection_ui.tscn")
@onready var game_manager = preload("res://scenes/managers/GameManager.tscn").instantiate()
var boss_ui_scene = preload("res://scenes/enemies/boss_ui.tscn")
var boss_ui = null

func _get_room_manager() -> Node:
	return get_node("/root/RoomManager")

func _enter_tree() -> void:
	await get_tree().process_frame

func _ready():
	if not is_in_group("main"):
		add_to_group("main")
	
	if not player:
		return
	
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
	ui.name = "UI"
	
	if player and ui:
		if not player.gold_changed.is_connected(ui.update_gold):
			player.gold_changed.connect(ui.update_gold)
		if not player.health_changed.is_connected(ui._on_player_health_changed):
			player.health_changed.connect(ui._on_player_health_changed)
	

	var autoload_boss_ui = get_node_or_null("/root/BossUI")
	if autoload_boss_ui:
		if autoload_boss_ui.get_parent():
			autoload_boss_ui.get_parent().remove_child(autoload_boss_ui)
			autoload_boss_ui.queue_free()
			await get_tree().process_frame

	var existing_boss_ui = get_tree().get_first_node_in_group("boss_ui")
	if existing_boss_ui:
		boss_ui = existing_boss_ui
		
		if boss_ui.get_parent() != self:
			if boss_ui.get_parent():
				boss_ui.get_parent().remove_child(boss_ui)
			add_child(boss_ui)
		
		var control_hud = boss_ui.get_node_or_null("Control_BossHUD")
		if not control_hud:
			boss_ui.queue_free()
			await get_tree().process_frame
			boss_ui = boss_ui_scene.instantiate()
			add_child(boss_ui)
		
	else:
		boss_ui = boss_ui_scene.instantiate()
		
		add_child(boss_ui)
		await get_tree().process_frame
		
		var control_hud = boss_ui.get_node_or_null("Control_BossHUD")
		if control_hud:
			var texture_progress = control_hud.get_node_or_null("TextureProgressBar_BossHP")
			if not texture_progress:
				pass
		else:
			pass
		
		if not boss_ui.is_in_group("boss_ui"):
			boss_ui.add_to_group("boss_ui")
	
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
	_initialize_sizes()
	
	if player:
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	
	_connect_signals()

func _connect_signals():
	await get_tree().process_frame
	
	var room_manager = get_node("/root/RoomManager")
	if not room_manager:
		return
		
	if room_manager.has_signal("room_changed"):
		if not room_manager.is_connected("room_changed", _on_room_changed):
			room_manager.connect("room_changed", _on_room_changed)
	
	if player:
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)

func _initialize_sizes():
	screen_size = get_viewport_rect().size
	world_size = Vector2(1920, 1080)

func _setup_initial_room():
	var initial_room = load("res://scenes/rooms/Beginning1.tscn").instantiate()
	add_child(initial_room)
	
	_setup_player_position(initial_room)
	
	if enemy_manager:
		enemy_manager.spawn_enemies_for_room("Beginning1")

func _setup_player_position(room):
	if not player or not room:
		return
		
	var spawn_points = room.get_node_or_null("SpawnPoints")
	if not spawn_points:
		return
		
	var left_spawn = spawn_points.get_node_or_null("LeftSpawn")
	if not left_spawn:
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
