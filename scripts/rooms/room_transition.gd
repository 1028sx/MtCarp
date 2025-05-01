extends Area2D

#region 導出參數
@export var direction: String = "right"
@export var spawn_point: String = "Right"
#endregion

#region 變量
var player_in_area := false
var is_transitioning := false
var room_cleared := false
@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_label = $Label_Interaction
#endregion

#region 生命週期函數
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = true
	
	# 初始化時隱藏門和標籤
	modulate.a = 0
	if interaction_label:
		interaction_label.hide()
	
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.stop()  # 確保一開始沒有動畫播放
	
	_connect_signals()
	print("Door ", name, " _ready finished. modulate.a=", modulate.a, " room_cleared=", room_cleared)

func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("jump"):
		_transition_room()
#endregion

#region 信號連接
func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	await get_tree().process_frame
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		if enemy_manager.all_enemies_defeated.is_connected(_on_all_enemies_defeated):
			enemy_manager.all_enemies_defeated.disconnect(_on_all_enemies_defeated)
		enemy_manager.all_enemies_defeated.connect(_on_all_enemies_defeated)

func _on_all_enemies_defeated() -> void:
	print("Door ", name, " received all_enemies_defeated. Setting visible and playing start animation.")
	room_cleared = true
	modulate.a = 1  # 顯示門
	
	if animated_sprite:
		animated_sprite.play("start")

func _on_animation_finished() -> void:
	print("Door ", name, " animation finished: ", animated_sprite.animation if animated_sprite else "[No Sprite]")
	if animated_sprite and animated_sprite.animation == "start":
		animated_sprite.play("idle")
#endregion

#region 信號處理
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		if room_cleared and interaction_label:
			interaction_label.show()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		if interaction_label:
			interaction_label.hide()
#endregion

#region 房間切換
func _get_and_remove_managers() -> Array:
	var managers = []
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		enemy_manager.name = "EnemyManager"
		if enemy_manager.get_parent():
			enemy_manager.get_parent().remove_child(enemy_manager)
		managers.append(enemy_manager)
		
		var room_manager = _get_room_manager()
		if room_manager:
			var current_room = room_manager.get_current_room()
			enemy_manager.save_room_state(current_room)
	
	var item_manager = get_tree().get_first_node_in_group("item_manager")
	if item_manager:
		item_manager.name = "ItemManager"
		if item_manager.get_parent():
			item_manager.get_parent().remove_child(item_manager)
		managers.append(item_manager)
	
	return managers

func _place_managers_in_new_scene(managers: Array, new_scene: Node) -> void:
	if not new_scene:
		return
		
	for manager in managers:
		if not manager:
			continue
			
		if manager.get_parent():
			manager.get_parent().remove_child(manager)
		new_scene.add_child(manager)
		
		if manager.is_in_group("enemy_manager"):
			manager.name = "EnemyManager"

func _transition_room() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	var room_manager = _get_room_manager()
	if not room_manager:
		printerr("錯誤：無法在 right_door.gd 中找到 RoomManager！")
		is_transitioning = false
		return
		
	var current_room = room_manager.get_current_room()
	var target_room = room_manager.get_connected_room(current_room, direction)
	if target_room.is_empty():
		printerr("RoomManager 未找到從 ", current_room, " 往 ", direction, " 的連接房間！")
		is_transitioning = false
		return
	
	var current_player = _get_and_remove_player()
	var current_uis = _get_and_remove_ui()
	var current_managers = _get_and_remove_managers()
	
	if not current_player:
		printerr("錯誤：無法在轉換前找到玩家節點！")
		is_transitioning = false
		return
	
	var scene_path = "res://scenes/rooms/%s.tscn" % target_room
	var packed_scene = load(scene_path)
	if not packed_scene:
		printerr("無法載入場景：", scene_path, " - 請檢查路徑和 RoomManager 返回的房間名 (", target_room, ") 是否與 res://scenes/rooms/ 下的文件名匹配！")
		is_transitioning = false
		return
	
	var new_scene = packed_scene.instantiate()
	
	if MetSys: 
		MetSys.room_changed.emit(current_room, target_room)
	else:
		printerr("警告：無法找到 MetSys 來發出 room_changed 信號。")

	_switch_scene(new_scene)
	_place_player_in_new_scene(current_player, new_scene)
	_place_ui_in_new_scene(current_uis, new_scene)
	_place_managers_in_new_scene(current_managers, new_scene)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		if enemy_manager.has_method("spawn_enemies_for_room"):
			enemy_manager.spawn_enemies_for_room(target_room)
		else:
			printerr("錯誤：EnemyManager 沒有 spawn_enemies_for_room 方法！")
	
	is_transitioning = false
#endregion

#region 輔助函數
func _get_and_remove_player() -> Node2D:
	var current_player = get_tree().get_first_node_in_group("player")
	if current_player:
		if not current_player.is_physics_processing():
			printerr("玩家物理處理已停止（可能已死亡），無法進行房間轉換。")
			return null
		if current_player.get_parent():
			current_player.get_parent().remove_child(current_player)
		else:
			printerr("警告：無法移除玩家，因為它沒有父節點。")
			return null
		return current_player
	else:
		printerr("錯誤：在 right_door.gd 中無法找到玩家節點！")
		return null

func _get_and_remove_ui() -> Array:
	var uis = []
	
	var main_ui_nodes = get_tree().get_nodes_in_group("ui")
	for main_ui in main_ui_nodes:
		if main_ui and main_ui.get_parent():
			main_ui.get_parent().remove_child(main_ui)
			uis.append(main_ui)
	
	var loot_ui_nodes = get_tree().get_nodes_in_group("loot_selection_ui")
	for loot_ui in loot_ui_nodes:
		if loot_ui and loot_ui.get_parent():
			loot_ui.get_parent().remove_child(loot_ui)
			uis.append(loot_ui)
	
	return uis

func _switch_scene(new_scene: Node) -> void:
	var root = get_tree().root
	var current_scene = get_tree().current_scene
	
	root.add_child(new_scene)
	if current_scene:
		current_scene.queue_free()
	get_tree().current_scene = new_scene

func _place_player_in_new_scene(player: Node2D, new_scene: Node) -> void:
	if not player or not new_scene:
		printerr("錯誤：_place_player_in_new_scene 收到無效的 player 或 new_scene")
		return
	
	# 先將玩家添加到新場景，這樣後續查找生成點時 new_scene 才是玩家的相對根
	new_scene.add_child(player)
	
	# --- 修改的部分：根據 spawn_point 決定目標生成點名稱 ---
	var target_spawn_node_name = ""
	match spawn_point: # spawn_point 是這個門在當前房間的位置
		"Right":
			# 從右門出去，應出現在新房間的左邊生成點
			target_spawn_node_name = "LeftSpawn" 
		"Left":
			# 從左門出去，應出現在新房間的右邊生成點
			target_spawn_node_name = "RightSpawn" 
		"Top": 
			# 從上門出去，應出現在新房間的下邊生成點 (假設使用 Top/Bottom)
			target_spawn_node_name = "BottomSpawn"
		"Bottom":
			# 從下門出去，應出現在新房間的上邊生成點 (假設使用 Top/Bottom)
			target_spawn_node_name = "TopSpawn"
		_: # 處理未知的 spawn_point 值
			printerr("room_transition.gd: 無效的 spawn_point 值 '", spawn_point, "'，無法確定目標生成點！將嘗試使用 DefaultSpawn。")
			# 你可以在這裡設定一個預設的生成點，或者讓玩家生成在房間中心
			target_spawn_node_name = "DefaultSpawn" # 或者其他備用名稱
	# --- 結束修改 ---
	
	# 查找包含生成點的節點 (例如名為 "SpawnPoints" 的 Node2D)
	var spawn_points = new_scene.get_node_or_null("SpawnPoints")
	
	if spawn_points:
		# 在 "SpawnPoints" 節點下查找具體的生成點 (例如名為 "LeftSpawn" 的 Marker2D)
		var target_spawn = spawn_points.get_node_or_null(target_spawn_node_name)
		if target_spawn:
			# 確保 target_spawn 是一個 Node2D 或繼承自它的節點，以便有 global_position
			if target_spawn is Node2D:
				player.global_position = target_spawn.global_position
				# print("玩家已放置在生成點: ", target_spawn_node_name)
			else:
				printerr("錯誤：找到的生成點 '", target_spawn_node_name, "' 不是 Node2D，無法設定 global_position。")
		else:
			printerr("錯誤：在新場景 '", new_scene.name, "' 的 'SpawnPoints' 節點下找不到名為 '", target_spawn_node_name, "' 的生成點節點。")
	else:
		printerr("錯誤：在新場景 '", new_scene.name, "' 中找不到名為 'SpawnPoints' 的節點來放置玩家。")

	# 等待一幀確保玩家位置等已更新
	await get_tree().process_frame
	
	# 重新連接 UI 信號
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("connect_player_signals"):
		ui.connect_player_signals()

func _place_ui_in_new_scene(uis: Array, new_scene: Node) -> void:
	if new_scene:
		for ui in uis:
			if not ui:
				continue
			
			new_scene.add_child(ui)
			
			if ui.is_in_group("ui"):
				_setup_main_ui(ui)
			elif ui.is_in_group("loot_selection_ui"):
				ui.hide()
		
		var global_ui = get_node_or_null("/root/GlobalUi")
		if global_ui:
			global_ui.setup_inventory()

func _setup_main_ui(ui: Node) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.health_changed.is_connected(ui._on_player_health_changed):
			player.health_changed.disconnect(ui._on_player_health_changed)
		player.health_changed.connect(ui._on_player_health_changed)
		if ui.has_method("_update_health_bar"):
			ui._update_health_bar(player)

func _get_room_manager() -> Node:
	var room_manager = get_node_or_null("/root/RoomManager")
	if room_manager:
		return room_manager
	
	room_manager = get_tree().root.get_node_or_null("RoomManager")
	if room_manager:
		return room_manager
	
	return null
#endregion
