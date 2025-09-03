extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

# MetSys SaveManager 整合
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
const SAVE_PATH = "user://metsys_save.dat"

#region 節點引用
@onready var game_player = $Player
@onready var enemy_manager = EnemyManager
@onready var item_manager = preload("res://scenes/managers/item_manager.tscn").instantiate()
@onready var ui = preload("res://scenes/ui/ui.tscn").instantiate()
@onready var loot_selection_ui = preload("res://scenes/ui/loot_selection_ui.tscn")
@onready var game_manager = GameManager
var boss_ui_scene = preload("res://scenes/ui/boss_ui.tscn")
var boss_ui = null


func _enter_tree() -> void:
	await get_tree().process_frame

func _ready():
	if not is_in_group("main"):
		add_to_group("main")
	
	if not game_player:
		return
	
	
	# 設置MetSys玩家追蹤
	set_player(game_player)
	
	# 添加房間轉換模塊
	add_module("RoomTransitions.gd")
	
	if not game_player.health_changed.is_connected(_on_player_health_changed):
		game_player.health_changed.connect(_on_player_health_changed)
	
	_pause_stack = 0
	get_tree().paused = false
	
	for node in get_tree().get_nodes_in_group("main"):
		if node != self:
			node.remove_from_group("main")
	add_to_group("main")
	
	var global_ui = get_node_or_null("/root/GlobalUi")
	if not global_ui:
		return
	
	
	var existing_item_manager = get_tree().get_first_node_in_group("item_manager")
	if existing_item_manager:
		item_manager = existing_item_manager
	else:
		add_child(item_manager)
		item_manager.add_to_group("item_manager")
	
	
	add_child(ui)
	ui.name = "UI"
	
	if game_player and ui:
		if not game_player.gold_changed.is_connected(ui.update_gold):
			game_player.gold_changed.connect(ui.update_gold)
		if not game_player.health_changed.is_connected(ui._on_player_health_changed):
			game_player.health_changed.connect(ui._on_player_health_changed)
	

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
	
	# 連接room_loaded信號來處理房間載入後的邏輯
	if not room_loaded.is_connected(_on_room_loaded):
		room_loaded.connect(_on_room_loaded)
	
	# 使用MetSys載入初始房間
	await load_room("beginning/Beginning1.tscn")
	
	# 只在初始房間載入時設置玩家位置
	_setup_player_position()
	
	# 確保攝影機限制正確設定
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_camera_limits()
#endregion

#region 狀態變量
var screen_size: Vector2
var world_size: Vector2
var _pause_stack: int = 0
#endregion

#region 初始化
func _initialize_game():
	_initialize_sizes()
	
	# 初始化MetSys存檔系統（必需，避免save_data為null）
	_initialize_metsys()
	
	if game_player:
		if not game_player.health_changed.is_connected(_on_player_health_changed):
			game_player.health_changed.connect(_on_player_health_changed)
	
	_connect_signals()

func _initialize_metsys():
	# 只初始化存檔系統，不重複連接信號
	if MetSys and MetSys.save_data == null:
		# set_save_data接受Dictionary參數，空字典表示新遊戲
		MetSys.set_save_data({})

func _connect_signals():
	if game_player:
		if not game_player.health_changed.is_connected(_on_player_health_changed):
			game_player.health_changed.connect(_on_player_health_changed)

func _initialize_sizes():
	screen_size = get_viewport().get_visible_rect().size
	world_size = Vector2(1920, 1080)

func _get_room_manager() -> Node:
	return get_node("/root/RoomManager")

func _on_room_loaded():
	if game_player and map:
		if game_player.get_parent():
			game_player.get_parent().remove_child(game_player)
		map.add_child(game_player)

	await get_tree().process_frame
	_setup_camera_limits()
	
	if enemy_manager:
		var current_room_name = MetSys.get_current_room_name()
		enemy_manager.spawn_enemies_for_room(current_room_name)
		
	# 生成BOSS
	if BossManager:
		var current_room_name = MetSys.get_current_room_name()
		BossManager.spawn_bosses_for_room(current_room_name)

func _setup_initial_room():
	var initial_room = load("res://scenes/rooms/beginning/Beginning1.tscn").instantiate()
	add_child(initial_room)
	
	_setup_player_position()
	
	# 確保初始房間也設定攝影機限制
	await get_tree().process_frame
	_setup_camera_limits()
	
	if enemy_manager:
		enemy_manager.spawn_enemies_for_room("Beginning1")
		
	# 生成初始房間BOSS  
	if BossManager:
		BossManager.spawn_bosses_for_room("Beginning1")

func _setup_player_position():
	if not game_player or not map:
		return
	
	await get_tree().process_frame
	
	# 使用MetSys的RoomInstance計算初始位置
	var room_instance = MetSys.get_current_room_instance()
	if not is_instance_valid(room_instance):
		# 如果沒有從MetSys取得，嘗試從場景取得
		room_instance = map.get_node_or_null("RoomInstance")
	
	if is_instance_valid(room_instance) and room_instance.has_method("get_size"):
		# 使用RoomInstance的bounds計算位置
		var room_size = room_instance.get_size()
		# 將玩家放在房間底部中央，距離底部96像素（安全距離）
		var initial_position = Vector2(room_size.x / 2, room_size.y - 96)
		game_player.position = initial_position
		print("設置玩家初始位置: ", initial_position, " (房間大小: ", room_size, ")")
	else:
		# 後備方案：使用MetSys的cell size計算
		var cell_size = MetSys.settings.in_game_cell_size
		var initial_position = Vector2(cell_size.x / 2, cell_size.y - 96)
		game_player.position = initial_position
		print("使用後備位置: ", initial_position, " (Cell大小: ", cell_size, ")")
	
	var camera = game_player.get_node_or_null("Camera2D")
	if camera:
		camera.force_update_scroll()
	
	_setup_camera_limits()

func _setup_camera_limits() -> void:
	# 安全檢查
	if not is_instance_valid(game_player) or not is_instance_valid(map):
		return
	
	var camera = game_player.get_node_or_null("Camera2D")
	if not is_instance_valid(camera):
		return
	
	# 使用 MetSys 的 RoomInstance 設定攝影機限制
	var room_instance = MetSys.get_current_room_instance()
	if not is_instance_valid(room_instance):
		# 如果沒有從 MetSys 取得，嘗試從場景取得
		room_instance = map.get_node_or_null("RoomInstance")
	
	if is_instance_valid(room_instance) and room_instance.has_method("adjust_camera_limits"):
		# 檢查房間大小計算
		if room_instance.has_method("get_size"):
			# 使用 MetSys 原生的 adjust_camera_limits 方法
			room_instance.adjust_camera_limits(camera)
	else:
		# 作為後備，設定預設限制以避免攝影機完全無限制
		_set_fallback_camera_limits(camera)

func _set_fallback_camera_limits(camera: Camera2D) -> void:
	# 使用當前場景的預設大小作為後備
	camera.limit_left = 0
	camera.limit_top = 0 
	camera.limit_right = 1920
	camera.limit_bottom = 1080


#endregion

#region 遊戲系統
func request_pause():
	_pause_stack += 1
	if _pause_stack > 0:
		get_tree().paused = true

func request_unpause():
	_pause_stack = max(0, _pause_stack - 1)
	if _pause_stack == 0:
		get_tree().paused = false

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



func _on_player_health_changed(new_health):
	if ui and game_manager:
		ui._on_player_health_changed(new_health)
#endregion

#region 遊戲管理
func start_new_game():
	if game_manager:
		game_manager.reset_game()

func save_game():
	var save_manager := SaveManager.new()
	save_manager.store_game(self)
	save_manager.save_as_text(SAVE_PATH)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var save_manager := SaveManager.new()
	save_manager.load_from_text(SAVE_PATH)
	save_manager.retrieve_game(self)
	
	# 恢復房間位置（如果有的話）
	var current_room = save_manager.get_value("current_room", "")
	if current_room != "" and current_room != MetSys.get_current_room_name():
		await load_room(current_room)
	
	return true

func set_music_volume(volume: float):
	if game_manager:
		game_manager.set_music_volume(volume)

func set_sfx_volume(volume: float):
	if game_manager:
		game_manager.set_sfx_volume(volume)

# MetSys SaveManager 整合方法
func _get_save_data() -> Dictionary:
	var data = {}
	
	# 收集GameManager的數據
	if game_manager and game_manager.has_method("get_save_data"):
		data.merge(game_manager.get_save_data())
	
	# 收集RespawnManager的數據
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager and respawn_manager.has_method("get_save_data"):
		data.merge(respawn_manager.get_save_data())
	
	# 添加當前房間信息
	data["current_room"] = MetSys.get_current_room_name()
	
	return data

func _set_save_data(data: Dictionary):
	# 分發數據到GameManager
	if game_manager and game_manager.has_method("set_save_data"):
		game_manager.set_save_data(data)
	
	# 分發數據到RespawnManager
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager and respawn_manager.has_method("set_save_data"):
		respawn_manager.set_save_data(data)


#endregion
