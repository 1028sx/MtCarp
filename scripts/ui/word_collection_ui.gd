extends Control

#region 節點引用
@onready var collected_words = $Panel/MarginContainer/VBoxContainer/CollectedWords
@onready var idiom_hints = $Panel/MarginContainer/VBoxContainer/IdiomHints
@onready var idiom_slots = $Panel/MarginContainer/VBoxContainer/IdiomSlots

var inventory_word_scene = preload("res://scenes/ui/inventory_word.tscn")
var word_states = {}  # 用於追蹤每個文字的狀態
#endregion

#region 初始化
func _ready() -> void:
	add_to_group("word_collection_ui")
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_priority = 100
	
	var panel = get_node_or_null("Panel")
	if panel:
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.process_priority = 100
	
	_setup_mouse_filters(self)
	_setup_word_collection()
	setup_idiom_slots()

func _setup_word_collection() -> void:
	if not collected_words:
		push_error("[WordUI] 找不到collected_words節點")
		return
		
	collected_words.custom_minimum_size = Vector2(600, 200)
	collected_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collected_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collected_words.mouse_filter = Control.MOUSE_FILTER_PASS
	collected_words.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var word_system = get_node("/root/WordSystem")
	if word_system:
		word_system.words_updated.connect(_on_words_updated)
		_on_words_updated(word_system.collected_words)
		update_idiom_hints([])
	else:
		push_error("[WordUI] 找不到word_system")
#endregion

#region 文字管理
func _on_words_updated(new_words: Array) -> void:
	var updated_states = {}
	for word in new_words:
		if not word_states.has(word):
			updated_states[word] = {"in_slot": false, "slot_index": -1}
		else:
			updated_states[word] = word_states[word]
	word_states = updated_states
	update_collected_words()

func update_collected_words() -> void:
	for child in collected_words.get_children():
		child.queue_free()
	
	for word in word_states.keys():
		if not word_states[word]["in_slot"]:
			var word_instance = inventory_word_scene.instantiate()
			word_instance.character = word
			word_instance.custom_minimum_size = Vector2(50, 50)
			collected_words.add_child(word_instance)

func move_word_to_slot(word: String, slot_index: int) -> void:
	if word_states.has(word):
		word_states[word]["in_slot"] = true
		word_states[word]["slot_index"] = slot_index
		update_collected_words()

func remove_word_from_slot(word: String) -> void:
	if word_states.has(word):
		word_states[word]["in_slot"] = false
		word_states[word]["slot_index"] = -1
		
		var word_system = get_tree().get_first_node_in_group("word_system")
		if word_system:
			word_system.update_active_effects("")
#endregion

#region 輸入處理
func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	var global_ui = get_node_or_null("/root/GlobalUi")
	if global_ui and global_ui.has_method("is_other_ui_visible"):
		if global_ui.is_other_ui_visible("inventory"):
			return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = _find_word_at_position(event.position)
		if target:
			var current_parent = target.get_parent()
			if current_parent == collected_words:
				var empty_slot = _find_empty_slot()
				if empty_slot:
					if empty_slot.has_method("accept_word"):
						move_word_to_slot(target.character, idiom_slots.get_children().find(empty_slot))
						empty_slot.accept_word(target.character)
						get_viewport().set_input_as_handled()
			elif current_parent.is_in_group("idiom_slot"):
				if current_parent.has_method("remove_word"):
					var word_character = ""
					if target.has_method("get_character"):
						word_character = target.character
					elif target.has_method("get_text"):
						word_character = target.get_text()
					elif target is Node and target.get_parent().has_method("get_current_text"):
						word_character = target.get_parent().get_current_text()
					
					if word_character != "":
						remove_word_from_slot(word_character)
						current_parent.remove_word()
						update_idiom_hints([])
						
						var word_instance = inventory_word_scene.instantiate()
						word_instance.character = word_character
						word_instance.custom_minimum_size = Vector2(50, 50)
						collected_words.add_child(word_instance)
						get_viewport().set_input_as_handled()
			get_viewport().set_input_as_handled()
#endregion

#region 輔助函數
func _find_empty_slot() -> Node:
	if not idiom_slots:
		return null
		
	for slot in idiom_slots.get_children():
		if slot is PanelContainer and slot.has_method("is_empty") and slot.is_empty():
			return slot
	return null

func _find_word_at_position(click_pos: Vector2) -> Node:
	if collected_words:
		for word in collected_words.get_children():
			if word.has_method("get_global_rect"):
				var rect = word.get_global_rect()
				if rect.has_point(click_pos):
					return word
	
	if idiom_slots:
		for slot in idiom_slots.get_children():
			if slot is PanelContainer and slot.has_method("get_word"):
				var slot_rect = slot.get_global_rect()
				if slot_rect.has_point(click_pos):
					var word = slot.get_word()
					if word:
						return word
	
	return null

func _find_slot_at_position(click_pos: Vector2) -> Node:
	if not idiom_slots:
		return null
		
	for slot in idiom_slots.get_children():
		if slot is PanelContainer and slot.get_global_rect().has_point(click_pos):
			return slot
	return null
#endregion

#region UI更新
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible:
				process_mode = Node.PROCESS_MODE_ALWAYS
				_setup_mouse_filters(self)
				var global_ui = get_node_or_null("/root/GlobalUi")
				if global_ui and global_ui.has_method("is_other_ui_visible"):
					if global_ui.is_other_ui_visible("inventory"):
						set_process_input(false)
					else:
						set_process_input(true)
			else:
				set_process_input(false)
		NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			process_mode = Node.PROCESS_MODE_ALWAYS

func setup_idiom_slots() -> void:
	for child in idiom_slots.get_children():
		child.queue_free()
	
	for i in range(4):
		var slot = PanelContainer.new()
		slot.set_script(preload("res://scripts/ui/idiom_slots.gd"))
		idiom_slots.add_child(slot)

func update_idiom_hints(_available_idioms: Array) -> void:
	for child in idiom_hints.get_children():
		child.queue_free()
	
	var word_system = get_tree().get_first_node_in_group("word_system")
	if not word_system:
		push_error("[WordUI] 找不到word_system")
		return
	
	for idiom in word_system.IDIOMS:
		var label = Label.new()
		var display_text = ""
		var characters = idiom.split("")
		
		for character in characters:
			if word_system.collected_words.has(character):
				display_text += character
			else:
				display_text += "?"
		
		var description = word_system.get_idiom_description(idiom)
		label.text = "%s: %s" % [display_text, description]
		idiom_hints.add_child(label)

func _setup_mouse_filters(node: Node) -> void:
	if node is Control:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.process_priority = 100
		
		if node == collected_words:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		elif node is LineEdit or node is TextEdit:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		elif node.is_in_group("inventory_word"):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		elif node.is_in_group("idiom_slot"):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		elif node.name == "Panel":
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in node.get_children():
		_setup_mouse_filters(child)
#endregion
