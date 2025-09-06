extends Node

# UI系統信號
signal ui_setup_complete
signal inventory_opened
signal inventory_closed
signal scene_transition_requested(scene_path: String)
signal ui_state_changed(state: String)

# UI組件引用
var ui: Node
var boss_ui: Node  
var inventory_ui: Control = null
var word_collection_ui: Control = null

# 暫停管理
var pause_stack := 0
var active_ui_stack := []

# UI狀態管理（按優先級從低到高排列）
enum UIState {
	GAME,      # 0 - 基礎遊戲狀態
	INVENTORY, # 1 - 物品欄（遊戲內UI，最低優先級）
	PAUSE,     # 2 - 暫停選單
	SETTINGS,  # 3 - 設置選單  
	GAME_OVER, # 4 - 遊戲結束畫面
	MENU       # 5 - 主菜單（最高優先級）
}

var current_ui_state := UIState.GAME
var ui_state_stack := []
var transition_screen: Node = null

# 預載場景
var boss_ui_scene = preload("res://scenes/ui/boss_ui.tscn")

func _init():
	add_to_group("ui_system")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# 確保輸入映射存在
	if not InputMap.has_action("inventory"):
		InputMap.add_action("inventory")
		var event = InputEventKey.new()
		event.keycode = KEY_Q
		InputMap.action_add_event("inventory", event)
	
	if not InputMap.has_action("ui_cancel"):
		InputMap.add_action("ui_cancel")
		var escape_event = InputEventKey.new()
		escape_event.keycode = KEY_ESCAPE
		InputMap.action_add_event("ui_cancel", escape_event)
	
	# 獲取過場動畫節點
	transition_screen = get_node_or_null("/root/TransitionScreen")

# UI設定 - 來自 UIManager
func setup_ui(main_node: Node, player: Node):
	await _setup_main_ui(main_node, player)
	await _setup_boss_ui(main_node)
	
	# 設定背包系統
	setup_inventory()
	
	ui_setup_complete.emit()

func _setup_main_ui(main_node: Node, player: Node):
	var ui_scene = preload("res://scenes/ui/ui.tscn")
	ui = ui_scene.instantiate()
	main_node.add_child(ui)
	ui.name = "UI"
	
	if player and ui:
		if not player.gold_changed.is_connected(ui.update_gold):
			player.gold_changed.connect(ui.update_gold)
		if not player.health_changed.is_connected(ui._on_player_health_changed):
			player.health_changed.connect(ui._on_player_health_changed)

func _setup_boss_ui(main_node: Node):
	var autoload_boss_ui = get_node_or_null("/root/BossUI")
	if autoload_boss_ui:
		if autoload_boss_ui.get_parent():
			autoload_boss_ui.get_parent().remove_child(autoload_boss_ui)
			autoload_boss_ui.queue_free()
			await get_tree().process_frame

	var existing_boss_ui = get_tree().get_first_node_in_group("boss_ui")
	if existing_boss_ui:
		boss_ui = existing_boss_ui
		
		if boss_ui.get_parent() != main_node:
			if boss_ui.get_parent():
				boss_ui.get_parent().remove_child(boss_ui)
			main_node.add_child(boss_ui)
		
		var control_hud = boss_ui.get_node_or_null("Control_BossHUD")
		if not control_hud:
			boss_ui.queue_free()
			await get_tree().process_frame
			boss_ui = boss_ui_scene.instantiate()
			main_node.add_child(boss_ui)
		
	else:
		boss_ui = boss_ui_scene.instantiate()
		main_node.add_child(boss_ui)
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

func get_ui() -> Node:
	return ui

func get_boss_ui() -> Node:
	return boss_ui

func on_player_health_changed(new_health):
	if ui:
		ui._on_player_health_changed(new_health)

# 暫停和背包管理

func _ensure_canvas_layer() -> CanvasLayer:
	var existing_canvas = get_node_or_null("GlobalCanvas")
	if existing_canvas:
		return existing_canvas
		
	var global_canvas = CanvasLayer.new()
	global_canvas.name = "GlobalCanvas"
	global_canvas.layer = 15  # 遊戲內UI層 (10-19)
	global_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(global_canvas)
	return global_canvas

func setup_inventory() -> void:
	if inventory_ui and is_instance_valid(inventory_ui) and inventory_ui.is_inside_tree():
		return
	
	var inventory_scene = load("res://scenes/ui/inventory_ui.tscn")
	if not inventory_scene:
		return
		
	inventory_ui = inventory_scene.instantiate()
	if not inventory_ui:
		return
		
	inventory_ui.name = "GlobalInventoryUI"
	
	var global_canvas = _ensure_canvas_layer()
	if not global_canvas:
		return
	
	global_canvas.add_child(inventory_ui)
	inventory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	word_collection_ui = inventory_ui.get_node_or_null("WordCollectionUI")
	if word_collection_ui:
		word_collection_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		word_collection_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	inventory_ui.hide()

func request_pause(source: String = "") -> void:
	if source and is_other_ui_visible(source):
		return
	
	pause_stack += 1
	if source:
		active_ui_stack.erase(source)
		active_ui_stack.push_back(source)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		
		for child in player.get_children():
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		
	for loot in get_tree().get_nodes_in_group("loot"):
		loot.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if not get_tree().paused:
		get_tree().paused = true

func request_unpause(source: String = "") -> void:
	if pause_stack <= 0:
		return
	
	if source and is_other_ui_visible(source):
		return
	
	if source:
		if source in active_ui_stack:
			active_ui_stack.erase(source)
			pause_stack -= 1
		else:
			return
	else:
		pause_stack -= 1
	
	if pause_stack == 0:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.process_mode = Node.PROCESS_MODE_INHERIT
			
			for child in player.get_children():
				child.process_mode = Node.PROCESS_MODE_INHERIT
		
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			
		for loot in get_tree().get_nodes_in_group("loot"):
			loot.process_mode = Node.PROCESS_MODE_INHERIT
		
		if get_tree().paused:
			get_tree().paused = false

func toggle_inventory() -> void:
	if not inventory_ui or not is_instance_valid(inventory_ui):
		setup_inventory()
		if not inventory_ui:
			return
	
	if current_ui_state == UIState.INVENTORY:
		# 關閉物品欄，返回遊戲狀態
		inventory_ui.hide()
		if word_collection_ui:
			word_collection_ui.hide()
		
		pop_ui_state()  # 回到之前的狀態（通常是GAME）
		inventory_closed.emit()
	elif current_ui_state == UIState.GAME:
		# 只有在遊戲狀態才能打開物品欄
		inventory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		if word_collection_ui:
			word_collection_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		
		change_ui_state(UIState.INVENTORY)
		
		inventory_ui.show()
		if word_collection_ui:
			word_collection_ui.show()
			
		var global_canvas = inventory_ui.get_parent()
		if global_canvas is CanvasLayer:
			global_canvas.layer = 15  # 確保使用遊戲內UI層
			
		_ensure_ui_input_handling(inventory_ui)
		
		inventory_opened.emit()
	# 其他狀態下（PAUSE, SETTINGS等）不允許操作物品欄

func _ensure_ui_input_handling(node: Node) -> void:
	if node is Control:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		
		if node.is_in_group("inventory_word"):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		elif node.is_in_group("idiom_slot"):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.mouse_default_cursor_shape = Control.CURSOR_DRAG
		elif node.name == "CollectedWords":
			node.mouse_filter = Control.MOUSE_FILTER_PASS
		elif node.name == "Panel":
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.mouse_default_cursor_shape = Control.CURSOR_ARROW
		elif node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			node.focus_mode = Control.FOCUS_ALL
	
	for child in node.get_children():
		_ensure_ui_input_handling(child)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		# 物品欄作為遊戲內UI，只有在沒有更高優先級UI時才能操作
		if current_ui_state == UIState.GAME:
			# 只有在遊戲狀態時才能打開物品欄
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif current_ui_state == UIState.INVENTORY:
			# 在物品欄狀態時可以關閉
			toggle_inventory()
			get_viewport().set_input_as_handled()
		# 如果有更高優先級的UI開啟（PAUSE, SETTINGS等），忽略Q鍵
	elif event.is_action_pressed("ui_cancel"):
		_handle_cancel_input()
		get_viewport().set_input_as_handled()

func _handle_cancel_input() -> void:
	# 按UI優先級處理ESC鍵（優先處理最高優先級的UI）
	match current_ui_state:
		UIState.SETTINGS:
			# 設置選單有自己的back按鈕處理邏輯
			# ESC鍵不直接處理，讓設置選單內部的返回按鈕處理
			var settings_menu = get_tree().get_first_node_in_group("settings_menu")
			if settings_menu and settings_menu.has_method("_on_back_pressed"):
				settings_menu._on_back_pressed()
		UIState.PAUSE:
			# 關閉暫停選單，返回遊戲
			var pause_menu = get_tree().get_first_node_in_group("pause_menu")
			if pause_menu:
				pause_menu.hide_menu()
		UIState.INVENTORY:
			# 關閉物品欄，返回遊戲
			toggle_inventory()
		UIState.GAME:
			# 遊戲中按ESC打開暫停選單
			var pause_menu = get_tree().get_first_node_in_group("pause_menu")
			if pause_menu:
				pause_menu.show_menu()
		UIState.GAME_OVER:
			# 遊戲結束畫面有自己的輸入處理（返回主菜單）
			var game_over_screen = get_tree().get_first_node_in_group("game_over_screen")
			if game_over_screen and game_over_screen.has_method("_back_to_menu"):
				game_over_screen._back_to_menu()
		UIState.MENU:
			# 主菜單狀態下ESC不做處理（或可以是退出遊戲）
			pass

# 字詞系統接口
func add_word(word: String) -> void:
	if word_collection_ui and word_collection_ui.has_method("add_word"):
		word_collection_ui.add_word(word)

func remove_word(word: String) -> void:
	if word_collection_ui and word_collection_ui.has_method("remove_word"):
		word_collection_ui.remove_word(word)

func get_collected_words() -> Array:
	if word_collection_ui and word_collection_ui.has_method("get_collected_words"):
		return word_collection_ui.get_collected_words()
	return []

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			process_mode = Node.PROCESS_MODE_ALWAYS
			
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.process_mode = Node.PROCESS_MODE_INHERIT
				
				for child in player.get_children():
					child.process_mode = Node.PROCESS_MODE_INHERIT
		
		NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			process_mode = Node.PROCESS_MODE_ALWAYS

func is_other_ui_visible(current_ui: String) -> bool:
	var settings_menu = get_tree().get_first_node_in_group("settings_menu")
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	
	match current_ui:
		"inventory":
			return (settings_menu and settings_menu.visible) or \
				   (pause_menu and pause_menu.visible)
		"pause_menu":
			return settings_menu and settings_menu.visible
		"settings_menu":
			return false
		_:
			return (settings_menu and settings_menu.visible) or \
				   (pause_menu and pause_menu.visible) or \
				   (inventory_ui and inventory_ui.visible)

# 新的UI狀態管理方法
func change_ui_state(new_state: UIState, push_to_stack: bool = true) -> void:
	if push_to_stack and current_ui_state != new_state:
		ui_state_stack.push_back(current_ui_state)
	
	var old_state = current_ui_state
	current_ui_state = new_state
	
	_handle_state_transition(old_state, new_state)
	ui_state_changed.emit(_state_to_string(new_state))

func pop_ui_state() -> void:
	if ui_state_stack.size() > 0:
		var previous_state = ui_state_stack.pop_back()
		change_ui_state(previous_state, false)
	else:
		change_ui_state(UIState.GAME, false)

func _handle_state_transition(_from_state: UIState, to_state: UIState) -> void:
	# 處理暫停邏輯
	match to_state:
		UIState.GAME:
			if pause_stack > 0:
				request_unpause()
		UIState.PAUSE, UIState.INVENTORY, UIState.SETTINGS:
			if pause_stack == 0:
				request_pause(_state_to_string(to_state))

func _state_to_string(state: UIState) -> String:
	match state:
		UIState.GAME: return "game"
		UIState.MENU: return "menu"
		UIState.PAUSE: return "pause_menu"
		UIState.INVENTORY: return "inventory"
		UIState.SETTINGS: return "settings_menu"
		UIState.GAME_OVER: return "game_over"
		_: return "unknown"

# 獲取UI狀態的優先級（數字越大優先級越高）
func _get_ui_priority(state: UIState) -> int:
	return int(state)

# 檢查是否可以切換到指定狀態（基於優先級）
func _can_transition_to_state(target_state: UIState) -> bool:
	# 總是可以切換到更高優先級的狀態
	# 或者返回到更低優先級的狀態
	return _get_ui_priority(target_state) >= _get_ui_priority(current_ui_state)

# 統一的場景轉換方法
func request_scene_transition(scene_path: String) -> void:
	scene_transition_requested.emit(scene_path)
	
	if transition_screen:
		await transition_screen.fade_to_black()
	
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		if transition_screen:
			await transition_screen.fade_from_black()
	else:
		push_error("無法找到場景檔案: " + scene_path)

# 清理遊戲內UI的統一方法
func cleanup_game_ui() -> void:
	for group_name in ["inventory_ui", "pause_menu", "settings_menu", "game_over_screen"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if node and is_instance_valid(node):
				node.queue_free()