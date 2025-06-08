class_name GlobalUI
extends Node

signal inventory_opened
signal inventory_closed

var inventory_ui: Control = null
var word_collection_ui: Control = null
var process_mode_monitor: Timer = null
var pause_stack := 0
var active_ui_stack := []

func _init():
	add_to_group("global_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
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
	
	_start_process_mode_monitor()

func _start_process_mode_monitor() -> void:
	if process_mode_monitor:
		process_mode_monitor.queue_free()
	
	process_mode_monitor = Timer.new()
	process_mode_monitor.wait_time = 0.05
	process_mode_monitor.one_shot = false
	process_mode_monitor.timeout.connect(_check_process_modes)
	process_mode_monitor.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(process_mode_monitor)
	process_mode_monitor.start()

func _check_process_modes() -> void:
	if process_mode != Node.PROCESS_MODE_ALWAYS:
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	_check_node_process_mode(self)

func _check_node_process_mode(node: Node) -> void:
	if node.process_mode != Node.PROCESS_MODE_ALWAYS:
		node.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	if node == inventory_ui:
		if inventory_ui.process_mode != Node.PROCESS_MODE_ALWAYS:
			inventory_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	if node == word_collection_ui:
		if word_collection_ui.process_mode != Node.PROCESS_MODE_ALWAYS:
			word_collection_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	for child in node.get_children():
		_check_node_process_mode(child)

func _ensure_canvas_layer() -> CanvasLayer:
	var existing_canvas = get_node_or_null("GlobalCanvas")
	if existing_canvas:
		return existing_canvas
		
	var global_canvas = CanvasLayer.new()
	global_canvas.name = "GlobalCanvas"
	global_canvas.layer = 100
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
	
	if source:
		match source:
			"inventory":
				var loot_ui = get_tree().get_first_node_in_group("loot_selection_ui")
				if loot_ui and loot_ui.visible and loot_ui.has_method("hide_menu"):
					loot_ui.hide_menu()
					request_unpause("loot_ui")
			"loot_ui":
				if inventory_ui and inventory_ui.visible:
					inventory_ui.hide()
					if word_collection_ui:
						word_collection_ui.hide()
					request_unpause("inventory")
	
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
	
	if inventory_ui.visible:
		inventory_ui.hide()
		if word_collection_ui:
			word_collection_ui.hide()
		
		request_unpause("inventory")
		inventory_closed.emit()
	else:
		inventory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		if word_collection_ui:
			word_collection_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		
		request_pause("inventory")
		
		inventory_ui.show()
		if word_collection_ui:
			word_collection_ui.show()
			
		var global_canvas = inventory_ui.get_parent()
		if global_canvas is CanvasLayer:
			global_canvas.layer = 100
			
		_ensure_ui_input_handling(inventory_ui)
		
		inventory_opened.emit()

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
		elif node is Button or node.get_class() == "EffectButton":
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			node.focus_mode = Control.FOCUS_ALL
	
	for child in node.get_children():
		_ensure_ui_input_handling(child)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		var settings_menu = get_tree().get_first_node_in_group("settings_menu")
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		var loot_ui = get_tree().get_first_node_in_group("loot_selection_ui")
		
		if settings_menu and settings_menu.visible:
			get_viewport().set_input_as_handled()
		elif inventory_ui and inventory_ui.visible:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif pause_menu:
			if pause_menu.visible:
				pause_menu.hide_menu()
			else:
				pause_menu.show_menu()
			get_viewport().set_input_as_handled()
		elif loot_ui and loot_ui.visible:
			get_viewport().set_input_as_handled()

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
	var loot_ui = get_tree().get_first_node_in_group("loot_selection_ui")
	
	match current_ui:
		"inventory":
			return (settings_menu and settings_menu.visible) or \
				   (pause_menu and pause_menu.visible) or \
				   (loot_ui and loot_ui.visible)
		"loot_ui":
			return (settings_menu and settings_menu.visible) or \
				   (pause_menu and pause_menu.visible)
		"pause_menu":
			return settings_menu and settings_menu.visible
		"settings_menu":
			return false
		_:
			return (settings_menu and settings_menu.visible) or \
				   (pause_menu and pause_menu.visible) or \
				   (loot_ui and loot_ui.visible) or \
				   (inventory_ui and inventory_ui.visible)
